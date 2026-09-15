import AppKit
import MetalKit
import MiniCore
import SwiftUI

/// Shared, bounded GPU spectacle for desk accessories. Useful content stays in its owning app.
public struct MiniMetalScene: View {
  public enum Scene: Float { case mathematics, globe, toasters }
  @Environment(\.miniTheme) private var theme
  @Environment(\.miniWindowVisible) private var visible
  @Environment(\.self) private var environment
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var error: String?
  private let scene: Scene
  private let animate: Bool
  public init(_ scene: Scene, animate: Bool) {
    self.scene = scene
    self.animate = animate
  }
  public var body: some View {
    Group {
      if let error {
        Text(error).font(theme.typography.small).padding()
      } else {
        MetalSceneView(
          scene: scene.rawValue, ink: rgba(theme.ink), paper: rgba(theme.paper),
          animate: animate && visible && !reduceMotion, error: $error)
      }
    }

  }
  private func rgba(_ color: Color) -> SIMD4<Float> {
    let c = color.resolve(in: environment)
    return SIMD4(c.red, c.green, c.blue, c.opacity)
  }
}

struct DeskSceneUniforms {
  var ink: SIMD4<Float>
  var paper: SIMD4<Float>
  var options: SIMD4<Float>
}

@MainActor final class DeskSceneGPU {
  let queue: MTLCommandQueue
  let pipeline: MTLRenderPipelineState
  init(device: MTLDevice) throws {
    guard let queue = device.makeCommandQueue() else { throw CocoaError(.featureUnsupported) }
    self.queue = queue
    let bundle = MiniResourceBundle.resolve(named: "HelloMini_MiniUI", developmentBundle: .module)
    guard
      let url = bundle.url(
        forResource: "DeskScenes", withExtension: "metal", subdirectory: "Resources")
    else { throw CocoaError(.fileReadNoSuchFile) }
    let library = try device.makeLibrary(
      source: String(contentsOf: url, encoding: .utf8), options: nil)
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "deskVertex")
    descriptor.fragmentFunction = library.makeFunction(name: "deskFragment")
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
  }
  func encode(
    _ command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, uniforms: DeskSceneUniforms
  ) {
    guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
    var uniforms = uniforms
    encoder.setRenderPipelineState(pipeline)
    encoder.setFragmentBytes(&uniforms, length: MemoryLayout<DeskSceneUniforms>.stride, index: 0)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder.endEncoding()
  }
}

private struct MetalSceneView: NSViewRepresentable {
  let scene: Float
  let ink: SIMD4<Float>
  let paper: SIMD4<Float>
  let animate: Bool
  @Binding var error: String?
  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeNSView(context: Context) -> MiniMetalView {
    let view = BoundedMetalView(frame: .zero, device: MTLCreateSystemDefaultDevice())
    view.autoResizeDrawable = false
    view.activeFramesPerSecond = 30
    view.colorPixelFormat = .bgra8Unorm
    view.isPaused = true
    do {
      guard let device = view.device else { throw CocoaError(.featureUnsupported) }
      context.coordinator.gpu = try DeskSceneGPU(device: device)
      view.delegate = context.coordinator
    } catch {
      Task { @MainActor in
        self.error = "The graphics demo is unavailable. \(error.localizedDescription)"
      }
    }
    view.setAccessibilityElement(true)
    view.setAccessibilityLabel(
      scene == 0
        ? "Animated Mandelbrot mathematics"
        : scene == 1 ? "Decorative rotating globe" : "Flying winged toasters and slices of toast")
    return view
  }
  func updateNSView(_ view: MiniMetalView, context: Context) {
    let c = context.coordinator
    c.scene = scene
    c.ink = ink
    c.paper = paper
    if c.animate != animate { c.previous = nil }
    c.animate = animate
    view.wantsAnimation = animate && c.gpu != nil
    if view.isPaused { view.draw() }
  }
  static func dismantleNSView(_ view: MiniMetalView, coordinator: Coordinator) {
    view.wantsAnimation = false
    view.delegate = nil
  }
  @MainActor final class Coordinator: NSObject, MTKViewDelegate {
    var gpu: DeskSceneGPU?
    var scene: Float = 0
    var ink = SIMD4<Float>(0, 0, 0, 1)
    var paper = SIMD4<Float>(1, 1, 1, 1)
    var animate = false
    var previous: TimeInterval?
    var time: Double = 0
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { previous = nil }
    func draw(in view: MTKView) {
      guard let gpu, view.window?.occlusionState.contains(.visible) == true,
        !view.isHiddenOrHasHiddenAncestor, let pass = view.currentRenderPassDescriptor,
        let drawable = view.currentDrawable, let command = gpu.queue.makeCommandBuffer()
      else {
        previous = nil
        return
      }
      let now = CACurrentMediaTime()
      if animate, let previous { time = AnimationClock.advance(time, by: min(0.1, now - previous)) }
      previous = animate ? now : nil
      gpu.encode(
        command, pass: pass,
        uniforms: DeskSceneUniforms(
          ink: ink, paper: paper,
          options: SIMD4(
            Float(view.drawableSize.width / max(1, view.drawableSize.height)), Float(time), scene, 0
          )))
      command.present(drawable)
      command.commit()
    }
  }
}

private final class BoundedMetalView: MiniMetalView {
  override func layout() {
    super.layout()
    let scale = min(2, 800 / max(1, bounds.width), 600 / max(1, bounds.height))
    let size = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
    if drawableSize != size { drawableSize = size }
  }
}
