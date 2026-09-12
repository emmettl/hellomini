import AppKit
import Metal
import Testing
import simd

@testable import MiniTeapot

@Test func teapotMeshHasFiniteNormalsAndCompleteSymmetry() throws {
  let mesh = try TeapotMesh.make()
  #expect(mesh.vertices.count == 32 * 17 * 17)
  #expect(mesh.indices.count == 32 * 16 * 16 * 6)
  #expect(mesh.indices.allSatisfy { Int($0) < mesh.vertices.count })
  for vertex in mesh.vertices {
    #expect((0..<4).allSatisfy { vertex.position[$0].isFinite && vertex.normal[$0].isFinite })
    #expect(abs(simd_length(vertex.normal) - 1) < 0.001)
  }
  let positions = mesh.vertices.map(\.position)
  #expect(positions.map(\.x).min()! < -2.9)  // Handle
  #expect(positions.map(\.x).max()! > 3.4)  // Spout
  #expect(abs(positions.map(\.z).min()! + positions.map(\.z).max()!) < 0.001)
}

@Test(
  .enabled(
    if: ProcessInfo.processInfo.environment["MINI_ALLOW_MISSING_METAL"] != "1"
      || MTLCreateSystemDefaultDevice() != nil,
    "Hosted CI can omit this test when Metal is unavailable; the physical Mini requires it."))
@MainActor func metalRendersShadingRotationAndThemePalette() throws {
  let device = try #require(
    MTLCreateSystemDefaultDevice(), "This integration test needs a Metal GPU.")
  let gpu = try TeapotGPU(device: device)
  let width = 512
  let height = 320
  let descriptor = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
  descriptor.usage = [.renderTarget]
  descriptor.storageMode = .shared
  let target = try #require(device.makeTexture(descriptor: descriptor))
  descriptor.pixelFormat = .depth32Float
  descriptor.storageMode = .private
  let depth = try #require(device.makeTexture(descriptor: descriptor))
  func render(mode: TeapotMode, angle: Float = -0.35, inverse: Bool = false) throws -> [UInt8] {
    let command = try #require(gpu.queue.makeCommandBuffer())
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = target
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    let paper: Float = inverse ? 0 : 1
    let ink: Float = inverse ? 1 : 0
    pass.colorAttachments[0].clearColor = MTLClearColor(
      red: Double(paper), green: Double(paper), blue: Double(paper), alpha: 1)
    pass.depthAttachment.texture = depth
    pass.depthAttachment.loadAction = .clear
    pass.depthAttachment.storeAction = .dontCare
    pass.depthAttachment.clearDepth = 1
    let uniforms = TeapotUniforms(
      angle: angle, tilt: 0.3, aspect: Float(width) / Float(height),
      ink: SIMD4(ink, ink, ink, 1), paper: SIMD4(paper, paper, paper, 1), mode: mode, pixelSize: 1)
    gpu.encode(command: command, pass: pass, uniforms: uniforms, wireframe: mode == .wireframe)
    command.commit()
    command.waitUntilCompleted()
    #expect(command.status == .completed)
    #expect(command.error == nil)
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    bytes.withUnsafeMutableBytes { buffer in
      target.getBytes(
        buffer.baseAddress!, bytesPerRow: width * 4,
        from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
    }
    return bytes
  }
  let dither = try render(mode: .dither)
  let values = stride(from: 0, to: dither.count, by: 4).map { dither[$0] }
  #expect(Set(values) == [0, 255])
  #expect(values.filter { $0 == 0 }.count > 5000)
  #expect(values.filter { $0 == 255 }.count > 5000)
  let inverse = try render(mode: .dither, inverse: true)
  #expect(
    stride(from: 0, to: dither.count, by: 4).allSatisfy {
      Int(dither[$0]) + Int(inverse[$0]) == 255
    })
  let rotated = try render(mode: .dither, angle: 1.2)
  #expect(zip(dither, rotated).filter { $0 != $1 }.count > 10000)
  let smooth = try render(mode: .smooth)
  #expect(Set(stride(from: 0, to: smooth.count, by: 4).map { smooth[$0] }).count > 50)
  let wireframe = try render(mode: .wireframe)
  #expect(wireframe != dither && wireframe != smooth)
  #expect(wireframe.contains(0))
  if let path = ProcessInfo.processInfo.environment["MINI_TEAPOT_PROOF_PATH"] {
    let bitmap = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: width * 4, bitsPerPixel: 32))
    let pixels = try #require(bitmap.bitmapData)
    for offset in stride(from: 0, to: dither.count, by: 4) {
      pixels[offset] = dither[offset + 2]
      pixels[offset + 1] = dither[offset + 1]
      pixels[offset + 2] = dither[offset]
      pixels[offset + 3] = dither[offset + 3]
    }
    try #require(bitmap.representation(using: .png, properties: [:])).write(to: URL(filePath: path))
  }
}
