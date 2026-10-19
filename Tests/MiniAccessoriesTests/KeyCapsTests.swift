import AppKit
import Testing

@testable import MiniAccessories

@Test func physicalKeysTrackChordsRepeatsAndReleaseIndependently() {
  let keys = KeyCapsInput.pressed([], code: 0, down: true)
  #expect(KeyCapsInput.pressed(keys, code: 0, down: true) == keys)
  let chord = KeyCapsInput.pressed(keys, code: 1, down: true)
  #expect(KeyCapsInput.pressed(chord, code: 0, down: false) == [1])
  #expect(KeyCapsInput.rows.map(\.count) == [12, 12, 11, 10])
  #expect(Set(KeyCapsInput.rows.flatMap { $0 }).count == 45)
}

@Test @MainActor func disablingAndDismantlingKeyCapsClearsHeldKeys() {
  let view = KeyCapsEventSource.Anchor()
  var last = Set<UInt16>()
  view.changed = { keys, _ in last = keys }
  view.keys = [0, 1]
  view.clear()
  #expect(view.keys.isEmpty && last.isEmpty)
  view.keys = [49]
  view.stop()
  #expect(view.keys.isEmpty && last.isEmpty)
}

@Test func capsLockOnlyChangesLettersAndCombinesWithShift() {
  #expect(KeyCapsInput.characters("a1/", shifted: "A!?", shift: false, caps: true) == "A1/")
  #expect(KeyCapsInput.characters("a1/", shifted: "A!?", shift: true, caps: true) == "a!?")
}
