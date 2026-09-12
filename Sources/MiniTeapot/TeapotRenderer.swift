import AppKit
import MetalKit
import MiniUI
import SwiftUI
import simd

struct TeapotUniforms {
  var transform: simd_float4x4
  var rotation: simd_float4x4
  var ink: SIMD4<Float>
  var paper: SIMD4<Float>
  var options: SIMD4<Float>

  init(
    angle: Float, tilt: Float, aspect: Float, ink: SIMD4<Float>, paper: SIMD4<Float>,
    mode: TeapotMode, pixelSize: Float
  ) {
    let y = simd_float4x4(
      columns: (
        SIMD4(cos(angle), 0, -sin(angle), 0), SIMD4(0, 1, 0, 0),
        SIMD4(sin(angle), 0, cos(angle), 0), SIMD4(0, 0, 0, 1)
      ))
    let x = simd_float4x4(
      columns: (
        SIMD4(1, 0, 0, 0), SIMD4(0, cos(tilt), sin(tilt), 0),
        SIMD4(0, -sin(tilt), cos(tilt), 0), SIMD4(0, 0, 0, 1)
      ))
    rotation = x * y
    let halfHeight: Float = max(2.25, 3.7 / max(0.1, aspect))
    let projection = simd_float4x4(
      columns: (
        SIMD4(1 / (halfHeight * aspect), 0, 0, 0), SIMD4(0, 1 / halfHeight, 0, 0),
        SIMD4(0, 0, -1 / 12, 0), SIMD4(0, 0, 0.5, 1)
      ))
    transform = projection * rotation
    self.ink = ink
    self.paper = paper
    options = SIMD4(Float(mode.rawValue), pixelSize, 0, 0)
  }
}

/// Geometry and pipelines are uploaded once. Each frame sends only camera and palette uniforms.
@MainActor final class TeapotGPU {
  let device: MTLDevice
  let queue: MTLCommandQueue
  let pipeline: MTLRenderPipelineState
  let depthOnly: MTLRenderPipelineState
  let depthState: MTLDepthStencilState
  let vertices: MTLBuffer
  let indices: MTLBuffer
  let indexCount: Int

  init(device: MTLDevice) throws {
    self.device = device
    guard let queue = device.makeCommandQueue() else {
      throw TeapotError.unavailable("Metal could not create a command queue.")
    }
    self.queue = queue
    guard
      let url = Bundle.teapotResources.url(
        forResource: "Teapot", withExtension: "metal", subdirectory: "Resources")
    else {
      throw TeapotError.unavailable("The teapot shaders are missing.")
    }
    let library = try device.makeLibrary(
      source: String(contentsOf: url, encoding: .utf8), options: nil)
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "teapotVertex")
    descriptor.fragmentFunction = library.makeFunction(name: "teapotFragment")
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    descriptor.depthAttachmentPixelFormat = .depth32Float
    pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    descriptor.colorAttachments[0].writeMask = []
    depthOnly = try device.makeRenderPipelineState(descriptor: descriptor)
    let depth = MTLDepthStencilDescriptor()
    depth.depthCompareFunction = .lessEqual
    depth.isDepthWriteEnabled = true
    guard let state = device.makeDepthStencilState(descriptor: depth) else {
      throw TeapotError.unavailable("Metal could not create a depth buffer state.")
    }
    depthState = state
    let mesh = try TeapotMesh.make()
    guard
      let vertices = device.makeBuffer(
        bytes: mesh.vertices, length: mesh.vertices.count * MemoryLayout<TeapotVertex>.stride),
      let indices = device.makeBuffer(
        bytes: mesh.indices, length: mesh.indices.count * MemoryLayout<UInt32>.stride)
    else {
      throw TeapotError.unavailable("Metal could not upload the teapot.")
    }
    self.vertices = vertices
    self.indices = indices
    indexCount = mesh.indices.count
  }

  func encode(
    command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, uniforms: TeapotUniforms,
    wireframe: Bool
  ) {
    guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
    var uniforms = uniforms
    encoder.setDepthStencilState(depthState)
    encoder.setCullMode(.none)
    encoder.setVertexBuffer(vertices, offset: 0, index: 0)
    encoder.setVertexBytes(&uniforms, length: MemoryLayout<TeapotUniforms>.stride, index: 1)
    encoder.setFragmentBytes(&uniforms, length: MemoryLayout<TeapotUniforms>.stride, index: 1)
    if wireframe {
      // Fill depth first so the back of the mesh doesn't show through its front.
      encoder.setDepthBias(1, slopeScale: 1, clamp: 0)
      encoder.setRenderPipelineState(depthOnly)
      encoder.drawIndexedPrimitives(
        type: .triangle, indexCount: indexCount, indexType: .uint32, indexBuffer: indices,
        indexBufferOffset: 0)
      encoder.setDepthBias(0, slopeScale: 0, clamp: 0)
      encoder.setTriangleFillMode(.lines)
    }
    encoder.setRenderPipelineState(pipeline)
    encoder.drawIndexedPrimitives(
      type: .triangle, indexCount: indexCount, indexType: .uint32, indexBuffer: indices,
      indexBufferOffset: 0)
    encoder.endEncoding()
  }
}

