import AppKit
import MiniUI
import SwiftUI

struct ScrapEditor: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  let model: ScrapbookModel
  @State var scrap: Scrap
  @FocusState private var titleFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("A little something worth keeping.").font(theme.typography.display(21))
      TextField("Title", text: $scrap.title).focused($titleFocused).accessibilityLabel(
        "Scrap title"
      )
      .textFieldStyle(.plain).padding(8)
      .overlay(Rectangle().strokeBorder(theme.ink, lineWidth: 1))
      if scrap.kind != .image {
        HStack {
          ForEach([ScrapKind.note, .command, .link], id: \.self) { kind in
            Button((scrap.kind == kind ? "✓ " : "") + kind.title) { scrap.kind = kind }
              .accessibilityLabel(kind.title + " scrap")
              .accessibilityAddTraits(scrap.kind == kind ? .isSelected : [])
          }
        }.buttonStyle(RetroButtonStyle())
      }
      Text(scrap.kind == .image ? "Caption" : scrap.kind == .link ? "Web address" : "Contents")
        .font(theme.typography.small)
      TextEditor(text: $scrap.text)
        .font(theme.typography.body).scrollContentBackground(.hidden).padding(6)
        .background(theme.paper).overlay(Rectangle().strokeBorder(theme.ink, lineWidth: 1))
        .accessibilityLabel("Scrap contents")
      if let error = model.error { Text(error).font(theme.typography.small) }
      HStack {
        Text(
          scrap.kind == .command ? "Kept as text. Ready to copy when needed." : "Saved on this Mac."
        )
        .font(theme.typography.small)
        Spacer()
        Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
        Button("Save") { model.saveDraft(scrap) }.keyboardShortcut(.defaultAction)
      }.buttonStyle(RetroButtonStyle())
    }
    .padding(22).miniFormWidth(570).frame(height: 420)
    .foregroundStyle(theme.ink).background(theme.paper)
    .onAppear { titleFocused = true }
    .disabled(model.busy).interactiveDismissDisabled(model.busy)
  }
}
