import MetalKit
import MiniCore
import MiniUI
import SwiftUI

struct AquariumUniforms {
  var ink: SIMD4<Float>
  var paper: SIMD4<Float>
  // Logical width, logical height, simulation time, food age.
  var scene: SIMD4<Float>
  // CPU current, network intensity, build-streak growth, and sulking.
  var activity: SIMD4<Float>
}

@MainActor final class AquariumGPU {
  let queue: MTLCommandQueue
  let pipeline: MTLRenderPipelineState

  init(device: MTLDevice) throws {
    guard let queue = device.makeCommandQueue() else { throw AquariumError.unavailable }
    self.queue = queue
    let bundle = MiniResourceBundle.resolve(
      named: "HelloMini_MiniAquarium", developmentBundle: .module)
    guard
      let url = bundle.url(
        forResource: "Aquarium", withExtension: "metal", subdirectory: "Resources")
    else { throw AquariumError.missingShader }
    let library = try device.makeLibrary(
      source: String(contentsOf: url, encoding: .utf8), options: nil)
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "aquariumVertex")
    descriptor.fragmentFunction = library.makeFunction(name: "aquariumFragment")
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
  }

  func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, uniforms: AquariumUniforms)
  {
    guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
    var uniforms = uniforms
    encoder.setRenderPipelineState(pipeline)
    encoder.setFragmentBytes(&uniforms, length: MemoryLayout<AquariumUniforms>.stride, index: 0)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder.endEncoding()
  }
}

struct AquariumMetalView: NSViewRepresentable {
  let model: AquariumModel
  let ink: SIMD4<Float>
  let paper: SIMD4<Float>
  let animate: Bool
  let suspended: Bool
  let activity: AquariumActivity
  let feedRevision: Int
  var growth: Float = 0
  var sulking = false

  func makeCoordinator() -> Coordinator { Coordinator(model: model) }
  func makeNSView(context: Context) -> MTKView {
    let view = MiniMetalView(frame: .zero, device: MTLCreateSystemDefaultDevice())
    view.colorPixelFormat = .bgra8Unorm
    view.preferredFramesPerSecond = 30
    view.isPaused = true
    view.enableSetNeedsDisplay = true
    view.setAccessibilityElement(true)
    view.setAccessibilityLabel("Aquarium with nine fish, swaying plants, and bubbles")
    do {
      guard let device = view.device else { throw AquariumError.unavailable }
      context.coordinator.gpu = try AquariumGPU(device: device)
      view.delegate = context.coordinator
    } catch {
      let message = error.localizedDescription
      Task { @MainActor in model.error = message }
    }
    return view
  }

  func updateNSView(_ view: MTKView, context: Context) {
    let coordinator = context.coordinator
    coordinator.ink = ink
    coordinator.paper = paper
    coordinator.activity = activity
    coordinator.feedRevision = feedRevision
    coordinator.suspended = suspended
    coordinator.growth = growth
    coordinator.sulking = sulking
    view.setAccessibilityLabel(
      "Aquarium with \(growth >= 0.5 ? "ten" : "nine") fish, swaying plants, and bubbles")
    if coordinator.animate != animate { model.simulation.previousTime = nil }
    coordinator.animate = animate
    view.enableSetNeedsDisplay = !animate
    view.isPaused = !animate || coordinator.gpu == nil
    if view.isPaused && !suspended { view.draw() }
  }

  static func dismantleNSView(_ view: MTKView, coordinator: Coordinator) {
    view.isPaused = true
    view.delegate = nil
    coordinator.model.simulation.previousTime = nil
  }

  @MainActor final class Coordinator: NSObject, MTKViewDelegate {
    let model: AquariumModel
    var gpu: AquariumGPU?
    var ink = SIMD4<Float>(0, 0, 0, 1)
    var paper = SIMD4<Float>(1, 1, 1, 1)
    var activity = AquariumActivity()
    var feedRevision = 0
    var animate = false
    var suspended = false
    var growth: Float = 0
    var sulking = false
    init(model: AquariumModel) { self.model = model }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
      model.simulation.previousTime = nil
    }

    func draw(in view: MTKView) {
      guard !suspended else { return }
      guard let gpu, view.window?.occlusionState.contains(.visible) == true,
        !view.isHiddenOrHasHiddenAncestor,
        let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
        let command = gpu.queue.makeCommandBuffer()
      else {
        model.simulation.previousTime = nil
        return
      }
      model.simulation.advance(
        now: CACurrentMediaTime(), animate: animate, feedRevision: feedRevision, activity: activity,
        sulking: sulking)
      // A fixed logical height gives crisp, chunky pixels at both desk and screensaver sizes.
      let aspect = Float(view.drawableSize.width / max(1, view.drawableSize.height))
      gpu.encode(
        command: command, pass: pass,
        uniforms: AquariumUniforms(
          ink: ink, paper: paper,
          scene: SIMD4(240 * aspect, 240, model.simulation.time, model.simulation.foodAge),
          activity: SIMD4(
            model.simulation.current, model.simulation.bubbles, growth, model.simulation.sulk)))
      command.present(drawable)
      command.commit()
    }
  }
}

private enum AquariumError: LocalizedError {
  case unavailable, missingShader
  var errorDescription: String? {
    switch self {
    case .unavailable: "A Metal-capable GPU is needed for this fish tank."
    case .missingShader: "The aquarium shader is missing from the app bundle."
    }
  }
}
