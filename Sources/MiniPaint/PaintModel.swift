import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor @Observable final class PaintModel {
  enum Tool: String, CaseIterable {
    case pencil = "Pencil"
    case eraser = "Eraser"
    case fill = "Fill"
    case select = "Select"
  }
  private(set) var bitmap = PaintBitmap()
  var tool = Tool.pencil
  var pattern = PaintPattern.black
  var selection: PaintSelection?
  var showNew = false
  var notice = "320 × 200 pixels. An intimidating amount of potential."
  private(set) var ready = false
  private(set) var error: String?
  private(set) var undoStack: [PaintBitmap] = []
  private(set) var redoStack: [PaintBitmap] = []
  @ObservationIgnored private var start: PaintPoint?
  @ObservationIgnored private var previous: PaintPoint?
  @ObservationIgnored private var before: PaintBitmap?
  @ObservationIgnored private var moving: PaintSelection?
  @ObservationIgnored private let file: URL
  @ObservationIgnored private let send: @MainActor (CGImage) async throws -> Void
  init(file: URL? = nil, send: @escaping @MainActor (CGImage) async throws -> Void = { _ in }) {
    self.file =
      file
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("HelloMini/MiniPaint/drawing.json")
    self.send = send
  }
  func load() {
    guard !ready else { return }
    do {
      let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
      guard size <= 200_000 else { throw PaintError.invalid }
      let loaded = try JSONDecoder().decode(PaintBitmap.self, from: Data(contentsOf: file))
      guard loaded.isValid else { throw PaintError.invalid }
      bitmap = loaded
      ready = true
    } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
      ready = true
    } catch { self.error = PaintError.invalid.localizedDescription }
  }

  func draw(at point: PaintPoint) {
    guard ready, bitmap.contains(point.x, point.y) else { return }
    if start == nil {
      start = point
      previous = point
      before = bitmap
      moving = tool == .select && selection?.contains(point) == true ? selection : nil
      if tool != .select { selection = nil }
    }
    switch tool {
    case .pencil, .eraser:
      bitmap.line(from: previous ?? point, to: point, erase: tool == .eraser, pattern: pattern)
    case .fill:
      if previous == start {
        bitmap.fill(at: point, pattern: pattern)
        previous = nil
      }
      return
    case .select:
      if let rect = moving, let start, let before {
        let dx = min(PaintBitmap.width - rect.x - rect.width, max(-rect.x, point.x - start.x))
        let dy = min(PaintBitmap.height - rect.y - rect.height, max(-rect.y, point.y - start.y))
        bitmap = before
        bitmap.move(rect, dx: dx, dy: dy)
        var next = rect
        next.x += dx
        next.y += dy
        selection = next
      } else if let start {
        selection = PaintSelection(from: start, to: point)
      }
    }
    previous = point
  }
  func finish() {
    if let before, before != bitmap {
      undoStack.append(before)
      if undoStack.count > 20 { undoStack.removeFirst() }
      redoStack = []
      save()
    }
    start = nil
    previous = nil
    before = nil
    moving = nil
  }
  func undo() {
    guard before == nil, let previous = undoStack.popLast() else { return }
    redoStack.append(bitmap)
    bitmap = previous
    selection = nil
    save()
  }
  func redo() {
    guard before == nil, let next = redoStack.popLast() else { return }
    undoStack.append(bitmap)
    bitmap = next
    selection = nil
    save()
  }
  func clearSelection() {
    guard ready, let selection else { return }
    before = bitmap
    bitmap.clear(selection)
    finish()
    self.selection = nil
  }
  func newDrawing() {
    guard ready else { return }
    before = bitmap
    bitmap = PaintBitmap()
    selection = nil
    finish()
  }
  private func save() {
    do {
      try FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.withoutEscapingSlashes]
      try encoder.encode(bitmap).write(to: file, options: .atomic)
      error = nil
      notice = "Saved locally. The ink is already dry."
    } catch {
      self.error = "Drawing is still in memory, but could not be saved. Export PNG to keep a copy."
    }
  }
  func exportPNG() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.png]
    panel.nameFieldStringValue = "MiniPaint.png"
    guard ready, panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try bitmap.png().write(to: url, options: .atomic)
      notice = "Exported at 320 × 200, in magnificent monochrome."
    } catch { self.error = error.localizedDescription }
  }
  func sendToScrapbook() {
    guard ready, let image = bitmap.image() else { return }
    Task {
      do {
        try await send(image)
        notice = "Sent to Scrapbook. A minor work of art."
      } catch { self.error = error.localizedDescription }
    }
  }
}
