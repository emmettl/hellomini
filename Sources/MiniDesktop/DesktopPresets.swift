import Foundation
import MiniCore
import MiniUI
import Observation
import SwiftUI

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
    guard let data = defaults.data(forKey: Self.key) else { return }
    do {
      guard data.count <= 500_000 else { throw PresetError.invalid }
      let doc = try JSONDecoder().decode(PresetDocument.self, from: data)
      guard doc.version == 1, doc.presets.count <= 20, doc.presets.allSatisfy(\.isValid),
        Set(doc.presets.map(\.id)).count == doc.presets.count
      else { throw PresetError.invalid }
      presets = doc.presets
    } catch {
      readable = false
      self.error =
        "Saved presets could not be read. They have been preserved; repair the saved preferences before replacing them."
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
  private func persist(_ next: [DesktopPreset]) throws {
    let data = try JSONEncoder().encode(PresetDocument(presets: next))
    guard data.count <= 500_000 else { throw PresetError.invalid }
    defaults.set(data, forKey: Self.key)
    presets = next
    error = nil
  }
}
private enum PresetError: LocalizedError {
  case invalid, duplicate
  var errorDescription: String? {
    switch self {
    case .invalid:
      "Use a name of 1–80 characters and at most 20 presets. The saved preset must contain a supported desktop layout."
    case .duplicate:
      "A preset already has that name. Choose another name or replace the selected preset."
    }
  }
}
struct DesktopPresetsView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.miniTheme) private var theme
  let store: DesktopPresetStore
  let model: DesktopModel
  let settings: AppearanceSettings
  @State private var name = ""
  @State private var selection: UUID?
  @State private var confirmReplace = false
  @State private var confirmDelete = false
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Desktop Presets").font(theme.typography.title)
      Text("A desk for work. A desk for fish. Same computer.").font(theme.typography.small)
      if store.presets.isEmpty {
        Text("No desks on file. Arrange your windows, then save this desktop.")
      } else {
        Picker("Saved desk", selection: $selection) {
          Text("Choose a preset").tag(Optional<UUID>.none)
          ForEach(store.presets) { Text($0.name).tag(Optional($0.id)) }
        }
        if let selected = store.presets.first(where: { $0.id == selection }) {
          Text(
            "\(selected.session.openIDs.count) windows · \(selected.themeID) · \(selected.purist ? "Purist" : selected.tiny ? "2×" : "Standard")"
          )
          .font(theme.typography.small)
          HStack {
            Button("Use this desk") {
              if store.apply(selected, model: model, settings: settings) { dismiss() }
            }
            Button("Replace…") { confirmReplace = true }
            Button("Delete…") { confirmDelete = true }
          }
        }
      }
      Divider()
      TextField("Name for this desktop", text: $name)
      Button("Save current desktop") {
        store.save(name: name, model: model, settings: settings)
        if store.error == nil { name = "" }
      }
      .disabled(
        !store.readable || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          || store.presets.count >= 20)
      Text(
        "Saves theme, pattern, display mode and window arrangement. Other open windows are minimised when switching; their contents remain intact. Presets do not change app settings or data."
      )
      .font(theme.typography.small)
      if let error = store.error {
        Text(error).font(theme.typography.small).foregroundStyle(theme.accent)
      }
      HStack {
        Spacer()
        Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
      }
    }.padding(16).font(theme.typography.body).foregroundStyle(theme.ink).buttonStyle(
      RetroButtonStyle()
    )
    .confirmationDialog(
      "Replace this preset with the current desktop?", isPresented: $confirmReplace
    ) {
      Button("Replace preset") {
        if let selected = store.presets.first(where: { $0.id == selection }) {
          store.save(name: selected.name, replacing: selected.id, model: model, settings: settings)
        }
      }
    }
    .confirmationDialog(
      "Delete this saved desktop preset? Application data is kept.", isPresented: $confirmDelete
    ) {
      Button("Delete preset") {
        if let selection { store.remove(selection) }
        selection = nil
      }
    }
  }
}
