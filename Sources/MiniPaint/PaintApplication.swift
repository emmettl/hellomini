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
  public init(sendToScrapbook: @escaping @MainActor (CGImage) async throws -> Void = { _ in }) {
    model = PaintModel(send: sendToScrapbook)
  }
  public func content() -> AnyView { AnyView(PaintView(model: model)) }
  public var menus: [RetroMenu] {
    [
      RetroMenu(
        id: "paint", title: "Paint",
        items: [
          RetroMenuItem(id: "new", title: "New Drawing…", enabled: model.ready) {
            self.model.showNew = true
          },
          RetroMenuItem(
            id: "undo", title: "Undo", shortcut: RetroShortcut(key: "z", label: "⌘Z"),
            enabled: !model.undoStack.isEmpty, action: model.undo),
          RetroMenuItem(
            id: "redo", title: "Redo",
            shortcut: RetroShortcut(key: "z", modifiers: [.command, .shift], label: "⇧⌘Z"),
            enabled: !model.redoStack.isEmpty, action: model.redo),
          RetroMenuItem(
            id: "clear", title: "Clear Selection", enabled: model.selection != nil,
            action: model.clearSelection),
          RetroMenuItem(
            id: "export", title: "Export PNG…", enabled: model.ready, action: model.exportPNG),
          RetroMenuItem(
            id: "scrapbook", title: "Send to Scrapbook", enabled: model.ready,
            action: model.sendToScrapbook),
        ])
    ]
  }
}
private struct PaintView: View {
  @Environment(\.miniTheme) private var theme
  @Bindable var model: PaintModel
  var body: some View {
    VStack(spacing: 6) {
      HStack(spacing: 4) {
        ForEach(PaintModel.Tool.allCases, id: \.self) { tool in
          Button(model.tool == tool ? "✓ " + tool.rawValue : tool.rawValue) {
            model.finish()
            model.tool = tool
          }
        }
        Picker("Pattern", selection: $model.pattern) {
          ForEach(PaintPattern.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }.labelsHidden().frame(maxWidth: 120)
      }.buttonStyle(RetroButtonStyle()).fixedSize(horizontal: false, vertical: true)
      HStack {
        Button("Undo", action: model.undo).disabled(model.undoStack.isEmpty)
        Button("Redo", action: model.redo).disabled(model.redoStack.isEmpty)
        Button("PNG…", action: model.exportPNG)
        Button("Scrapbook", action: model.sendToScrapbook)
        Spacer(minLength: 0)
      }.buttonStyle(RetroButtonStyle()).fixedSize(horizontal: false, vertical: true)
      GeometryReader { geometry in
        let scale = min(
          geometry.size.width / CGFloat(PaintBitmap.width),
          geometry.size.height / CGFloat(PaintBitmap.height))
        let width = CGFloat(PaintBitmap.width) * scale
        let height = CGFloat(PaintBitmap.height) * scale
        ZStack(alignment: .topLeading) {
          if let image = model.bitmap.image() {
            Image(decorative: image, scale: 1).resizable().interpolation(.none).frame(
              width: width, height: height)
          }
          if let rect = model.selection {
            Rectangle().stroke(.black, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
              .background(Rectangle().stroke(.white, lineWidth: 3))
              .frame(width: CGFloat(rect.width) * scale, height: CGFloat(rect.height) * scale)
              .offset(x: CGFloat(rect.x) * scale, y: CGFloat(rect.y) * scale)
          }
        }
        .frame(width: width, height: height).contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0).onChanged { value in
            guard scale > 0 else { return }
            let x = min(PaintBitmap.width - 1, max(0, Int(value.location.x / scale)))
            let y = min(PaintBitmap.height - 1, max(0, Int(value.location.y / scale)))
            model.draw(at: .init(x: x, y: y))
          }.onEnded { _ in model.finish() }
        )
        .overlay(Rectangle().stroke(theme.ink, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
          "Monochrome drawing, 320 by 200 pixels. Use a pointing device to draw; Paint menu provides undo, selection clearing and export."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      Text(model.error ?? model.notice).font(theme.typography.small).lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }.padding(8).font(theme.typography.body).foregroundStyle(theme.ink).background(theme.paper)
      .disabled(!model.ready).onAppear { model.load() }.onDisappear { model.finish() }
      .confirmationDialog(
        "Start a new drawing? The current drawing can still be recovered with Undo during this session.",
        isPresented: $model.showNew
      ) {
        Button("New Drawing", action: model.newDrawing)
      }
  }
}