struct TeapotMetalView: NSViewRepresentable {
  let model: TeapotModel
  let ink: SIMD4<Float>
  let paper: SIMD4<Float>
  let animate: Bool
  let mode: TeapotMode
  let yaw: Float
  let tilt: Float
  let resetRevision: Int

  func makeCoordinator() -> Coordinator { Coordinator(model: model) }

  func makeNSView(context: Context) -> MTKView {
    let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
    view.colorPixelFormat = .bgra8Unorm
    view.depthStencilPixelFormat = .depth32Float
    view.preferredFramesPerSecond = 60
    view.isPaused = true
    view.enableSetNeedsDisplay = true
    view.setAccessibilityElement(true)
    view.setAccessibilityLabel("Utah teapot")
    view.setAccessibilityHelp(
      "Use the arrow buttons to rotate, or the other controls to pause and change shading.")
    do {
      guard let device = view.device else {
        throw TeapotError.unavailable("A Metal-capable GPU is needed for this demo.")
      }
      context.coordinator.gpu = try TeapotGPU(device: device)
      view.delegate = context.coordinator
    } catch {
      let message = error.localizedDescription
      Task { @MainActor in model.error = message }
    }
    return view
  }

  func updateNSView(_ view: MTKView, context: Context) {
    let coordinator = context.coordinator
    coordinator.mode = mode
    coordinator.yaw = yaw
    coordinator.tilt = tilt
    coordinator.ink = ink
    coordinator.paper = paper
    if coordinator.animate != animate { coordinator.previousTime = nil }
    coordinator.animate = animate
    view.clearColor = MTLClearColor(
      red: Double(paper.x), green: Double(paper.y), blue: Double(paper.z), alpha: 1)
    view.enableSetNeedsDisplay = !animate
    view.isPaused = !animate || coordinator.gpu == nil
    if view.isPaused { view.draw() }
  }

  static func dismantleNSView(_ view: MTKView, coordinator: Coordinator) {
    view.isPaused = true
    view.delegate = nil
    coordinator.previousTime = nil
  }

  @MainActor final class Coordinator: NSObject, MTKViewDelegate {
    let model: TeapotModel
    var gpu: TeapotGPU?
    var ink = SIMD4<Float>(0, 0, 0, 1)
    var paper = SIMD4<Float>(1, 1, 1, 1)
    var mode = TeapotMode.dither
    var yaw: Float = 0
    var tilt: Float = 0
    var animate = false
    var previousTime: CFTimeInterval?
    init(model: TeapotModel) { self.model = model }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { previousTime = nil }
    func draw(in view: MTKView) {
      guard let gpu, view.window?.occlusionState.contains(.visible) == true,
        !view.isHiddenOrHasHiddenAncestor,
        let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
        let command = gpu.queue.makeCommandBuffer()
      else {
        previousTime = nil
        return
      }
      let now = CACurrentMediaTime()
      if animate, let previousTime {
        model.rotation = (model.rotation + Float(min(0.1, now - previousTime)) * model.speed)
          .truncatingRemainder(dividingBy: 2 * .pi)
      }
      previousTime = now
      let uniforms = TeapotUniforms(
        angle: model.rotation + yaw, tilt: tilt,
        aspect: Float(view.drawableSize.width / max(1, view.drawableSize.height)), ink: ink,
        paper: paper,
        mode: mode, pixelSize: Float(view.window?.backingScaleFactor ?? 2))
      gpu.encode(
        command: command, pass: pass, uniforms: uniforms, wireframe: mode == .wireframe)
      command.present(drawable)
      command.commit()
    }
  }
}
