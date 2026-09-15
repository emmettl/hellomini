import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ScrapKind: String, Codable, CaseIterable, Sendable {
  case note, command, link, image
  var title: String { rawValue.capitalized }
}

struct Scrap: Identifiable, Codable, Equatable, Sendable {
  var id = UUID()
  var kind: ScrapKind
  var title: String
  var text: String
  var created = Date()
  var modified = Date()
  var archived = false
  /// Text found in an image scrap's picture: nil until read, empty when there was none.
  var recognizedText: String?

  var link: URL? { Self.webURL(text) }
  var awaitingRecognition: Bool { kind == .image && recognizedText == nil }
  static func webURL(_ text: String) -> URL? {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.contains(where: \.isWhitespace), let url = URL(string: value),
      ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
      let host = url.host, !host.isEmpty
    else { return nil }
    return url
  }

  func matches(_ query: String) -> Bool {
    let haystack = "\(title) \(text) \(kind.title) \(recognizedText ?? "")"
    return query.split(whereSeparator: \.isWhitespace).allSatisfy {
      haystack.range(of: String($0), options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
  }
}

struct ScrapbookDocument: Codable, Sendable {
  var version = 1
  var scraps: [Scrap]
}

struct ScrapImport: Sendable {
  var scrap: Scrap
  var image: Data?
}

enum ScrapbookError: LocalizedError {
  case invalidLibrary, unsupportedVersion, tooLarge, unsupportedFile, invalidLink, invalidTitle
  case invalidImage

  var errorDescription: String? {
    switch self {
    case .invalidLibrary: "The scrapbook could not be read. Its files have been left intact."
    case .unsupportedVersion: "This scrapbook was written by a newer version of Hello Mini."
    case .tooLarge:
      "Use text under 1 MB or an image under 25 MB. The library index is limited to 64 MB."
    case .unsupportedFile:
      "Choose a regular UTF-8 text file or a PNG, JPEG, TIFF, HEIC, or GIF image."
    case .invalidLink: "Enter one complete http:// or https:// web address."
    case .invalidTitle: "Give this scrap a title of up to 200 characters."
    case .invalidImage: "This image could not be read. Try exporting it as PNG or JPEG."
    }
  }
}

/// File work and image conversion stay off the UI actor. The model serializes all mutations.
actor ScrapbookStore {
  let directory: URL
  static let textLimit = 1_000_000
  static let imageLimit = 25_000_000
  static let indexLimit = 64_000_000
  static let recognitionLimit = 100_000

  init(directory: URL) { self.directory = directory }

  func load() throws -> [Scrap] {
    let url = directory.appendingPathComponent("scrapbook.json")
    // Only absence is an empty library. Permission, decoding, and future-version errors are surfaced.
    let data: Data
    do {
      let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard size <= Self.indexLimit else { throw ScrapbookError.tooLarge }
      data = try Data(contentsOf: url)
    } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
      return []
    }
    let document: ScrapbookDocument
    do { document = try JSONDecoder().decode(ScrapbookDocument.self, from: data) } catch {
      throw ScrapbookError.invalidLibrary
    }
    guard document.version == 1 else { throw ScrapbookError.unsupportedVersion }
    guard Set(document.scraps.map(\.id)).count == document.scraps.count else {
      throw ScrapbookError.invalidLibrary
    }
    return document.scraps
  }

  func save(_ scraps: [Scrap], image: ScrapImport? = nil) throws {
    for scrap in scraps {
      guard !scrap.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        scrap.title.count <= 200
      else { throw ScrapbookError.invalidTitle }
      guard scrap.text.utf8.count <= Self.textLimit else { throw ScrapbookError.tooLarge }
      if scrap.kind == .link && scrap.link == nil { throw ScrapbookError.invalidLink }
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(ScrapbookDocument(scraps: scraps))
    guard data.count <= Self.indexLimit else { throw ScrapbookError.tooLarge }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    if let image, let bytes = image.image {
      try bytes.write(to: imageURL(image.scrap.id), options: .atomic)
    }
    let index = directory.appendingPathComponent("scrapbook.json")
    if FileManager.default.fileExists(atPath: index.path) {
      // A previous complete index remains available for manual recovery.
      try Data(contentsOf: index).write(
        to: directory.appendingPathComponent("scrapbook.previous.json"), options: .atomic)
    }
    try data.write(to: index, options: .atomic)
  }

  func importFile(_ url: URL) throws -> ScrapImport {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    let info = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
    guard info.isRegularFile == true else { throw ScrapbookError.unsupportedFile }
    guard (info.fileSize ?? 0) <= Self.imageLimit else { throw ScrapbookError.tooLarge }
    let bytes = try Data(contentsOf: url)
    let title = String(url.deletingPathExtension().lastPathComponent.prefix(200))
    if let source = CGImageSourceCreateWithData(bytes as CFData, nil),
      CGImageSourceGetType(source) != nil
    {
      return try importImage(bytes, title: title)
    }
    guard bytes.count <= Self.textLimit else { throw ScrapbookError.tooLarge }
    guard let text = String(data: bytes, encoding: .utf8), !text.contains("\0") else {
      throw ScrapbookError.unsupportedFile
    }
    return ScrapImport(
      scrap: Scrap(kind: Scrap.webURL(text) == nil ? .note : .link, title: title, text: text))
  }

  func importImage(_ data: Data, title: String = "Pasted image") throws -> ScrapImport {
    guard data.count <= Self.imageLimit else { throw ScrapbookError.tooLarge }
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: 4096,
        ] as CFDictionary)
    else { throw ScrapbookError.invalidImage }
    let output = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        output, UTType.png.identifier as CFString, 1, nil)
    else { throw ScrapbookError.invalidImage }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw ScrapbookError.invalidImage }
    return ScrapImport(scrap: Scrap(kind: .image, title: title, text: ""), image: output as Data)
  }

  func imageData(_ id: UUID) throws -> Data { try Data(contentsOf: imageURL(id)) }
  private func imageURL(_ id: UUID) -> URL {
    directory.appendingPathComponent(id.uuidString + ".png")
  }
}
