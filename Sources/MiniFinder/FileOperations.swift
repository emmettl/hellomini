import Darwin
import Foundation

struct FileOperationDraft: Identifiable {
  enum Kind { case newFolder, rename, copy }
  let id = UUID()
  let kind: Kind
  let source: URL?
  let folder: URL
  var name: String
}
extension DirectoryReader {
  static func validatedName(_ name: String) throws -> String {
    guard !name.isEmpty, name != ".", name != "..", name.utf8.count <= 255,
      !name.contains(where: { $0 == "/" || $0 == ":" || $0.isNewline || $0.asciiValue == 0 })
    else {
      throw CocoaError(
        .fileWriteInvalidFileName,
        userInfo: [
          NSLocalizedDescriptionKey:
            "Use a name of up to 255 bytes without slashes, colons, newlines or NUL."
        ])
    }
    return name
  }
  func perform(_ draft: FileOperationDraft) throws -> URL {
    let name = try Self.validatedName(draft.name)
    let destination = draft.folder.appendingPathComponent(name)
    try Task.checkCancellation()
    switch draft.kind {
    case .newFolder:
      // createDirectory without intermediate directories fails rather than replacing a file.
      guard !FileManager.default.fileExists(atPath: destination.path) else {
        throw CocoaError(.fileWriteFileExists)
      }
      guard mkdir(destination.path, 0o755) == 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
      }
    case .rename:
      guard let source = draft.source,
        source.deletingLastPathComponent().standardizedFileURL == draft.folder.standardizedFileURL
      else { throw CocoaError(.fileWriteInvalidFileName) }
      try Self.moveExclusively(source, to: destination)
    case .copy:
      guard let source = draft.source else { throw CocoaError(.fileReadNoSuchFile) }
      let resolved = source.resolvingSymlinksInPath().standardizedFileURL.path
      let parent = draft.folder.resolvingSymlinksInPath().standardizedFileURL.path
      guard parent != resolved, !parent.hasPrefix(resolved + "/") else {
        throw CocoaError(
          .fileWriteInvalidFileName,
          userInfo: [NSLocalizedDescriptionKey: "Choose a destination outside the source folder."])
      }
      try Self.validateCopySize(source)
      var template = Array(
        draft.folder.appendingPathComponent(".HelloMini-copy-XXXXXX").path.utf8CString)
      guard mkdtemp(&template) != nil else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
      }
      let directory = URL(
        fileURLWithPath: String(
          decoding: template.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self))
      defer { try? FileManager.default.removeItem(at: directory) }
      let staging = directory.appendingPathComponent("item")
      try FileManager.default.copyItem(at: source, to: staging)
      try Task.checkCancellation()
      try Self.moveExclusively(staging, to: destination)
    }
    return destination
  }
  private static func moveExclusively(_ source: URL, to destination: URL) throws {
    guard renameatx_np(AT_FDCWD, source.path, AT_FDCWD, destination.path, UInt32(RENAME_EXCL)) == 0
    else {
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
  }
  private static func validateCopySize(_ source: URL) throws {
    let manager = FileManager.default
    var bytes: Int64 = 0
    var count = 0
    func add(_ url: URL) throws {
      try Task.checkCancellation()
      let attributes = try manager.attributesOfItem(atPath: url.path)
      bytes += (attributes[.size] as? NSNumber)?.int64Value ?? 0
      count += 1
      guard bytes <= 512 * 1024 * 1024, count <= 10_000 else {
        throw CocoaError(
          .fileWriteOutOfSpace,
          userInfo: [
            NSLocalizedDescriptionKey:
              "Hello Mini copies up to 512 MB and 10,000 entries at a time. Use macOS Finder for larger collections."
          ])
      }
    }
    try add(source)
    let attrs = try manager.attributesOfItem(atPath: source.path)
    if attrs[.type] as? FileAttributeType == .typeDirectory {
      var readError: Error?
      guard
        let enumerator = manager.enumerator(
          at: source, includingPropertiesForKeys: nil,
          errorHandler: { _, error in
            readError = error
            return false
          })
      else { throw CocoaError(.fileReadUnknown) }
      for case let url as URL in enumerator { try add(url) }
      if let readError { throw readError }
    }
  }
}
