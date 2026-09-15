import AppKit
import Testing

@testable import MiniScrapbook

private actor RecognitionCalls {
  private(set) var count = 0
  func record() { count += 1 }
}

private func library() throws -> URL {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(
    "ScrapbookRecognitionTests-\(UUID())")
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}

private func picture(text: String? = nil, width: Int = 360, height: Int = 90) throws -> CGImage {
  let context = try #require(
    CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
  context.setFillColor(NSColor.white.cgColor)
  context.fill(CGRect(x: 0, y: 0, width: width, height: height))
  if let text {
    let line = CTLineCreateWithAttributedString(
      NSAttributedString(
        string: text,
        attributes: [.font: NSFont.boldSystemFont(ofSize: 44), .foregroundColor: NSColor.black]))
    context.textPosition = CGPoint(x: 16, y: 24)
    CTLineDraw(line, context)
  }
  return try #require(context.makeImage())
}

@MainActor private func waitFor(_ condition: () -> Bool) async throws {
  let deadline = ContinuousClock.now.advanced(by: .seconds(5))
  while !condition() && ContinuousClock.now < deadline {
    try await Task.sleep(for: .milliseconds(10))
  }
  try #require(condition())
}

@Test @MainActor func pictureTextIsReadOnceSearchedAndSaved() async throws {
  let root = try library()
  defer { try? FileManager.default.removeItem(at: root) }
  let board = NSPasteboard.withUniqueName()
  defer { board.releaseGlobally() }
  let calls = RecognitionCalls()
  let model = ScrapbookModel(directory: root, pasteboard: board) { _ in
    await calls.record()
    return "  Invoice 42\nPaid in fish  "
  }
  await model.captureDesktop(try picture())
  try await waitFor { model.scraps.first?.recognizedText != nil && !model.busy }
  #expect(model.scraps.first?.recognizedText == "Invoice 42\nPaid in fish")
  model.query = "invoice FISH"
  #expect(model.visible.count == 1)
  model.query = "invoice lobster"
  #expect(model.visible.isEmpty)

  let restored = ScrapbookModel(directory: root, pasteboard: board) { _ in
    await calls.record()
    return "Read again"
  }
  await restored.load()
  try await Task.sleep(for: .milliseconds(100))
  #expect(restored.scraps.first?.recognizedText == "Invoice 42\nPaid in fish")
  #expect(await calls.count == 1)
}

@Test @MainActor func olderLibrariesAreBackfilledAndUnreadablePicturesAreNotRetried() async throws {
  let root = try library()
  defer { try? FileManager.default.removeItem(at: root) }
  let store = ScrapbookStore(directory: root)
  let png = try #require(
    NSBitmapImageRep(cgImage: try picture()).representation(using: .png, properties: [:]))
  var first = try await store.importImage(png, title: "Older picture")
  var second = try await store.importImage(png, title: "Broken picture")
  first.scrap.modified = .distantPast
  second.scrap.modified = .distantPast
  try await store.save([first.scrap], image: first)
  try await store.save([first.scrap, second.scrap], image: second)
  // Libraries written before recognition have no recognizedText key at all.
  let index = root.appendingPathComponent("scrapbook.json")
  let json = try #require(String(data: Data(contentsOf: index), encoding: .utf8))
  #expect(!json.contains("recognizedText"))

  let calls = RecognitionCalls()
  let brokenID = second.scrap.id
  let model = ScrapbookModel(directory: root) { data in
    await calls.record()
    let decoded = NSBitmapImageRep(data: data)
    guard decoded != nil else { throw ScrapbookError.invalidImage }
    if await calls.count == 2 { throw ScrapbookError.invalidImage }
    return "Backfilled"
  }
  await model.load()
  try await waitFor { model.scraps.allSatisfy { !$0.awaitingRecognition } && !model.busy }
  let texts = Dictionary(uniqueKeysWithValues: model.scraps.map { ($0.id, $0.recognizedText) })
  #expect(Set(texts.values) == ["Backfilled", ""])
  #expect(texts[brokenID] != nil)
  #expect(await calls.count == 2)
  let reloaded = try await ScrapbookStore(directory: root).load()
  #expect(reloaded.allSatisfy { $0.recognizedText != nil })
}

@Test(.timeLimit(.minutes(1))) func visionReadsPrintedTextOnThisMac() async throws {
  let png = try #require(
    NSBitmapImageRep(cgImage: try picture(text: "HELLO MINI", width: 420))
      .representation(using: .png, properties: [:]))
  let text = try await ScrapTextRecognizer.recognize(png, fast: true)
  #expect(text.uppercased().contains("HELLO"))
}
