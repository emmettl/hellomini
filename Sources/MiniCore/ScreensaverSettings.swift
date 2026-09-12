import Foundation
import Observation

public struct MiniScreensaver: Identifiable, Hashable, Sendable {
  public let id: String
  public let name: String
  public let description: String
  public init(id: String, name: String, description: String) {
    self.id = id
    self.name = name
    self.description = description
  }
}

/// Preferences and preview requests; presentation belongs to the host, never to Control Panel.
@MainActor @Observable public final class ScreensaverSettings {
  public let savers: [MiniScreensaver]
  public private(set) var selectedID: String
  public private(set) var idleMinutes: Int
  public private(set) var previewRevision = 0
  public private(set) var previewID: String?
  public private(set) var isPresenting = false
  public static let delays = [0, 1, 2, 5, 10, 15, 30]
  @ObservationIgnored private let defaults: UserDefaults

  public init(savers: [MiniScreensaver], defaults: UserDefaults = .standard) {
    precondition(!savers.isEmpty && Set(savers.map(\.id)).count == savers.count)
    self.savers = savers
    self.defaults = defaults
    let saved = defaults.string(forKey: "screensaver.selected")
    selectedID = savers.first { $0.id == saved }?.id ?? savers[0].id
    let delay = defaults.integer(forKey: "screensaver.idleMinutes")
    idleMinutes = Self.delays.contains(delay) ? delay : 0
  }
  public func select(_ id: String) {
    guard savers.contains(where: { $0.id == id }) else { return }
    selectedID = id
    defaults.set(id, forKey: "screensaver.selected")
  }
  public func setIdleMinutes(_ minutes: Int) {
    guard Self.delays.contains(minutes) else { return }
    idleMinutes = minutes
    defaults.set(minutes, forKey: "screensaver.idleMinutes")
  }
  public func preview(_ id: String? = nil) {
    let id = id ?? selectedID
    guard savers.contains(where: { $0.id == id }) else { return }
    previewID = id
    previewRevision += 1
  }
  public func setPresenting(_ presenting: Bool) { isPresenting = presenting }
}

/// Uses monotonic time. Ineligible periods and sleep/timer gaps never count as idle time.
public struct ScreensaverIdleClock {
  private var lastActivity: TimeInterval?
  private var lastTick: TimeInterval?
  public init() {}
  public mutating func reset(now: TimeInterval) {
    lastActivity = now
    lastTick = now
  }
  public mutating func tick(now: TimeInterval, delay: TimeInterval, eligible: Bool) -> Bool {
    guard eligible, delay > 0, let lastTick, now >= lastTick, now - lastTick < 4,
      let lastActivity
    else {
      reset(now: now)
      return false
    }
    self.lastTick = now
    guard now - lastActivity >= delay else { return false }
    reset(now: now)
    return true
  }
}
