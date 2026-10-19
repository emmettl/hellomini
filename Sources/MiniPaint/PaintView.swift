import MiniCore
import MiniUI
import SwiftUI

struct PaintView: View {
  @Environment(\.miniTheme) private var theme
  @Bindable var model: PaintModel
  var playfulness: PlayfulnessSettings? = nil
  @Environment(\.miniWindowActive) private var active
  @FocusState private var canvasFocused: Bool
  var body: some View {
    VStack(spacing: 6) {
      PaintToolbar(model: model).disabled(!model.ready)
      PaintCanvas(model: model, playfulness: playfulness, focus: $canvasFocused).disabled(
        !model.ready)
      if !model.ready { Button("Retry saved drawing", action: model.load) }
      Text(model.error ?? model.notice).font(theme.typography.small).lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }.padding(8).font(theme.typography.body).foregroundStyle(theme.ink).background(theme.paper)
      .onAppear { model.load() }.onDisappear { model.cancelGesture() }
      .onChange(of: model.focusRequest) { canvasFocused = false }
      .onChange(of: model.showNew) { _, showing in if !showing { model.focusRequest += 1 } }
      .background(
        MiniSheetFocusRestoration(request: model.focusRequest, active: active) {
          canvasFocused = true
        }.frame(width: 0, height: 0)
      )
      .sheet(
        isPresented: Binding(
          get: { model.pendingImport != nil }, set: { if !$0 { model.pendingImport = nil } }),
        onDismiss: { model.focusRequest += 1 }
      ) {
        VStack(spacing: 8) {
          Text("Open picture in MiniPaint?").font(.headline)
          Text(
            "Fit to 320 × 200 with white margins and a black-and-white threshold. Your current drawing can be recovered with Undo."
          ).font(theme.typography.small)
          if let image = model.pendingImport?.image() {
            Image(decorative: image, scale: 1).resizable().interpolation(.none).scaledToFit()
              .frame(height: 90)
          }
          HStack {
            Button("Cancel") { model.pendingImport = nil }.keyboardShortcut(.cancelAction)
            Button("Open", action: model.confirmImport).keyboardShortcut(.defaultAction)
          }.buttonStyle(RetroButtonStyle())
        }.padding(12).miniFormWidth(370).foregroundStyle(theme.ink).background(theme.paper)
          .miniSheet(width: 370)
      }
      .confirmationDialog(
        "Start a new drawing? The current drawing can still be recovered with Undo during this session.",
        isPresented: $model.showNew
      ) {
        Button("New Drawing", action: model.newDrawing)
      }
  }
}
