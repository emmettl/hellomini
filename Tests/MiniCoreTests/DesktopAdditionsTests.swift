import AppKit
import Testing

@testable import MiniCore

@Test @MainActor func customPatternRoundTripAndInvalidData() throws {
  let suite = "PatternTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let settings = AppearanceSettings(defaults: defaults)
  var pattern = DesktopPattern.initial
  let before = pattern.contains(x: 7, y: 7)
  pattern.toggle(x: 7, y: 7)
  #expect(pattern.contains(x: 7, y: 7) != before)
  let valid = pattern
  pattern.toggle(x: -1, y: 8)
  #expect(pattern == valid)
  settings.setPattern(pattern)
  #expect(AppearanceSettings(defaults: defaults).customPattern == pattern)
  settings.setPattern(nil)
  #expect(AppearanceSettings(defaults: defaults).customPattern == nil)
  defaults.set(Data([1, 2, 3]), forKey: "appearance.desktopPattern")
  #expect(AppearanceSettings(defaults: defaults).customPattern == nil)
}

@Test @MainActor func originalSoundsDecodeAsBoundedPCMWithoutPlaying() {
  for cue in SystemSounds.Cue.allCases {
    let wave = SystemSounds.wave(cue)
    #expect(wave.count > 44 && wave.count < 44_100)
    #expect(String(data: wave.prefix(4), encoding: .utf8) == "RIFF")
    #expect(NSSound(data: wave) != nil)
  }
}
