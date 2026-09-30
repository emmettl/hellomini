import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ScrapbookArchive: Codable, Sendable {
  var version = 1
  var entries: [Entry]
  struct Entry: Codable, Sendable {
    var scrap: Scrap
    var image: Data?
  }
  static let limit = 100_000_000
  static let entryLimit = 2000
}
struct ScrapbookImportPreview: Identifiable, Sendable {
  let id = UUID()
  var entries: [ScrapbookArchive.Entry]
  var skipped: Int
  var renamedIDs: Int
}
enum ScrapbookArchiveError: LocalizedError {
  case invalid, tooLarge, changed
  var errorDescription: String? {
    switch self {
    case .invalid:
      "This backup is invalid or unsupported. The existing scrapbook has not been replaced."
    case .tooLarge:
      "A backup may contain at most 2,000 scraps and 100 MB, with images up to 25 MB and text up to 1 MB each."
    case .changed:
      "The library changed while the import was being reviewed. Open the backup again for a fresh preview."
    }
  }
}
extension ScrapbookStore {
  func writeArchive(_ scraps: [Scrap], to url: URL) throws {
    try archive(scraps).write(to: url, options: .atomic)
  }
  func previewArchive(at url: URL, existing: [Scrap]) throws -> ScrapbookImportPreview {
    let info = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
    guard info.isRegularFile == true, (info.fileSize ?? Int.max) <= ScrapbookArchive.limit else {
      throw ScrapbookArchiveError.tooLarge
    }
    return try previewArchive(Data(contentsOf: url), existing: existing)
  }
  func archive(_ scraps: [Scrap]) throws -> Data {
    guard scraps.count <= ScrapbookArchive.entryLimit else { throw ScrapbookArchiveError.tooLarge }
    var entries: [ScrapbookArchive.Entry] = []
    var bytes = 0
    for scrap in scraps {
      let image = scrap.kind == .image ? try imageData(scrap.id) : nil
      bytes += image?.count ?? 0
      guard bytes <= ScrapbookArchive.limit else { throw ScrapbookArchiveError.tooLarge }
      let entry = ScrapbookArchive.Entry(scrap: scrap, image: image)
      try Self.validate(entry)
      entries.append(entry)
    }
    let data = try JSONEncoder().encode(ScrapbookArchive(entries: entries))
    guard data.count <= ScrapbookArchive.limit else { throw ScrapbookArchiveError.tooLarge }
    return data
  }
  func previewArchive(_ data: Data, existing: [Scrap]) throws -> ScrapbookImportPreview {
    guard data.count <= ScrapbookArchive.limit else { throw ScrapbookArchiveError.tooLarge }
    let archive: ScrapbookArchive
    do { archive = try JSONDecoder().decode(ScrapbookArchive.self, from: data) } catch {
      throw ScrapbookArchiveError.invalid
    }
    guard archive.version == 1 else { throw ScrapbookArchiveError.invalid }
    guard archive.entries.count <= ScrapbookArchive.entryLimit else {
      throw ScrapbookArchiveError.tooLarge
    }
    var fingerprints = Set<String>()
    var ids = Set(existing.map(\.id))
    for scrap in existing {
      let bytes = scrap.kind == .image ? try imageData(scrap.id) : nil
      fingerprints.insert(try Self.fingerprint(.init(scrap: scrap, image: bytes)))
    }
    var result = ScrapbookImportPreview(entries: [], skipped: 0, renamedIDs: 0)
    for var entry in archive.entries {
      try Self.validate(entry)
      guard fingerprints.insert(try Self.fingerprint(entry)).inserted else {
        result.skipped += 1
        continue
      }
      if ids.contains(entry.scrap.id) {
        entry.scrap.id = UUID()
        result.renamedIDs += 1
      }
      ids.insert(entry.scrap.id)
      result.entries.append(entry)
    }
    return result
  }
  func importArchive(_ preview: ScrapbookImportPreview, existing: [Scrap]) throws -> [Scrap] {
    // The model serializes writes; recheck identifiers before touching any files.
    let ids = Set(existing.map(\.id))
    guard Set(preview.entries.map { $0.scrap.id }).count == preview.entries.count,
      preview.entries.allSatisfy({ !ids.contains($0.scrap.id) })
    else { throw ScrapbookArchiveError.changed }
    for entry in preview.entries { try Self.validate(entry) }
    let next = existing + preview.entries.map(\.scrap)
    var created: [URL] = []
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      for entry in preview.entries {
        if let image = entry.image {
          let destination = imageURL(entry.scrap.id)
          // Even orphaned image files are never overwritten by an import.
          guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw ScrapbookArchiveError.changed
          }
          try image.write(to: destination, options: .withoutOverwriting)
          created.append(destination)
        }
      }
      try save(next)
      return next
    } catch {
      for url in created { try? FileManager.default.removeItem(at: url) }
      throw error
    }
  }
  func exportScrap(_ scrap: Scrap, to url: URL) throws {
    let data = scrap.kind == .image ? try imageData(scrap.id) : Data(scrap.text.utf8)
    try data.write(to: url, options: .atomic)
  }
  private static func validate(_ entry: ScrapbookArchive.Entry) throws {
    let scrap = entry.scrap
    guard !scrap.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      scrap.title.count <= 200,
      scrap.text.utf8.count <= textLimit, (scrap.recognizedText?.count ?? 0) <= recognitionLimit,
      scrap.created.timeIntervalSince1970.isFinite, scrap.modified.timeIntervalSince1970.isFinite,
      scrap.kind != .link || scrap.link != nil
    else { throw ScrapbookArchiveError.invalid }
    if scrap.kind == .image {
      guard let image = entry.image, image.count <= imageLimit,
        let source = CGImageSourceCreateWithData(image as CFData, nil),
        CGImageSourceGetType(source) as String? == UTType.png.identifier,
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
        let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
        let height = properties[kCGImagePropertyPixelHeight as String] as? Int,
        (1...4096).contains(width), (1...4096).contains(height),
        CGImageSourceCreateImageAtIndex(source, 0, nil) != nil
      else { throw ScrapbookArchiveError.invalid }
    } else if entry.image != nil {
      throw ScrapbookArchiveError.invalid
    }
  }
  private static func fingerprint(_ entry: ScrapbookArchive.Entry) throws -> String {
    // Dates, IDs and derived OCR do not make identical content a new scrap.
    struct Content: Encodable {
      let kind: ScrapKind
      let title: String
      let text: String
      let archived: Bool
      let imageHash: String?
    }
    let imageHash = entry.image.map {
      SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined()
    }
    let content = Content(
      kind: entry.scrap.kind, title: entry.scrap.title, text: entry.scrap.text,
      archived: entry.scrap.archived, imageHash: imageHash)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return SHA256.hash(data: try encoder.encode(content)).map { String(format: "%02x", $0) }
      .joined()
  }
}
