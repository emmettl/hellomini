import AppKit
import MiniCore
import MiniUI
import SwiftUI

struct DesktopPresetsView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.miniTheme) private var theme
  let store: DesktopPresetStore
  let model: DesktopModel
  let settings: AppearanceSettings
  let themes: MiniThemeRegistry
  @State private var name = ""
  @FocusState private var nameFocused: Bool
  @State private var focusRequest = 0
  @State private var selection: UUID?
  @State private var confirmReplace = false
  @State private var confirmDelete = false
  @State private var incoming: [DesktopPreset]?
  @State private var transferError: String?
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ScrollView {
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
              PresetThumbnail(
                preset: selected, theme: themes.definition(for: selected.themeID) ?? theme)
              HStack {
                Button("Use this desk") {
                  if store.apply(selected, model: model, settings: settings) { dismiss() }
                }
                Button("Replace…") { confirmReplace = true }
                Button("Delete…") { confirmDelete = true }
              }
            }
          }
          HStack {
            Button("Export…") { exportPresets() }.disabled(!store.readable)
            Button("Import…") { previewPresets() }.disabled(!store.readable)
          }
          if let incoming {
            ScrollView {
              VStack(alignment: .leading) {
                Text("Review \(incoming.count) presets. Existing presets and documents are kept.")
                ForEach(incoming) { preset in
                  Text(preset.name + " · " + preset.themeID)
                  PresetThumbnail(
                    preset: preset, theme: themes.definition(for: preset.themeID) ?? theme)
                  if themes.definition(for: preset.themeID) == nil {
                    Text(
                      "Theme unavailable; import keeps this preset, but it cannot be applied here.")
                  }
                }
              }
            }.frame(maxHeight: 180)
            HStack {
              Button("Cancel Import") { self.incoming = nil }
              Button("Import Reviewed Presets") {
                do {
                  try store.importPresets(incoming)
                  self.incoming = nil
                  transferError = nil
                } catch { transferError = error.localizedDescription }
              }
            }
          }
          if let transferError { Text(transferError).font(theme.typography.small) }
          Divider()
          TextField("Name for this desktop", text: $name).focused($nameFocused)
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
            Button("Retry saved presets") { store.reload() }
          }
        }
      }
      HStack {
        Spacer()
        Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
      }
    }.frame(width: 400, height: 280).padding(12).font(theme.typography.body).foregroundStyle(
      theme.ink
    ).buttonStyle(
      RetroButtonStyle()
    )
    .onAppear { nameFocused = true }
    .background(
      MiniSheetFocusRestoration(request: focusRequest, active: true) { nameFocused = true }
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
  private func restoreFocus() {
    nameFocused = false
    focusRequest += 1
  }
  private func exportPresets() {
    defer { restoreFocus() }
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "HelloMini-Desktop-Presets.json"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try store.exportData().write(to: url, options: .atomic)
      transferError = nil
    } catch { transferError = error.localizedDescription }
  }
  private func previewPresets() {
    defer { restoreFocus() }
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let handle = try FileHandle(forReadingFrom: url)
      defer { try? handle.close() }
      let data = try handle.read(upToCount: 500_001) ?? Data()
      incoming = try DesktopPresetStore.previewImport(data)
      transferError = nil
    } catch { transferError = error.localizedDescription }
  }

}

struct PresetThumbnail: View {
  let preset: DesktopPreset
  let theme: MiniThemeDefinition
  var body: some View {
    let desktop =
      preset.purist
      ? CGSize(width: 512, height: 384)
      : preset.tiny ? CGSize(width: 640, height: 360) : CGSize(width: 1280, height: 720)
    ZStack(alignment: .topLeading) {
      ThemeSurfaceView(theme.desktop)
      Canvas { context, size in
        let sx = size.width / desktop.width
        let sy = size.height / desktop.height
        for id in preset.session.openIDs where !(preset.session.minimisedIDs ?? []).contains(id) {
          guard let placement = preset.session.windows[id] else { continue }
          let rect = CGRect(
            x: max(0, min(size.width - 12, placement.origin.x * sx)),
            y: max(8, min(size.height - 10, placement.origin.y * sy)),
            width: min(size.width, placement.size.width * sx),
            height: min(size.height - 8, placement.size.height * sy))
          context.fill(Path(rect), with: .color(theme.paper))
          context.stroke(Path(rect), with: .color(theme.ink), lineWidth: 1)
          context.fill(
            Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 5)),
            with: .color(theme.accent))
        }
      }
    }.frame(width: 280, height: 140).clipped().overlay(Rectangle().stroke(theme.ink))
      .accessibilityLabel(
        "Window map for " + preset.name
          + ". Theme and window positions; document contents are not captured.")
  }
}
