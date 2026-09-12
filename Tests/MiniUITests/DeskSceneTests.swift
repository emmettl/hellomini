import Foundation
import Metal
import Testing

@testable import MiniUI

@Test(
  .enabled(
    if: ProcessInfo.processInfo.environment["MINI_ALLOW_MISSING_METAL"] != "1"
      || MTLCreateSystemDefaultDevice() != nil))
@MainActor func deskScenesRenderAnimateAndRespectPalette() throws {
  let device = try #require(MTLCreateSystemDefaultDevice())
  let gpu = try DeskSceneGPU(device: device)
  let descriptor = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .bgra8Unorm, width: 256, height: 256, mipmapped: false)
  descriptor.usage = .renderTarget
  descriptor.storageMode = .shared
  let target = try #require(device.makeTexture(descriptor: descriptor))
  func render(scene: Float, time: Float, inverse: Bool = false) throws -> [UInt8] {
    let command = try #require(gpu.queue.makeCommandBuffer())
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = target
    pass.colorAttachments[0].loadAction = .dontCare
    pass.colorAttachments[0].storeAction = .store
    let ink: Float = inverse ? 1 : 0
    let paper: Float = inverse ? 0 : 1
    gpu.encode(
      command, pass: pass,
      uniforms: DeskSceneUniforms(
        ink: SIMD4(ink, ink, ink, 1), paper: SIMD4(paper, paper, paper, 1),
        options: SIMD4(1, time, scene, 0)))
    command.commit()
    command.waitUntilCompleted()
    #expect(command.status == .completed && command.error == nil)
    var bytes = [UInt8](repeating: 0, count: 256 * 256 * 4)
    bytes.withUnsafeMutableBytes {
      target.getBytes(
        $0.baseAddress!, bytesPerRow: 1024, from: MTLRegionMake2D(0, 0, 256, 256), mipmapLevel: 0)
    }
    return bytes
  }
  for scene: Float in [0, 1, 2] {
    let frame = try render(scene: scene, time: 0)
    let values = stride(from: 0, to: frame.count, by: 4).map { frame[$0] }
    #expect(Set(values) == [0, 255])
    #expect(values.filter { $0 == 0 }.count > 1000)
    #expect(try render(scene: scene, time: 10) != frame)
    let inverse = try render(scene: scene, time: 0, inverse: true)
    #expect(
      stride(from: 0, to: frame.count, by: 4).allSatisfy {
        Int(frame[$0]) + Int(inverse[$0]) == 255
      })
  }
}
