import MiniUI
import SwiftUI

struct ScrapbookTransferView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.miniTheme) private var theme
  let model: ScrapbookModel
  let preview: ScrapbookImportPreview
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Unpack the Scrapbook").font(theme.typography.title)
      Text("\(preview.entries.count) new scraps · \(preview.skipped) identical scraps skipped")
      if preview.renamedIDs > 0 {
        Text("\(preview.renamedIDs) identifier conflicts will be kept as separate scraps.")
      }
      Text(
        "Existing scraps stay on the shelf. Archived scraps keep their archive state. Nothing is replaced."
      ).font(theme.typography.small)
      ForEach(preview.entries.prefix(20), id: \.scrap.id) { entry in
        HStack {
          Text(entry.scrap.title).lineLimit(2)
          Spacer()
          Text(entry.scrap.archived ? "Archived" : entry.scrap.kind.title).font(
            theme.typography.small)
        }
      }
      if preview.entries.count > 20 {
        Text("…and \(preview.entries.count-20) more.").font(theme.typography.small)
      }
      if let error = model.error {
        Text(error).font(theme.typography.small).foregroundStyle(theme.accent)
      }
      HStack {
        Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
        Spacer()
        Button("Import \(preview.entries.count) scraps") { model.confirmArchiveImport(preview) }
          .disabled(!model.canChange || preview.entries.isEmpty).keyboardShortcut(.defaultAction)
      }
    }.padding(16).font(theme.typography.body).foregroundStyle(theme.ink).buttonStyle(
      RetroButtonStyle())
  }
}
