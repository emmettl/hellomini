import Foundation
import MiniCore
import Testing

@testable import MiniMoose

@Test @MainActor func mooseStaysQuietUntilEnabledAndRationsItsRemarks() throws {
  let name = "TalkingMooseTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: name))
  defer { defaults.removePersistentDomain(forName: name) }
  let settings = PlayfulnessSettings(defaults: defaults, effects: [TalkingMoose.effect])
  #expect(!settings.allows(TalkingMoose.effect.id))
  var spoken: [String] = []
  var clock = Date(timeIntervalSince1970: 1000)
  let moose = TalkingMoose(
    settings: settings, speak: { spoken.append($0) }, now: { clock }, pick: { _ in 0 })
  moose.react(to: .failed(1))
  #expect(spoken.isEmpty && moose.remark == nil)

  settings.setSelected(true, for: TalkingMoose.effect.id)
  moose.react(to: .failed(1))
  #expect(spoken == ["Your build failed. Again."])
  #expect(moose.remark == "Your build failed. Again.")
  moose.react(to: .passed(1))
  #expect(spoken.count == 1)

  clock = clock.addingTimeInterval(TalkingMoose.quietInterval + 1)
  moose.react(to: .passed(3))
  #expect(spoken.last == "3 builds passed. Suspicious.")
  moose.dismiss()
  #expect(moose.remark == nil)

  settings.setEnabled(false)
  clock = clock.addingTimeInterval(120)
  moose.react(to: .failed(2))
  #expect(spoken.count == 2)
}

@Test func everyMooseLineIsShortAndSafeForAnyPick() {
  for event: TalkingMoose.Event in [.passed(1), .passed(4), .failed(1), .failed(2)] {
    for pick in [-5, 0, 1, 2, 3, 99] {
      let line = TalkingMoose.line(for: event, pick: { _ in pick })
      #expect(!line.isEmpty && line.count <= 80)
    }
  }
}
