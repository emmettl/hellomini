import Foundation
import Observation
import Synchronization
import Testing

@testable import MiniPaint

@Test func shapesAreSymmetricBoundedAndDistinguishOutlineFromFilled() {
  for shape in [PaintBitmap.Shape.rectangle, .ellipse] {
    var outline = PaintBitmap()
    outline.shape(
      shape, from: .init(x: 20, y: 20), to: .init(x: 10, y: 10), filled: false, pattern: .black)
    #expect(outline[15, 15] == 255)
    #expect(outline[15, 10] == 0 && outline[15, 20] == 0)
    #expect(outline[10, 15] == 0 && outline[20, 15] == 0)
    for y in 10...20 {
      for x in 10...20 {
        #expect(outline[x, y] == outline[30 - x, y])
        #expect(outline[x, y] == outline[x, 30 - y])
      }
    }
    var filled = PaintBitmap()
    filled.shape(
      shape, from: .init(x: 10, y: 10), to: .init(x: 20, y: 20), filled: true, pattern: .checks)
    #expect(filled[14, 14] == 0 && filled[15, 14] == 255)
    #expect(filled[9, 15] == 255 && filled[21, 15] == 255)
    for a in [PaintPoint(x: 0, y: 0), PaintPoint(x: 319, y: 199)] {
      filled.shape(shape, from: a, to: a, filled: false, pattern: .black)
      #expect(filled[a.x, a.y] == 0 && filled.isValid)
    }
  }
  var line = PaintBitmap()
  line.shape(.line, from: .init(x: 3, y: 5), to: .init(x: 8, y: 5), filled: false, pattern: .black)
  #expect((3...8).allSatisfy { line[$0, 5] == 0 })
}
@Test func selectionTransformsUseOriginalPixelsAndKeepDuplicatesInsideCanvas() {
  var original = PaintBitmap()
  original[10, 10] = 0
  original[11, 11] = 0
  let rect = PaintSelection(from: .init(x: 10, y: 10), to: .init(x: 12, y: 11))
  var horizontal = original
  _ = horizontal.transform(rect, operation: .flipHorizontal)
  #expect(horizontal[12, 10] == 0 && horizontal[10, 10] == 255 && horizontal[11, 11] == 0)
  var vertical = original
  _ = vertical.transform(rect, operation: .flipVertical)
  #expect(vertical[10, 11] == 0 && vertical[10, 10] == 255)
  _ = vertical.transform(rect, operation: .invert)
  #expect(vertical[10, 11] == 255 && vertical[10, 10] == 0)
  let copy = original.transform(rect, operation: .duplicate)
  #expect(copy.x == 18 && copy.y == 18 && original[18, 18] == 0 && original[10, 10] == 0)
  let edge = PaintSelection(from: .init(x: 300, y: 190), to: .init(x: 319, y: 199))
  original[319, 199] = 0
  let edgeCopy = original.transform(edge, operation: .duplicate)
  #expect(edgeCopy.isValid && edgeCopy.x == 292 && edgeCopy.y == 182)
  #expect(original[311, 191] == 0)
}
@Test @MainActor func shapePreviewCancelCommitAndSelectionUndoAreSingleOperations() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("ShapeHistory-\(UUID())")
  defer { try? FileManager.default.removeItem(at: root) }
  let file = root.appendingPathComponent("drawing.json")
  let model = PaintModel(file: file)
  model.load()
  model.chooseTool(.rectangle)
  model.draw(at: .init(x: 10, y: 10))
  model.draw(at: .init(x: 30, y: 30))
  #expect(
    model.hasGesture && model.undoStack.isEmpty
      && !FileManager.default.fileExists(atPath: file.path))
  model.draw(at: .init(x: 20, y: 20))
  #expect(model.bitmap[30, 30] == 255 && model.bitmap[20, 20] == 0)
  model.cancelGesture()
  #expect(model.bitmap == PaintBitmap() && !model.hasGesture)
  model.draw(at: .init(x: 10, y: 10))
  model.draw(at: .init(x: 20, y: 20))
  model.finish()
  #expect(model.undoStack.count == 1)
  let shape = model.bitmap
  let selection = PaintSelection(from: .init(x: 10, y: 10), to: .init(x: 20, y: 20))
  model.selection = selection
  model.transformSelection(.duplicate)
  #expect(model.undoStack.count == 2 && model.selection != selection)
  let duplicated = model.bitmap
  model.undo()
  #expect(model.bitmap == shape && model.selection == selection)
  model.redo()
  #expect(model.bitmap == duplicated && model.selection?.x == 18)
  let reopened = PaintModel(file: file)
  reopened.load()
  #expect(reopened.bitmap == duplicated)
}
@Test func canvasCoordinatesRespectLogicalScaleAndClampAtEdges() {
  for factor in [0.5, 1.0, 1.5, 2.0] {
    let scale = PaintCanvasCoordinates.scale(in: CGSize(width: 320 * factor, height: 200 * factor))
    #expect(
      PaintCanvasCoordinates.point(CGPoint(x: 45 * factor, y: 12 * factor), scale: scale)
        == PaintPoint(x: 45, y: 12))
    #expect(
      PaintCanvasCoordinates.point(CGPoint(x: -100, y: 1e20), scale: scale)
        == PaintPoint(x: 0, y: 199))
  }
  #expect(PaintCanvasCoordinates.point(.zero, scale: 0) == nil)
  #expect(PaintCanvasCoordinates.point(CGPoint(x: CGFloat.infinity, y: 0), scale: 1) == nil)
}
@Test func marchingAntsStopForEveryLifecycleGate() {
  #expect(
    PaintAntsPolicy.animates(
      enabled: true, reduceMotion: false, visible: true, awake: true, active: true))
  #expect(
    !PaintAntsPolicy.animates(
      enabled: false, reduceMotion: false, visible: true, awake: true, active: true))
  #expect(
    !PaintAntsPolicy.animates(
      enabled: true, reduceMotion: true, visible: true, awake: true, active: true))
  #expect(
    !PaintAntsPolicy.animates(
      enabled: true, reduceMotion: false, visible: false, awake: true, active: true))
  #expect(
    !PaintAntsPolicy.animates(
      enabled: true, reduceMotion: false, visible: true, awake: false, active: true))
  #expect(
    !PaintAntsPolicy.animates(
      enabled: true, reduceMotion: false, visible: true, awake: true, active: false))
}

@Test @MainActor func selectionOnlyGestureNotifiesControlsWhenItFinishes() {
  let file = FileManager.default.temporaryDirectory.appendingPathComponent(
    "SelectionGesture-\(UUID()).json")
  let model = PaintModel(file: file)
  model.load()
  model.chooseTool(.select)
  model.draw(at: .init(x: 1, y: 1))
  model.draw(at: .init(x: 5, y: 5))
  let changed = Mutex(false)
  withObservationTracking {
    _ = model.hasGesture
  } onChange: {
    changed.withLock { $0 = true }
  }
  model.finish()
  #expect(changed.withLock { $0 })
  #expect(model.selection != nil && !model.hasGesture && model.undoStack.isEmpty)
}
