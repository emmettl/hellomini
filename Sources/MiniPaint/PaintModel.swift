import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor @Observable final class PaintModel {
  enum Tool: String, CaseIterable {
    case pencil = "Pencil"
    case eraser = "Eraser"
    case fill = "Fill"
    case select = "Select"
    case line = "Line"
    case rectangle = "Rectangle"
    case ellipse = "Ellipse"
    var shape: PaintBitmap.Shape? {
      switch self {
      case .line: .line
      case .rectangle: .rectangle
      case .ellipse: .ellipse
      default: nil
      }
    }
  }
  private(set) var bitmap = PaintBitmap()
  var tool = Tool.pencil
  var pattern = PaintPattern.black
  var filledShapes = false
  var hasGesture: Bool { before != nil }
  var selection: PaintSelection?
  var focusRequest = 0
  var showNew = false
  var pendingImport: PaintBitmap?
  var applyPattern: @MainActor ([UInt8]) -> Void = { _ in }
  var notice = "320 × 200 pixels. An intimidating amount of potential."
  private(set) var ready = false
  private(set) var error: String?
  private(set) var undoStack: [PaintEdit] = []
  private(set) var redoStack: [PaintEdit] = []
  @ObservationIgnored private var start: PaintPoint?
  @ObservationIgnored private var previous: PaintPoint?
  private var before: PaintBitmap?
  @ObservationIgnored private var beforeSelection: PaintSelection?
  @ObservationIgnored private var moving: PaintSelection?
  @ObservationIgnored let file: URL
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
      bitmap = try PaintStore(file: file).load()
      ready = true
      error = nil
    } catch { self.error = PaintError.invalid.localizedDescription }
  }

  func draw(at point: PaintPoint) {
    guard ready, bitmap.contains(point.x, point.y) else { return }
    if start == nil {
      start = point
      previous = point
      before = bitmap
      beforeSelection = selection
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
    case .line, .rectangle, .ellipse:
      if let before, let start, let shape = tool.shape {
        bitmap = before
        bitmap.shape(shape, from: start, to: point, filled: filledShapes, pattern: pattern)
      }
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
      undoStack.append(PaintEdit(bitmap: before, selection: beforeSelection))
      if undoStack.count > 20 { undoStack.removeFirst() }
      redoStack = []
      save()
    }
    start = nil
    previous = nil
    before = nil
    moving = nil
    beforeSelection = nil
  }
  func undo() {
    guard before == nil, let previous = undoStack.popLast() else { return }
    redoStack.append(PaintEdit(bitmap: bitmap, selection: selection))
    bitmap = previous.bitmap
    selection = previous.selection
    save()
  }
  func redo() {
    guard before == nil, let next = redoStack.popLast() else { return }
    undoStack.append(PaintEdit(bitmap: bitmap, selection: selection))
    bitmap = next.bitmap
    selection = next.selection
    save()
  }
  func clearSelection() {
    guard ready, before == nil, let selection, selection.isValid else { return }
    before = bitmap
    beforeSelection = selection
    bitmap.clear(selection)
    finish()
    self.selection = nil
  }
  func newDrawing() {
    guard ready, before == nil else { return }
    before = bitmap
    beforeSelection = selection
    bitmap = PaintBitmap()
    selection = nil
    finish()
  }
  func cancelGesture() {
    if let before {
      bitmap = before
      selection = beforeSelection
    }
    start = nil
    previous = nil
    before = nil
    moving = nil
    beforeSelection = nil
  }
  func chooseTool(_ tool: Tool) {
    cancelGesture()
    self.tool = tool
  }
  func transformSelection(_ operation: PaintBitmap.SelectionOperation) {
    guard ready, before == nil, let selection, selection.isValid else { return }
    before = bitmap
    beforeSelection = selection
    self.selection = bitmap.transform(selection, operation: operation)
    finish()
  }
  private func save() {
    do {
      try PaintStore(file: file).save(bitmap)
      error = nil
      notice = "Saved locally. The ink is already dry."
    } catch {
      self.error = "Drawing is still in memory, but could not be saved. Export PNG to keep a copy."
    }
  }
  func prepareImport(_ image: CGImage) throws {
    load()
    guard ready else { throw PaintError.invalid }
    finish()
    pendingImport = try PaintBitmap.importing(image)
  }
  func confirmImport() {
    guard ready, let imported = pendingImport else { return }
    before = bitmap
    beforeSelection = selection
    bitmap = imported
    selection = nil
    pendingImport = nil
    finish()
  }
  func useAsDesktopPattern() {
    guard ready, before == nil, let selection, selection.isValid else { return }
    applyPattern(bitmap.desktopRows(selection: selection))
    notice = "Selection sampled to an 8 × 8 desktop pattern."
  }
  func exportPNG() {
    guard ready, !hasGesture else { return }
    defer { focusRequest += 1 }
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
    guard ready, !hasGesture, let image = bitmap.image() else { return }
    Task {
      do {
        try await send(image)
        notice = "Sent to Scrapbook. A minor work of art."
      } catch { self.error = error.localizedDescription }
    }
  }
}

struct PaintEdit {
  var bitmap: PaintBitmap
  var selection: PaintSelection?
}
