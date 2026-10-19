import Foundation
import MiniCore
import Observation

struct DesktopPreset: Codable, Identifiable {
  var id = UUID()
  var name: String
  var themeID: String
  var pattern: [UInt8]?
  var purist: Bool
  var tiny: Bool
  var session: DesktopSession
  var isValid: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80
      && !themeID.isEmpty && themeID.count <= 80 && !(purist && tiny)
      && (pattern == nil || pattern?.count == 8) && session.version == 1
      && session.openIDs.count <= 64 && Set(session.openIDs).count == session.openIDs.count
      && session.openIDs.allSatisfy { !$0.isEmpty && $0.count <= 100 }
      && session.windows.count <= 64 && session.windows.values.allSatisfy { $0.isValid }
  }
}
private struct PresetDocument: Codable {
  var version = 1
  var presets: [DesktopPreset]
}
@MainActor @Observable final class DesktopPresetStore {
  private(set) var presets: [DesktopPreset] = []
  private(set) var error: String?
  private(set) var readable = true
  @ObservationIgnored private let defaults: UserDefaults
  static let key = "desktop.presets.v1"
  init(defaults: UserDefaults) {
    self.defaults = defaults
    reload()
  }
  /// Retry only after the user has repaired the saved preferences; never reset implicitly.
  func reload() {
    do {
      let value = defaults.object(forKey: Self.key)
      if let value {
        guard let data = value as? Data else { throw PresetError.invalid }
        presets = try Self.previewImport(data)
      } else {
        presets = []
      }
      readable = true
      error = nil
    } catch {
      readable = false
      self.error =
        "Saved presets could not be read. The original is preserved and saving is paused. Repair the saved preferences, then retry."
    }
  }

  func save(
    name: String, replacing id: UUID? = nil, model: DesktopModel, settings: AppearanceSettings
  ) {
    do {
      guard readable else { throw PresetError.invalid }
      let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard
        !presets.contains(where: {
          $0.id != id && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        })
      else { throw PresetError.duplicate }
      let preset = DesktopPreset(
        id: id ?? UUID(), name: name, themeID: settings.theme.id,
        pattern: settings.customPattern?.rows, purist: settings.puristMode,
        tiny: settings.tinyScreenMode, session: model.snapshot())
      guard preset.isValid, id != nil || presets.count < 20 else { throw PresetError.invalid }
      var next = presets.filter { $0.id != preset.id }
      next.append(preset)
      try persist(next)
    } catch { self.error = error.localizedDescription }
  }
  func remove(_ id: UUID) {
    guard readable else { return }
    do { try persist(presets.filter { $0.id != id }) } catch {
      self.error = error.localizedDescription
    }
  }
  func apply(_ preset: DesktopPreset, model: DesktopModel, settings: AppearanceSettings) -> Bool {
    guard preset.isValid, settings.availableThemes.contains(where: { $0.id == preset.themeID })
    else {
      error = "This preset needs a theme that is not installed. The desktop was left unchanged."
      return false
    }
    settings.selectTheme(id: preset.themeID)
    settings.setPattern(preset.pattern.flatMap(DesktopPattern.init(rows:)))
    settings.setPuristMode(preset.purist)
    settings.setTinyScreenMode(preset.tiny)
    model.apply(preset.session)
    error = nil
    return true
  }
  func exportData() throws -> Data {
    guard readable else { throw PresetError.invalid }
    return try JSONEncoder().encode(PresetDocument(presets: presets))
  }
  static func previewImport(_ data: Data) throws -> [DesktopPreset] {
    guard data.count <= 500_000 else { throw PresetError.invalid }
    let document = try JSONDecoder().decode(PresetDocument.self, from: data)
    guard document.version == 1, document.presets.count <= 20,
      document.presets.allSatisfy(\.isValid),
      Set(document.presets.map(\.id)).count == document.presets.count
    else { throw PresetError.invalid }
    return document.presets
  }
  func importPresets(_ incoming: [DesktopPreset]) throws {
    guard readable, incoming.count <= 20, incoming.allSatisfy(\.isValid) else {
      throw PresetError.invalid
    }
    var next = presets
    for var preset in incoming {
      // Identical payloads are skipped; conflicting identifiers get a new identity/name.
      let encoder = JSONEncoder()
      encoder.outputFormatting = .sortedKeys
      if try next.contains(where: { try encoder.encode($0) == encoder.encode(preset) }) { continue }
      if next.contains(where: { $0.id == preset.id }) { preset.id = UUID() }
      let base = String(preset.name.prefix(65))
      var suffix = 2
      while next.contains(where: {
        $0.name.localizedCaseInsensitiveCompare(preset.name) == .orderedSame
      }) {
        preset.name = "\(base) (\(suffix))"
        suffix += 1
      }
      next.append(preset)
    }
    guard next.count <= 20 else { throw PresetError.invalid }
    try persist(next)
  }
  private func persist(_ next: [DesktopPreset]) throws {
    // A different session/version may have replaced preferences since this store loaded.
    if let value = defaults.object(forKey: Self.key) {
      guard let original = value as? Data else { throw PresetError.unreadable }
      do { _ = try Self.previewImport(original) } catch { throw PresetError.unreadable }
      defaults.set(original, forKey: Self.key + ".previous")
    }
    let data = try JSONEncoder().encode(PresetDocument(presets: next))
    guard data.count <= 500_000 else { throw PresetError.invalid }
    defaults.set(data, forKey: Self.key)
    presets = next
    error = nil
  }
}
private enum PresetError: LocalizedError {
  case invalid, duplicate, unreadable
  var errorDescription: String? {
    switch self {
    case .unreadable:
      "Saved presets changed and could not be read. The original is preserved. Repair the saved preferences, then retry."
    case .invalid:
      "Use a name of 1–80 characters and at most 20 presets. The saved preset must contain a supported desktop layout."
    case .duplicate:
      "A preset already has that name. Choose another name or replace the selected preset."
    }
  }
}
