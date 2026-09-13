import MiniCore
import SwiftUI

@MainActor public final class FinderApplication: MiniApplication {
  public let id = "finder"
  public let name = "Finder"
  public let icon = MiniApplicationIcon.folder
  public let defaultSize = CGSize(width: 800, height: 472)
  public let minimumSize = CGSize(width: 440, height: 230)
  private let model: FinderModel
  private let findFile: @MainActor () -> Void
  public init(defaults: UserDefaults = .standard, findFile: @escaping @MainActor () -> Void = {}) {
    model = FinderModel(defaults: defaults)
    self.findFile = findFile
  }
  public var title: String { model.title }
  public func content() -> AnyView { AnyView(FinderView(model: model, findFile: findFile)) }

  public var menus: [RetroMenu] {
    [
      RetroMenu(
        id: "file", title: "File", width: 304,
        items: [
          RetroMenuItem(
            id: "find-file", title: "Find File…", shortcut: RetroShortcut(key: "f", label: "⌘F"),
            action: findFile),
          RetroMenuItem(
            id: "open", title: "Open Selected", shortcut: RetroShortcut(key: "o", label: "⌘O"),
            enabled: model.selectedEntry != nil
          ) {
            if let entry = self.model.selectedEntry { self.model.open(entry) }
          },
          RetroMenuItem(
            id: "open-folder", title: "Open Folder…",
            shortcut: RetroShortcut(key: "o", modifiers: [.command, .shift], label: "⇧⌘O"),
            action: model.chooseFolder),
          RetroMenuItem(
            id: "reveal", title: "Reveal in macOS Finder", action: model.revealSelection),
        ]),
      RetroMenu(
        id: "view", title: "View", width: 330,
        items: [
          RetroMenuItem(id: "icons", title: "As Icons", checked: !model.listView) {
            self.model.listView = false
          },
          RetroMenuItem(id: "list", title: "As List", checked: model.listView) {
            self.model.listView = true
          },
          .separator("view-mode-divider"),
          RetroMenuItem(
            id: "hidden", title: "Show Hidden Files",
            shortcut: RetroShortcut(key: ".", modifiers: [.command, .shift], label: "⇧⌘."),
            checked: model.showHidden
          ) { self.model.showHidden.toggle() },
          RetroMenuItem(
            id: "refresh", title: "Refresh", shortcut: RetroShortcut(key: "r", label: "⌘R"),
            action: model.reload),
        ]),
      RetroMenu(
        id: "go", title: "Go", width: 276,
        items: [
          RetroMenuItem(
            id: "back", title: "Back", shortcut: RetroShortcut(key: "[", label: "⌘["),
            enabled: model.history.canGoBack, action: model.goBack),
          RetroMenuItem(
            id: "up", title: "Enclosing Folder",
            shortcut: RetroShortcut(key: "\u{F700}", label: "⌘↑"), enabled: model.history.canGoUp,
            action: model.goUp),
          .separator("go-divider"),
          RetroMenuItem(
            id: "home", title: "Home",
            shortcut: RetroShortcut(key: "h", modifiers: [.command, .shift], label: "⇧⌘H")
          ) { self.model.navigate(to: FileManager.default.homeDirectoryForCurrentUser) },
        ]),
    ]
  }
}
