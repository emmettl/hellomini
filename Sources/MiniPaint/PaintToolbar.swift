import MiniUI
import SwiftUI

struct PaintToolbar: View {
  @Bindable var model: PaintModel
  var body: some View {
    VStack(spacing: 4) {
      HStack(spacing: 8) {
        Picker("Drawing tool", selection: Binding(get: { model.tool }, set: model.chooseTool)) {
          ForEach(PaintModel.Tool.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }.miniControlBounds("paint.tool")
        Picker("Ink pattern", selection: $model.pattern) {
          ForEach(PaintPattern.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }.miniControlBounds("paint.pattern")
        Toggle("Filled", isOn: $model.filledShapes).disabled(
          model.tool != .rectangle && model.tool != .ellipse
        )
        .accessibilityLabel("Filled rectangles and ellipses")
      }.disabled(model.hasGesture)
      HStack(spacing: 6) {
        Button("Undo", action: model.undo).disabled(model.undoStack.isEmpty || model.hasGesture)
        Button("Redo", action: model.redo).disabled(model.redoStack.isEmpty || model.hasGesture)
        Button("PNG…", action: model.exportPNG).disabled(model.hasGesture).miniControlBounds(
          "paint.export")
        Button("Scrapbook", action: model.sendToScrapbook).disabled(model.hasGesture)
        Spacer(minLength: 0)
      }.buttonStyle(RetroButtonStyle())
    }.fixedSize(horizontal: false, vertical: true)
  }
}
