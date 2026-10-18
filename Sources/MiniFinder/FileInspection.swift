import Foundation
import ImageIO
import UniformTypeIdentifiers

struct FileInspection: Identifiable, Sendable {
  let id = UUID()
  let title: String
  let details: String
  var text: String?
  var image: Data?
}
extension DirectoryReader {
  func inspect(_ url: URL, preview: Bool) throws -> FileInspection {
    let values = try url.resourceValues(forKeys: [
      .contentTypeKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey, .isDirectoryKey,
      .isSymbolicLinkKey, .isRegularFileKey,
    ])
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    let size = ByteCountFormatter.string(
      fromByteCount: Int64(values.fileSize ?? 0), countStyle: .file)
    let permissions =
      (attributes[.posixPermissions] as? NSNumber).map { String(format: "%03o", $0.intValue) }
      ?? "Unavailable"
    let kind =
      values.isSymbolicLink == true
      ? "Symbolic link" : values.contentType?.localizedDescription ?? "Unknown"
    let details =
      "Kind: \(kind)\nSize: \(size)\(values.isDirectory == true ? " (folder entry; contents not counted)" : "")\nLocation: \(url.path)\nCreated: \(values.creationDate?.formatted() ?? "Unavailable")\nModified: \(values.contentModificationDate?.formatted() ?? "Unavailable")\nPOSIX permissions: \(permissions)"
    var result = FileInspection(title: url.lastPathComponent, details: details)
    guard preview else { return result }
    guard values.isRegularFile == true, values.isSymbolicLink != true else {
      result.text = "Preview is available for regular text and image files."
      return result
    }
    let type = values.contentType ?? .data
    if type.conforms(to: .image) {
      guard (values.fileSize ?? Int.max) <= 25_000_000 else {
        result.text = "Image preview is limited to files up to 25 MB."
        return result
      }
      guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateThumbnailAtIndex(
          source, 0,
          [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 800,
            kCGImageSourceShouldCacheImmediately: true,
          ] as CFDictionary)
      else { throw CocoaError(.fileReadCorruptFile) }
      let data = NSMutableData()
      guard
        let destination = CGImageDestinationCreateWithData(
          data, UTType.png.identifier as CFString, 1, nil)
      else { throw CocoaError(.fileReadCorruptFile) }
      CGImageDestinationAddImage(destination, image, nil)
      guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileReadCorruptFile) }
      result.image = data as Data
    } else if type.conforms(to: .text) || type.conforms(to: .json) || type.conforms(to: .sourceCode)
    {
      let handle = try FileHandle(forReadingFrom: url)
      defer { try? handle.close() }
      let bytes = try handle.read(upToCount: 65_537) ?? Data()
      let prefix = bytes.prefix(65_536)
      // A multibyte UTF-8 character may cross the preview boundary.
      result.text =
        String(decoding: prefix, as: UTF8.self)
        + (bytes.count > 65_536 ? "\n[Preview limited to 64 KB]" : "")
    } else {
      result.text = "No built-in preview for this file type. Use Open or Reveal in macOS Finder."
    }
    return result
  }
}
