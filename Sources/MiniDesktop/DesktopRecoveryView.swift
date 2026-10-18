import AppKit
import MiniUI
import SwiftUI

struct DesktopBackup: Identifiable {
  let id: String
  let bytes: Data
  let summary: String
  let session: DesktopSession?
  var label: String = "Preserved layout (date unavailable)"
}
extension DesktopSessionStore {
  func backups() -> [DesktopBackup] {
    defaults.dictionaryRepresentation().keys.filter {
      $0 == Self.key || $0.hasPrefix("desktop.session.recovery.")
    }.sorted().compactMap { key in
      guard let value = defaults.object(forKey: key) else { return nil }
      let bytes =
        (value as? Data)
        ?? (try? PropertyListSerialization.data(
          fromPropertyList: ["original": value], format: .xml, options: 0)) ?? Data()
      let session =
        bytes.count <= 500_000 ? try? JSONDecoder().decode(DesktopSession.self, from: bytes) : nil
      let usable = session.flatMap { item -> DesktopSession? in
        guard item.version == 1, item.openIDs.count <= 64, item.windows.count <= 64,
          item.windows.values.allSatisfy(\.isValid)
        else { return nil }
        return item
      }
      return DesktopBackup(
        id: key, bytes: bytes,
        summary: session.map {
          "Version \($0.version) · \($0.openIDs.count) windows · \(bytes.count) bytes"
        } ?? "Unreadable layout · \(bytes.count) bytes", session: usable,
        label: (defaults.dictionary(forKey: "desktop.recoveryDates")?[key] as? Date).map {
          "Saved " + $0.formatted(date: .abbreviated, time: .shortened)
        } ?? "Preserved layout (date unavailable)")
    }
  }
}
struct DesktopRecoveryView: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  let model: DesktopModel
  @State private var selection: String?
  @State private var confirmRestore = false
  @State private var error: String?
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Saved Desktop Backups").font(theme.typography.title)
      Text(
        "Inspect and export preserved layouts. Restoring keeps app documents and minimises other open windows."
      ).font(theme.typography.small)
      Picker("Saved data", selection: $selection) {
        Text("Choose a backup").tag(Optional<String>.none)
        ForEach(model.sessionBackups) { backup in
          Text(
            backup.id == DesktopSessionStore.key
              ? "Current saved layout" : backup.label + " · " + String(backup.id.suffix(8))
          ).tag(Optional(backup.id))
        }
      }
      if let backup = model.sessionBackups.first(where: { $0.id == selection }) {
        Text(backup.summary).font(theme.typography.small)
        Text(
          backup.session == nil
            ? "Export available. This layout cannot be restored by this version."
            : "Restoring first preserves the current saved layout. Open documents stay in memory."
        ).font(theme.typography.small)
        ScrollView {
          Text(String(decoding: backup.bytes.prefix(2048), as: UTF8.self)).font(
            .system(size: 11, design: .monospaced)
          ).textSelection(.enabled)
        }.frame(height: 90)
        Text(
          "Preview shows the first 2 KB. Export retains every original byte. Unsupported layouts can be exported but not restored."
        ).font(theme.typography.small)
        HStack {
          Button("Export Original…") { export(backup) }
          Button("Restore Layout…") { confirmRestore = true }.disabled(backup.session == nil)
        }
      } else if model.sessionBackups.isEmpty {
        Text("No saved layouts or backups yet.")
      }
      if let error { Text(error).font(theme.typography.small) }
      HStack {
        Spacer()
        Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
      }
    }.padding(12).miniFormWidth(420).foregroundStyle(theme.ink).background(theme.paper).buttonStyle(
      RetroButtonStyle()
    )
    .confirmationDialog(
      "Back up the current saved layout and restore this one?", isPresented: $confirmRestore
    ) {
      Button("Restore Layout") {
        if let backup = model.sessionBackups.first(where: { $0.id == selection }),
          let session = backup.session
        {
          model.restoreBackup(session)
          dismiss()
        }
      }
    }
  }
  private func export(_ backup: DesktopBackup) {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "HelloMini-Desktop-Backup.dat"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do { try backup.bytes.write(to: url, options: .atomic) } catch {
      self.error = error.localizedDescription
    }
  }
}
