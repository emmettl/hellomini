import Foundation
import Testing

@testable import MiniClock

@Test @MainActor func clocksPersistAndHandleDaylightSavingAndWeekends() throws {
  let suite = "WorldClockTests-\(UUID())"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  defaults.set(["UTC", "UTC", "invalid/zone"], forKey: "worldClock.zones")
  let model = WorldClockModel(defaults: defaults)
  #expect(model.zones == ["UTC"])
  model.add("Asia/Tokyo")
  #expect(WorldClockModel(defaults: defaults).zones == ["UTC", "Asia/Tokyo"])
  let ny = try #require(TimeZone(identifier: "America/New_York"))
  let before = try #require(ISO8601DateFormatter().date(from: "2026-03-08T06:30:00Z"))
  let after = before.addingTimeInterval(3600)
  #expect(ny.secondsFromGMT(for: after) - ny.secondsFromGMT(for: before) == 3600)
  #expect(!WorldClockModel.working(after, zone: ny, start: 0, end: 24))
  let monday = try #require(ISO8601DateFormatter().date(from: "2026-03-09T14:00:00Z"))
  #expect(WorldClockModel.working(monday, zone: ny, start: 9, end: 17))
}
