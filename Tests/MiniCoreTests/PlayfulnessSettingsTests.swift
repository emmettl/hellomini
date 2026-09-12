import Foundation
import Testing

@testable import MiniCore

private let motion = MiniPlayfulEffect(id: "demo.motion", name: "Motion", description: "A demo")
private let particles = MiniPlayfulEffect(
  id: "demo.particles", name: "Particles", description: "Another demo", enabledByDefault: false)

@Test @MainActor func effectChoicesPersistIndependentlyOfTheMasterSwitch() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let settings = PlayfulnessSettings(defaults: defaults, effects: [motion, particles])
  #expect(settings.allows(motion.id))
  #expect(!settings.allows(particles.id))
  settings.setSelected(false, for: motion.id)
  settings.setSelected(true, for: particles.id)
  settings.setEnabled(false)

  let restored = PlayfulnessSettings(defaults: defaults, effects: [motion, particles])
  #expect(!restored.enabled)
  #expect(!restored.allows(particles.id))
  #expect(restored.isSelected(particles.id))
  restored.setEnabled(true)
  #expect(restored.allows(particles.id))
  #expect(!restored.allows(motion.id))
  #expect(PlayfulnessSettings(defaults: defaults, effects: [motion]).enabled)
}

@Test @MainActor func unavailableEffectsCannotRunAndKeepTheirSavedChoices() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let settings = PlayfulnessSettings(defaults: defaults, effects: [motion, particles])
  settings.setSelected(false, for: motion.id)
  let removed = PlayfulnessSettings(defaults: defaults, effects: [particles])
  #expect(!removed.allows(motion.id))
  #expect(!removed.setSelected(true, for: motion.id))
  removed.setSelected(true, for: particles.id)
  let reinstalled = PlayfulnessSettings(defaults: defaults, effects: [motion, particles])
  #expect(!reinstalled.isSelected(motion.id))
  #expect(reinstalled.isSelected(particles.id))
  #expect(!reinstalled.allows("unknown"))
}

@Test @MainActor func themeChangesDoNotAlterPlayfulnessPreferences() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let settings = PlayfulnessSettings(defaults: defaults, effects: [motion])
  settings.setEnabled(false)
  AppearanceSettings(defaults: defaults).selectTheme(id: MiniTheme.midnight.id)
  #expect(!PlayfulnessSettings(defaults: defaults, effects: [motion]).enabled)
  settings.setEnabled(true)
  #expect(AppearanceSettings(defaults: defaults).theme == .midnight)
}
