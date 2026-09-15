import Foundation
import MiniCore
import Testing

@testable import MiniAquarium

@Test @MainActor func fishRememberGreenStreaksAndSulkAfterFailures() throws {
  let name = "BuildMemoryTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: name))
  defer { defaults.removePersistentDomain(forName: name) }
  let settings = PlayfulnessSettings(defaults: defaults, effects: AquariumApplication.effects)
  #expect(settings.allows(AquariumApplication.buildMemory.id))
  let aquarium = AquariumApplication(playfulness: settings, defaults: defaults)
  aquarium.feedFromSuccessfulBuilds(3)
  #expect(aquarium.model.streak == 3 && aquarium.model.residents == 9)
  aquarium.feedFromSuccessfulBuilds(2)
  #expect(aquarium.model.residents == 10 && aquarium.model.growth == 0.5)
  let relaunched = AquariumModel(defaults: defaults)
  #expect(relaunched.streak == 5 && !relaunched.sulking)
  aquarium.recordFailedBuilds(1)
  #expect(aquarium.model.streak == 0 && aquarium.model.sulking)
  #expect(AquariumModel(defaults: defaults).sulking)
  #expect(aquarium.model.moodNote?.contains("sulking") == true)
  aquarium.feedFromSuccessfulBuilds(1)
  #expect(!aquarium.model.sulking && aquarium.model.streak == 1)
  settings.setSelected(false, for: AquariumApplication.buildMemory.id)
  aquarium.recordFailedBuilds(2)
  aquarium.feedFromSuccessfulBuilds(4)
  #expect(aquarium.model.streak == 1 && !aquarium.model.sulking)
}

@Test func sulkingEasesWhileSwimmingAndSnapsWhilePaused() {
  var simulation = AquariumSimulation()
  simulation.advance(now: 1, animate: true, feedRevision: 0, sulking: true)
  simulation.advance(now: 1.05, animate: true, feedRevision: 0, sulking: true)
  #expect(simulation.sulk > 0 && simulation.sulk < 0.2)
  simulation.advance(now: 2, animate: false, feedRevision: 0, sulking: false)
  #expect(simulation.sulk == 0)
  simulation.advance(now: 3, animate: false, feedRevision: 0, sulking: true)
  #expect(simulation.sulk == 1)
}
