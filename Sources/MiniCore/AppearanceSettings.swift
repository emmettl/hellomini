import Foundation
import Observation

/// Stable, persistable identity. Rendering lives in MiniUI or a separate theme module.
public struct MiniTheme: Identifiable, Hashable, Sendable {
  public let id: String
  public let name: String
  public let description: String

  public init(id: String, name: String, description: String) {
    precondition(!id.isEmpty, "Theme IDs must not be empty")
    self.id = id
    self.name = name
    self.description = description
  }

  public static let classic = MiniTheme(
    id: "classic", name: "Classic",
    description: "Black ink, white windows, and the familiar dotted desktop.")
  public static let paper = MiniTheme(
    id: "paper", name: "Paper",
    description: "The same crisp interface on a quiet, plain white desktop.")
  public static let midnight = MiniTheme(
    id: "midnight", name: "Midnight",
    description: "White ink on black, with a dotted desktop for late-night builds.")
  public static let builtIns: [MiniTheme] = [.classic, .paper, .midnight]
}

/// The composition root supplies the same catalog to preferences and rendering.
@MainActor @Observable public final class AppearanceSettings {
  public private(set) var theme: MiniTheme
  public private(set) var puristMode: Bool
  public private(set) var tinyScreenMode: Bool
  public private(set) var balloonHelp: Bool
  public private(set) var customPattern: DesktopPattern?
  public let availableThemes: [MiniTheme]
  @ObservationIgnored private let defaults: UserDefaults
  static let themeKey = "appearance.theme"
  static let puristKey = "appearance.puristMode"
  static let tinyScreenKey = "appearance.tinyScreenMode"

  public init(defaults: UserDefaults = .standard, themes: [MiniTheme] = MiniTheme.builtIns) {
    precondition(!themes.isEmpty, "At least one theme is required")
    precondition(Set(themes.map(\.id)).count == themes.count, "Theme IDs must be unique")
    self.defaults = defaults
    balloonHelp = defaults.bool(forKey: "appearance.balloonHelp")
    customPattern = defaults.data(forKey: "appearance.desktopPattern").flatMap {
      DesktopPattern(rows: Array($0))
    }
    puristMode = defaults.object(forKey: Self.puristKey) as? Bool ?? false
    // Older installations only have Purist mode. It wins if conflicting preferences are imported.
    tinyScreenMode =
      !defaults.bool(forKey: Self.puristKey) && defaults.bool(forKey: Self.tinyScreenKey)
    availableThemes = themes
    let savedID = defaults.string(forKey: Self.themeKey)
    theme =
      themes.first { $0.id == savedID }
      ?? themes.first { $0.id == MiniTheme.classic.id } ?? themes[0]
  }

  public func setBalloonHelp(_ enabled: Bool) {
    balloonHelp = enabled
    defaults.set(enabled, forKey: "appearance.balloonHelp")
  }

  public func setPattern(_ pattern: DesktopPattern?) {
    customPattern = pattern
    defaults.set(pattern.map { Data($0.rows) }, forKey: "appearance.desktopPattern")
  }

  public func setPuristMode(_ enabled: Bool) {
    if enabled { setTinyScreenMode(false) }
    puristMode = enabled
    defaults.set(enabled, forKey: Self.puristKey)
  }

  public func setTinyScreenMode(_ enabled: Bool) {
    if enabled { setPuristMode(false) }
    tinyScreenMode = enabled
    defaults.set(enabled, forKey: Self.tinyScreenKey)
  }

  /// Unknown IDs cannot leave settings pointing at a renderer that isn't installed.
  @discardableResult public func selectTheme(id: String) -> Bool {
    guard let selection = availableThemes.first(where: { $0.id == id }) else { return false }
    theme = selection
    defaults.set(selection.id, forKey: Self.themeKey)
    return true
  }
}
