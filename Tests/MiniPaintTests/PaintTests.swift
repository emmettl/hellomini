import Foundation
import ImageIO
import Testing

@testable import MiniPaint

@Test func pencilFillsLineWithoutGapsAndEraserStaysInBounds() {
  var bitmap = PaintBitmap()
  bitmap.line(from: .init(x: 0, y: 0), to: .init(x: 100, y: 100), erase: false, pattern: .black)
  for i in 0...100 { #expect(bitmap[i, i] == 0) }
  bitmap.line(from: .init(x: 0, y: 0), to: .init(x: 0, y: 0), erase: true, pattern: .black)
  #expect(bitmap[0, 0] == 255)
  #expect(bitmap[3, 3] == 0)
  #expect(bitmap.isValid)
}
@Test func patternedFillRespectsEnclosedRegion() {
  var bitmap = PaintBitmap()
  for x in 10...20 {
    bitmap[x, 10] = 0
    bitmap[x, 20] = 0
  }
  for y in 10...20 {
    bitmap[10, y] = 0
    bitmap[20, y] = 0
  }
  bitmap.fill(at: .init(x: 15, y: 15), pattern: .checks)
  #expect(bitmap[12, 12] == 0)
  #expect(bitmap[13, 12] == 255)
  #expect(bitmap[9, 12] == 255)
  #expect(bitmap[10, 12] == 0)
  #expect(bitmap.isValid)
}
@Test func overlappingSelectionMovesFromOriginalPixels() {
  var bitmap = PaintBitmap()
  bitmap[0, 0] = 0
  bitmap[1, 0] = 255
  bitmap[2, 0] = 0
  bitmap.move(.init(from: .init(x: 0, y: 0), to: .init(x: 2, y: 0)), dx: 1, dy: 0)
  #expect(bitmap[0, 0] == 255 && bitmap[1, 0] == 0 && bitmap[2, 0] == 255 && bitmap[3, 0] == 0)
}
@Test func exportIsAReal320By200PNG() throws {
  let data = try PaintBitmap().png()
  let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
  let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
  #expect(image.width == 320 && image.height == 200)
}
@MainActor @Test func strokeUndoRedoAndRelaunchKeepDrawing() throws {
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent("PaintTests-\(UUID())")
  defer { try? FileManager.default.removeItem(at: dir) }
  let file = dir.appendingPathComponent("drawing.json")
  let model = PaintModel(file: file)
  model.load()
  model.draw(at: .init(x: 12, y: 20))
  model.draw(at: .init(x: 45, y: 20))
  model.finish()
  let drawn = model.bitmap
  #expect(model.undoStack.count == 1)
  model.undo()
  #expect(model.bitmap[12, 20] == 255)
  model.redo()
  #expect(model.bitmap == drawn)
  #expect(model.error == nil)
  #expect(try JSONDecoder().decode(PaintBitmap.self, from: Data(contentsOf: file)) == drawn)
  let restored = PaintModel(file: file)
  restored.load()
  #expect(restored.error == nil)
  #expect(restored.bitmap == drawn)
  model.newDrawing()
  model.undo()
  #expect(model.bitmap == drawn)
}
@MainActor @Test func invalidDrawingIsPreservedAndFailedSaveKeepsPixels() throws {
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent("PaintTests-\(UUID())")
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: dir) }
  let file = dir.appendingPathComponent("drawing.json")
  let corrupt = Data("bad saved drawing".utf8)
  try corrupt.write(to: file)
  let model = PaintModel(file: file)
  model.load()
  #expect(!model.ready && model.error != nil)
  #expect(try Data(contentsOf: file) == corrupt)
  let blocked = dir.appendingPathComponent("not-a-folder")
  let unsaved = PaintModel(file: blocked.appendingPathComponent("drawing.json"))
  unsaved.load()
  try Data().write(to: blocked)
  unsaved.draw(at: .init(x: 1, y: 1))
  unsaved.finish()
  #expect(unsaved.bitmap[1, 1] == 0 && unsaved.error != nil)
}
