import Foundation

/// Version-one drawings remain readable; unreadable or future files never become empty drawings.
struct PaintStore {
  let file: URL
  func load() throws -> PaintBitmap {
    do {
      let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
      guard size <= 200_000 else { throw PaintError.invalid }
      let drawing = try JSONDecoder().decode(PaintBitmap.self, from: Data(contentsOf: file))
      guard drawing.isValid else { throw PaintError.invalid }
      return drawing
    } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
      return PaintBitmap()
    }
  }
  func save(_ drawing: PaintBitmap) throws {
    guard drawing.isValid else { throw PaintError.invalid }
    // Recheck disk state before replacing it, including edits by another app version/session.
    _ = try load()
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.withoutEscapingSlashes]
    try encoder.encode(drawing).write(to: file, options: .atomic)
  }
}
