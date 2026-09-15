import AppKit
import MiniCore
import MiniUI
import Observation
import SwiftUI

@MainActor public final class FindFileApplication: MiniApplication {
  public let id = "find-file"
  public let name = "Find File"
  public let icon = MiniApplicationIcon.folder
  public let defaultSize = CGSize(width: 660, height: 450)
  public let minimumSize = CGSize(width: 420, height: 230)
  private let model = FindFileModel()
  public init() {}
  public func content() -> AnyView { AnyView(FindFileView(model: model)) }
}

@MainActor @Observable private final class FindFileModel {
  var text = ""
  var scope = FileManager.default.homeDirectoryForCurrentUser
  var results: [URL] = []
  var message = "Search indexed file names in your home folder, or choose a folder."
  var searching = false
  @ObservationIgnored let query = NSMetadataQuery()
  func search() {
    stop()
    results = []
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else {
      message = "Enter part of a file name."
      return
    }
    query.searchScopes = [scope.path]
    query.predicate = NSPredicate(format: "%K CONTAINS[cd] %@", NSMetadataItemFSNameKey, value)
    query.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSNameKey, ascending: true)]
    searching = query.start()
    message = searching ? "Following a promising scent…" : "Spotlight could not start this search."
  }
  func update() {
    query.disableUpdates()
    defer { query.enableUpdates() }
    results = (0..<min(200, query.resultCount)).compactMap {
      guard let item = query.result(at: $0) as? NSMetadataItem,
        let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
      else { return nil }
      return URL(fileURLWithPath: path)
    }
    searching = query.isGathering
    message =
      "\(query.resultCount) indexed matches"
      + (query.resultCount > 200 ? " · showing the first 200" : "")
      + ". Unindexed or inaccessible files may be absent."
  }
  func stop() {
    query.stop()
    searching = false
  }
  func chooseFolder() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    stop()
    scope = url
    results = []
    message = "Search scope changed. Choose Find to search here."
  }
  func open(_ url: URL) {
    if !NSWorkspace.shared.open(url) {
      message = "macOS could not open this result. It may have moved or be inaccessible."
    }
  }
}

private struct FindFileView: View {
  @Environment(\.miniTheme) private var theme
  @Bindable var model: FindFileModel
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        dog.frame(width: 48, height: 36).accessibilityHidden(true)
        TextField("File name contains…", text: $model.text).onSubmit(model.search)
        Button("Find", action: model.search).disabled(
          model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        Button("Stop", action: model.stop).disabled(!model.searching)
      }.buttonStyle(RetroButtonStyle())
      HStack {
        Text(model.scope.path).font(theme.typography.small).lineLimit(1).truncationMode(.head)
          .miniHelp(
            model.scope.path)
        Spacer()
        Button("Choose folder…", action: model.chooseFolder).buttonStyle(RetroButtonStyle())
      }
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          ForEach(model.results, id: \.self) { url in
            HStack {
              VStack(alignment: .leading) {
                Text(url.lastPathComponent).font(theme.typography.title).lineLimit(1)
                Text(url.deletingLastPathComponent().path).font(theme.typography.small).lineLimit(1)
                  .truncationMode(.head)
              }
              Spacer()
              Button("Open") { model.open(url) }
              Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }.buttonStyle(RetroButtonStyle()).miniHelp(url.path)
            Rectangle().frame(height: 1)
          }
        }
      }
      Text(model.message).font(theme.typography.small).fixedSize(horizontal: false, vertical: true)
    }.padding(16)
      .onReceive(
        NotificationCenter.default.publisher(
          for: .NSMetadataQueryDidFinishGathering, object: model.query)
      ) { _ in model.update() }
      .onReceive(
        NotificationCenter.default.publisher(for: .NSMetadataQueryDidUpdate, object: model.query)
      ) { _ in model.update() }
      .onDisappear { model.stop() }
  }
  private var dog: some View {
    Canvas { context, _ in
      let pixels = [
        "        ####", "       #####", "      ## ###", "##  ########", " #########  ",
        "  ########  ", "  ##    ##  ", "  ##    ##  ",
      ]
      for (y, row) in pixels.enumerated() {
        for (x, character) in row.enumerated() where character == "#" {
          context.fill(
            Path(CGRect(x: x * 3, y: y * 3, width: 3, height: 3)), with: .color(theme.ink))
        }
      }
    }
  }
}
