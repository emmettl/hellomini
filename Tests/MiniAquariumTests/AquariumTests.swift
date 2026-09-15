import AppKit
import Metal
import MiniCore
import Testing

@testable import MiniAquarium

@Test func swimmingPausesWithoutCatchUpAndFeedingSurvivesPause() {
  var simulation = AquariumSimulation()
  simulation.advance(now: 10, animate: true, feedRevision: 0)
  simulation.advance(now: 10.05, animate: true, feedRevision: 0)
  #expect(abs(simulation.time - 0.05) < 0.001)
  simulation.advance(now: 20, animate: false, feedRevision: 1)
  #expect(simulation.foodAge == 0)
  simulation.advance(now: 500, animate: false, feedRevision: 1)
  #expect(simulation.foodAge == 0)
  simulation.advance(
    now: 600, animate: false, feedRevision: 1,
    activity: AquariumActivity(cpu: 1, bytesPerSecond: 10_000_000))
  #expect(simulation.current == 0 && simulation.bubbles == 0)
  simulation.advance(now: 1000, animate: true, feedRevision: 1)
  #expect(abs(simulation.time - 0.05) < 0.001)
  simulation.advance(now: 1000.05, animate: true, feedRevision: 1)
  #expect(abs(simulation.foodAge - 0.05) < 0.001)
  simulation.advance(now: 2000, animate: true, feedRevision: 1)
  #expect(simulation.time < 0.21)
}

@Test func activityUsesCounterDeltasAndRejectsNetworkResets() {
  let first = AquariumCounters(ticks: [100, 200, 300, 0], networkBytes: 2000, time: 1)
  let next = AquariumCounters(ticks: [110, 210, 360, 0], networkBytes: 6000, time: 3)
  let activity = next.activity(since: first)
  #expect(activity.cpu == 0.25)
  #expect(activity.bytesPerSecond == 2000)
  #expect(activity.bubbles > 0 && activity.bubbles < 1)
  let reset = AquariumCounters(ticks: next.ticks, networkBytes: 10, time: 4)
  #expect(reset.activity(since: next).bytesPerSecond == nil)
  #expect(reset.activity(since: next).cpu == nil)
  let wrapped = AquariumCounters(ticks: [4, 0, 10, 0], networkBytes: nil, time: 5)
  let before = AquariumCounters(ticks: [.max - 5, 0, 0, 0], networkBytes: nil, time: 4)
  #expect(wrapped.activity(since: before).cpu == 0.5)
}

@Test @MainActor func aquariumActivityIsOptInAndPreferencesSurviveMasterSwitch() throws {
  let name = "AquariumTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: name))
  defer { defaults.removePersistentDomain(forName: name) }
  let settings = PlayfulnessSettings(defaults: defaults, effects: AquariumApplication.effects)
  #expect(settings.allows(AquariumApplication.animation.id))
  #expect(!settings.allows(AquariumApplication.activity.id))
  settings.setSelected(true, for: AquariumApplication.activity.id)
  settings.setEnabled(false)
  #expect(!settings.allows(AquariumApplication.activity.id))
  settings.setEnabled(true)
  let restored = PlayfulnessSettings(defaults: defaults, effects: AquariumApplication.effects)
  #expect(restored.allows(AquariumApplication.activity.id))
}

@Test(
  .enabled(
    if: ProcessInfo.processInfo.environment["MINI_ALLOW_MISSING_METAL"] != "1"
      || MTLCreateSystemDefaultDevice() != nil,
    "Hosted CI may lack Metal; the physical Mini requires this rendering test."))
@MainActor func aquariumRendersAnimationFoodActivityAndThemePalette() throws {
  let device = try #require(MTLCreateSystemDefaultDevice())
  let gpu = try AquariumGPU(device: device)
  let width = 640
  let height = 360
  let descriptor = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
  descriptor.usage = .renderTarget
  descriptor.storageMode = .shared
  let target = try #require(device.makeTexture(descriptor: descriptor))
  func render(
    time: Float = 5, food: Float = 20, inverse: Bool = false, activity: Float = 0,
    growth: Float = 0, sulk: Float = 0
  ) throws
    -> [UInt8]
  {
    let command = try #require(gpu.queue.makeCommandBuffer())
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = target
    pass.colorAttachments[0].loadAction = .dontCare
    pass.colorAttachments[0].storeAction = .store
    let ink: Float = inverse ? 1 : 0
    let paper: Float = inverse ? 0 : 1
    gpu.encode(
      command: command, pass: pass,
      uniforms: AquariumUniforms(
        ink: SIMD4(ink, ink, ink, 1), paper: SIMD4(paper, paper, paper, 1),
        scene: SIMD4(Float(width) / Float(height) * 240, 240, time, food),
        activity: SIMD4(activity, activity, growth, sulk)))
    command.commit()
    command.waitUntilCompleted()
    #expect(command.status == .completed)
    #expect(command.error == nil)
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    bytes.withUnsafeMutableBytes {
      target.getBytes(
        $0.baseAddress!, bytesPerRow: width * 4,
        from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
    }
    return bytes
  }
  let frame = try render()
  let values = stride(from: 0, to: frame.count, by: 4).map { frame[$0] }
  #expect(Set(values) == [0, 255])
  #expect(values.filter { $0 == 0 }.count > 5000)
  #expect(values.filter { $0 == 255 }.count > width * height / 2)
  let inverse = try render(inverse: true)
  #expect(
    stride(from: 0, to: frame.count, by: 4).allSatisfy { Int(frame[$0]) + Int(inverse[$0]) == 255 })
  let later = try render(time: 9)
  #expect(zip(frame, later).filter { $0 != $1 }.count > 10000)
  #expect(try render(food: 4) != frame)
  #expect(try render(activity: 1) != frame)
  #expect(try render(growth: 1) != frame)
  #expect(try render(sulk: 1) != frame)
  if let path = ProcessInfo.processInfo.environment["MINI_AQUARIUM_PROOF_PATH"] {
    let bitmap = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: width * 4, bitsPerPixel: 32))
    let pixels = try #require(bitmap.bitmapData)
    for offset in stride(from: 0, to: frame.count, by: 4) {
      pixels[offset] = frame[offset + 2]
      pixels[offset + 1] = frame[offset + 1]
      pixels[offset + 2] = frame[offset]
      pixels[offset + 3] = frame[offset + 3]
    }
    try #require(bitmap.representation(using: .png, properties: [:])).write(to: URL(filePath: path))
  }
}
