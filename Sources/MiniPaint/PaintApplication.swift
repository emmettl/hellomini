import MiniCore
import MiniUI
import SwiftUI

@MainActor public final class PaintApplication: MiniApplication {
  public let id = "mini-paint"
  public let name = "MiniPaint"
  public let icon = MiniApplicationIcon.paint
  public let defaultSize = CGSize(width: 720, height: 510)
  public let minimumSize = CGSize(width: 440, height: 250)
  private let model: PaintModel
  private let playfulness: PlayfulnessSettings?
  public init(
    playfulness: PlayfulnessSettings? = nil,
    applyPattern: @escaping @MainActor ([UInt8]) -> Void = { _ in },
    sendToScrapbook: @escaping @MainActor (CGImage) async throws -> Void = { _ in }
  ) {
    self.playfulness = playfulness
    model = PaintModel(send: sendToScrapbook)
    model.applyPattern = applyPattern
  }
  public func openDrawing(_ image: CGImage) throws { try model.prepareImport(image) }
  public func content() -> AnyView { AnyView(PaintView(model: model, playfulness: playfulness)) }
  public var menus: [RetroMenu] {
    [
      RetroMenu(
        id: "paint", title: "Paint", width: 330,
        items: [
          RetroMenuItem(id: "new", title: "New Drawing…", enabled: model.ready && !model.hasGesture)
          {
            self.model.showNew = true
          },
          RetroMenuItem(
            id: "undo", title: "Undo", shortcut: RetroShortcut(key: "z", label: "⌘Z"),
            enabled: !model.undoStack.isEmpty && !model.hasGesture, action: model.undo),
          RetroMenuItem(
            id: "redo", title: "Redo",
            shortcut: RetroShortcut(key: "z", modifiers: [.command, .shift], label: "⇧⌘Z"),
            enabled: !model.redoStack.isEmpty && !model.hasGesture, action: model.redo),
          RetroMenuItem(
            id: "clear", title: "Clear Selection",
            enabled: model.ready && model.selection != nil && !model.hasGesture,
            action: model.clearSelection),
          RetroMenuItem(
            id: "desktop-pattern", title: "Use Selection as Desktop Pattern",
            enabled: model.ready && model.selection != nil && !model.hasGesture,
            action: model.useAsDesktopPattern),
          RetroMenuItem(
            id: "export", title: "Export PNG…", enabled: model.ready && !model.hasGesture,
            action: model.exportPNG),
          RetroMenuItem(
            id: "scrapbook", title: "Send to Scrapbook", enabled: model.ready && !model.hasGesture,
            action: model.sendToScrapbook),
        ]),
      RetroMenu(
        id: "tools", title: "Tools", width: 300,
        items:
          PaintModel.Tool.allCases.enumerated().map { index, tool in
            RetroMenuItem(
              id: "tool-\(index)", title: tool.rawValue,
              shortcut: RetroShortcut(key: String(index + 1), label: "⌘\(index + 1)"),
              enabled: model.ready && !model.hasGesture, checked: model.tool == tool
            ) { self.model.chooseTool(tool) }
          } + [
            RetroMenuItem(
              id: "filled", title: "Filled Shapes", enabled: model.ready && !model.hasGesture,
              checked: model.filledShapes
            ) { self.model.filledShapes.toggle() }
          ]),
      RetroMenu(
        id: "selection", title: "Selection", width: 300,
        items:
          PaintBitmap.SelectionOperation.allCases.enumerated().map { index, operation in
            let keys = ["h", "v", "i", "d"]
            return RetroMenuItem(
              id: "transform-\(index)", title: operation.rawValue,
              shortcut: RetroShortcut(
                key: keys[index], modifiers: [.command, .shift],
                label: "⇧⌘" + keys[index].uppercased()),
              enabled: model.ready && model.selection != nil && !model.hasGesture
            ) { self.model.transformSelection(operation) }
          }),
    ]
  }
}
