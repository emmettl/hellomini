import Foundation
import Observation

/// Effect modules supply metadata; the host registers the effects it actually implements.
public struct MiniPlayfulEffect: Identifiable, Hashable, Sendable {
  public let id: String
  public let name: String
  public let description: String
  public let enabledByDefault: Bool

  public init(id: String, name: String, description: String, enabledByDefault: Bool = true) {
    precondition(!id.isEmpty)
    self.id = id
    self.name = name
    self.description = description
    self.enabledByDefault = enabledByDefault
  }
}

@MainActor @Observable public final class PlayfulnessSettings {
  public private(set) var enabled: Bool
  public let effects: [MiniPlayfulEffect]
  private var selections: [String: Bool]
  @ObservationIgnored private let defaults: UserDefaults
  private static let enabledKey = "playfulness.enabled"
  private static let effectsKey = "playfulness.effects"

  public init(defaults: UserDefaults = .standard, effects: [MiniPlayfulEffect]) {
    precondition(Set(effects.map(\.id)).count == effects.count, "Effect IDs must be unique")
    self.defaults = defaults
    self.effects = effects
    enabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    selections = defaults.dictionary(forKey: Self.effectsKey) as? [String: Bool] ?? [:]
  }

  public func setEnabled(_ enabled: Bool) {
    self.enabled = enabled
    defaults.set(enabled, forKey: Self.enabledKey)
  }

  /// Individual choices survive disabling the master switch or removing an effect module.
  public func isSelected(_ id: String) -> Bool {
    guard let effect = effects.first(where: { $0.id == id }) else { return false }
    return selections[id] ?? effect.enabledByDefault
  }

  public func allows(_ id: String) -> Bool { enabled && isSelected(id) }

  @discardableResult public func setSelected(_ selected: Bool, for id: String) -> Bool {
    guard effects.contains(where: { $0.id == id }) else { return false }
    selections[id] = selected
    defaults.set(selections, forKey: Self.effectsKey)
    return true
  }
}
