import MiniUI
import SwiftUI

struct FileOperationView: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  let model: FinderModel
  @State var draft: FileOperationDraft
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(
        draft.kind == .newFolder
          ? "New Folder" : draft.kind == .rename ? "Rename" : draft.kind == .move ? "Move" : "Copy"
      )
      .font(theme.typography.title)
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          if let source = draft.source {
            Text("Source: " + source.path).font(theme.typography.small).textSelection(.enabled)
          }
          Text("Destination folder: " + draft.folder.path).font(theme.typography.small)
            .textSelection(
              .enabled)
          TextField("Name", text: $draft.name).accessibilityLabel("Destination name").disabled(
            model.fileBusy)
          Text(
            "Existing files are never replaced. Copy keeps the source and preserves symbolic links as links. Moves are atomic within one volume; use macOS Finder for cross-volume moves."
          ).font(theme.typography.small)
          if model.fileBusy {
            Text(
              "Copied \(ByteCountFormatter.string(fromByteCount: model.copiedBytes, countStyle: .file))"
            )
            .accessibilityLabel("Copy progress")
          }
          if let error = model.fileOperationError {
            Text(error).font(theme.typography.small).textSelection(.enabled)
          }
        }
      }.frame(maxHeight: 230)
      HStack {
        Button("Cancel") {
          if model.fileBusy { model.cancelFileOperation() } else { dismiss() }
        }.keyboardShortcut(.cancelAction).miniControlBounds(
          "files.cancel")
        Spacer()
        Button(model.fileBusy ? "Working…" : "Confirm") { model.performFileOperation(draft) }
          .disabled(model.fileBusy).keyboardShortcut(.defaultAction).miniControlBounds(
            "files.confirm")
      }
    }.padding(12).frame(width: 400).foregroundStyle(theme.ink).background(theme.paper).buttonStyle(
      RetroButtonStyle()
    )
    .interactiveDismissDisabled(model.fileBusy)
  }
}
