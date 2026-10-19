import MiniCore
import MiniUI
import SwiftUI

/// Gesture coordinates are local logical points; presentation scaling belongs to the host.
enum PaintCanvasCoordinates {
  static func scale(in size: CGSize) -> CGFloat {
    max(0, min(size.width / CGFloat(PaintBitmap.width), size.height / CGFloat(PaintBitmap.height)))
  }
  static func point(_ location: CGPoint, scale: CGFloat) -> PaintPoint? {
    guard scale.isFinite, scale > 0, location.x.isFinite, location.y.isFinite else { return nil }
    // Clamp before conversion so a drag far outside the canvas cannot overflow Int.
    return PaintPoint(
      x: Int(min(CGFloat(PaintBitmap.width - 1), max(0, location.x / scale))),
      y: Int(min(CGFloat(PaintBitmap.height - 1), max(0, location.y / scale))))
  }
}
struct PaintCanvas: View {
  @Environment(\.miniTheme) private var theme
  @Bindable var model: PaintModel
  let playfulness: PlayfulnessSettings?
  let focus: FocusState<Bool>.Binding
  @State private var cancelledStroke = false
  var body: some View {
    GeometryReader { geometry in
      let scale = PaintCanvasCoordinates.scale(in: geometry.size)
      let width = CGFloat(PaintBitmap.width) * scale
      let height = CGFloat(PaintBitmap.height) * scale
      ZStack(alignment: .topLeading) {
        if let image = model.bitmap.image() {
          Image(decorative: image, scale: 1).resizable().interpolation(.none).frame(
            width: width, height: height)
        }
        if let rect = model.selection {
          PaintSelectionBorder(enabled: playfulness?.allows(PaintApplication.antsEffect.id) == true)
            .frame(width: CGFloat(rect.width) * scale, height: CGFloat(rect.height) * scale)
            .offset(x: CGFloat(rect.x) * scale, y: CGFloat(rect.y) * scale)
            .allowsHitTesting(false).accessibilityHidden(true)
        }
      }
      .frame(width: width, height: height).contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0).onChanged { value in
          focus.wrappedValue = true
          guard !cancelledStroke,
            let point = PaintCanvasCoordinates.point(value.location, scale: scale)
          else { return }
          model.draw(at: point)
        }.onEnded { _ in
          if cancelledStroke { model.cancelGesture() } else { model.finish() }
          cancelledStroke = false
        }
      )
      .overlay(Rectangle().stroke(theme.ink, lineWidth: 1))
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Monochrome drawing, 320 by 200 pixels")
      .accessibilityValue(
        model.tool.rawValue + (model.filledShapes ? ", filled shapes" : ", outline shapes")
          + (model.selection == nil ? ", no selection" : ", selection available")
      )
      .accessibilityHint(
        "Use a pointing device to draw. Command-1 through Command-7 choose tools. Escape cancels the current stroke. Paint menu offers selection transforms, Undo and export."
      )
      .focusable().focused(focus)
      .onKeyPress(.escape) {
        guard model.hasGesture else { return .ignored }
        cancelledStroke = true
        model.cancelGesture()
        return .handled
      }
      .miniControlBounds("paint.canvas")
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}
