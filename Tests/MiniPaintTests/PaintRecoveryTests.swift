import Foundation
import Testing

@testable import MiniPaint

@Test @MainActor func legacyDrawingUpgradeRoundTripAndFutureFilesStayIntact() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(
    "PaintRecovery-\(UUID())")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let file = root.appendingPathComponent("drawing.json")
  var legacy = PaintBitmap()
  legacy[1, 1] = 0
  let bytes = try JSONEncoder().encode(legacy)
  try bytes.write(to: file)
  let model = PaintModel(file: file)
  model.load()
  #expect(model.bitmap == legacy && model.ready)
  model.selection = .init(from: .init(x: 1, y: 1), to: .init(x: 2, y: 2))
  model.transformSelection(.invert)
  #expect(try PaintStore(file: file).load() == model.bitmap)
  var future = legacy
  future.version = 99
  let futureBytes = try JSONEncoder().encode(future)
  try futureBytes.write(to: file)
  // Detect a future-format file even if another version replaced it after this model loaded.
  model.undo()
  #expect(model.error != nil && model.bitmap == legacy)
  #expect(try Data(contentsOf: file) == futureBytes)
  let reopened = PaintModel(file: file)
  reopened.load()
  #expect(!reopened.ready && reopened.error != nil)
  reopened.newDrawing()
  reopened.draw(at: .init(x: 0, y: 0))
  reopened.finish()
  #expect(try Data(contentsOf: file) == futureBytes)
  try bytes.write(to: file)
  reopened.load()
  #expect(reopened.ready && reopened.bitmap == legacy)
}
@Test @MainActor func failedShapeSaveRetainsPixelsAndCanExportWithoutDamagingOldDrawing() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(
    "PaintSaveFailure-\(UUID())")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let file = root.appendingPathComponent("drawing.json")
  let original = try JSONEncoder().encode(PaintBitmap())
  try original.write(to: file)
  let model = PaintModel(file: file)
  model.load()
  let corrupt = Data("unreadable newer contents".utf8)
  try corrupt.write(to: file)
  model.chooseTool(.ellipse)
  model.filledShapes = true
  model.draw(at: .init(x: 10, y: 10))
  model.draw(at: .init(x: 20, y: 20))
  model.finish()
  #expect(model.bitmap[15, 15] == 0 && model.error != nil)
  #expect(try Data(contentsOf: file) == corrupt)
  #expect(try model.bitmap.png().count > 0)
  model.undo()
  #expect(model.bitmap == PaintBitmap() && model.error != nil)
}
