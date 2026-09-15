import AppKit
import MiniCore
import SwiftUI

@MainActor public final class ScrapbookApplication: MiniApplication {
  public let id = "scrapbook"
  public let name = "Scrapbook"
  public let icon = MiniApplicationIcon.scrapbook
  public let defaultSize = CGSize(width: 760, height: 480)
  public let minimumSize = CGSize(width: 440, height: 240)
  private let model = ScrapbookModel()
  public init() {}
  public func captureDesktop(_ image: CGImage) async { await model.captureDesktop(image) }
  public func content() -> AnyView { AnyView(ScrapbookView(model: model)) }
  public static let screensaver = MiniScreensaver(
    id: "scrapbook-slideshow", name: "Scrapbook Slideshow",
    description: "Your scrapbook pictures, one at a time, like a very patient projector.")
  public func screensaverContent() -> AnyView { AnyView(ScrapbookSlideshow(model: model)) }

  public var menus: [RetroMenu] {
    [
      RetroMenu(
        id: "scrapbook", title: "Scrapbook", width: 300,
        items: [
          RetroMenuItem(
            id: "new-scrap", title: "New Scrap…",
            shortcut: RetroShortcut(key: "n", label: "⌘N"), enabled: model.canChange,
            action: model.newNote),
          RetroMenuItem(
            id: "paste-scrap", title: "Paste as New",
            shortcut: RetroShortcut(key: "v", modifiers: [.command, .shift], label: "⇧⌘V"),
            enabled: model.canChange, action: model.pasteAsNew),
          RetroMenuItem(
            id: "import-scrap", title: "Import Text or Image…", enabled: model.canChange,
            action: model.chooseFile),
          .separator("scrap-actions"),
          RetroMenuItem(
            id: "edit-scrap", title: "Edit Scrap…",
            enabled: model.canChange && model.selected != nil, action: model.edit),
          RetroMenuItem(
            id: "copy-scrap", title: "Copy Scrap",
            shortcut: RetroShortcut(key: "c", modifiers: [.command, .shift], label: "⇧⌘C"),
            enabled: model.canChange && model.selected != nil, action: model.copySelected),
          RetroMenuItem(
            id: "archive-scrap", title: model.showArchive ? "Restore Scrap" : "Archive Scrap",
            enabled: model.canChange && model.selected != nil, action: model.archiveOrRestore),
        ])
    ]
  }
}
