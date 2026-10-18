import MiniUI
import SwiftUI

enum ScrapSort: String, CaseIterable {
  case modified = "Recently changed"
  case created = "Newest first"
  case title = "Title"
  func precedes(_ a: Scrap, _ b: Scrap) -> Bool {
    if self == .title {
      let order = a.title.localizedStandardCompare(b.title)
      if order != .orderedSame { return order == .orderedAscending }
    }
    let lhs = self == .created ? a.created : a.modified
    let rhs = self == .created ? b.created : b.modified
    return lhs == rhs ? a.id.uuidString < b.id.uuidString : lhs > rhs
  }
}

struct ScrapbookOrganisation: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Bindable var model: ScrapbookModel
  @State private var name = ""
  @State private var renamed = ""
  @State private var destination: String?
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Organise Scrapbook").font(theme.typography.title)
      Picker("Collection", selection: $model.collection) {
        Text("All collections").tag(String?.none)
        ForEach(model.collections, id: \.self) { Text($0).tag(Optional($0)) }
      }
      Toggle("Favourites only", isOn: $model.favouritesOnly)
      Picker("Sort", selection: $model.sort) {
        ForEach(ScrapSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
      }
      HStack {
        TextField("New collection", text: $name).accessibilityLabel("New collection name")
        Button("Create") {
          model.createCollection(name)
          name = ""
        }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      if let collection = model.collection {
        HStack {
          TextField("Rename collection", text: $renamed).accessibilityLabel(
            "New name for current collection")
          Button("Rename") {
            model.renameCollection(collection, to: renamed)
            renamed = ""
          }
          .disabled(renamed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        Button("Remove collection, keep scraps") { model.removeCollection(collection) }
        Text("Removing a collection returns its scraps to All collections.").font(
          theme.typography.small)
      }
      if model.selecting {
        Divider()
        Text("\(model.operationIDs.count) selected scraps").font(theme.typography.title)
        Picker("File selected scraps in", selection: $destination) {
          Text("Unfiled").tag(String?.none)
          ForEach(model.collections, id: \.self) { Text($0).tag(Optional($0)) }
        }
        Group {
          Button("File selected scraps") { model.fileSelection(in: destination) }.miniControlBounds(
            "filing.file")
          Button("Make selected favourites") { model.favouriteSelection(true) }
          Button("Remove selected favourites") { model.favouriteSelection(false) }
          Button(
            model.showArchive ? "Restore selected scraps" : "Archive selected scraps",
            action: model.archiveOrRestore)
        }.disabled(model.operationIDs.isEmpty)
      } else if let selected = model.selected {
        Divider()
        Text(selected.title).font(theme.typography.title).lineLimit(2)
        Picker(
          "File selected scrap in",
          selection: Binding(
            get: { selected.collection },
            set: { model.organiseSelected(collection: $0, favourite: selected.isFavourite) })
        ) {
          Text("Unfiled").tag(String?.none)
          ForEach(model.collections, id: \.self) { Text($0).tag(Optional($0)) }
        }
        Button(selected.isFavourite ? "Remove Favourite" : "Make Favourite") {
          model.organiseSelected(collection: selected.collection, favourite: !selected.isFavourite)
        }
      }
      if let error = model.error { Text(error).font(theme.typography.small) }
      Button("Undo Filing", action: model.undoFiling).disabled(model.filingUndo == nil)
        .miniControlBounds("filing.undo")
      Button("Done") { dismiss() }.keyboardShortcut(.cancelAction).miniControlBounds("filing.done")
    }
    .padding(12).miniFormWidth(400).foregroundStyle(theme.ink).background(theme.paper)
    .buttonStyle(RetroButtonStyle()).disabled(!model.canChange)
    .onChange(of: model.collection) {
      model.batchSelection = []
      model.selection = model.visible.first?.id
    }
    .onChange(of: model.favouritesOnly) { model.selection = model.visible.first?.id }
  }
}
