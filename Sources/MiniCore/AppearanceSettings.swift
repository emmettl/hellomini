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
  public let availableThemes: [MiniTheme]
  @ObservationIgnored private let defaults: UserDefaults
  static let themeKey = "appearance.theme"

  public init(defaults: UserDefaults = .standard, themes: [MiniTheme] = MiniTheme.builtIns) {
    precondition(!themes.isEmpty, "At least one theme is required")
    precondition(Set(themes.map(\.id)).count == themes.count, "Theme IDs must be unique")
    self.defaults = defaults
    availableThemes = themes
    let savedID = defaults.string(forKey: Self.themeKey)
    theme =
      themes.first { $0.id == savedID }
      ?? themes.first { $0.id == MiniTheme.classic.id } ?? themes[0]
  }

  /// Unknown IDs cannot leave settings pointing at a renderer that isn't installed.
  @discardableResult public func selectTheme(id: String) -> Bool {
    guard let selection = availableThemes.first(where: { $0.id == id }) else { return false }
    theme = selection
    defaults.set(selection.id, forKey: Self.themeKey)
    return true
  }
}
