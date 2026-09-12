import Foundation

public struct FileEntry: Identifiable, Sendable, Equatable {
  public var id: URL { url }
  public let url: URL
  public let name: String
  public let isDirectory: Bool
  public let isPackage: Bool
  public let byteCount: Int64

  public var isBrowsable: Bool { isDirectory && !isPackage }
}

/// Filesystem work stays off the UI actor, including metadata reads on external volumes.
public actor DirectoryReader {
  public init() {}

  public func entries(at directory: URL, showHidden: Bool = false) throws -> [FileEntry] {
    let keys: Set<URLResourceKey> = [
      .isDirectoryKey, .isPackageKey, .fileSizeKey, .localizedNameKey,
    ]
    let urls = try FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: Array(keys),
      options: showHidden ? [] : [.skipsHiddenFiles]
    )
    return try urls.map { url in
      let values = try url.resourceValues(forKeys: keys)
      return FileEntry(
        url: url,
        name: values.localizedName ?? url.lastPathComponent,
        isDirectory: values.isDirectory ?? false,
        isPackage: values.isPackage ?? false,
        byteCount: Int64(values.fileSize ?? 0)
      )
    }.sorted { lhs, rhs in
      if lhs.isBrowsable != rhs.isBrowsable { return lhs.isBrowsable }
      return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
  }
}

public struct NavigationHistory: Sendable {
  public private(set) var current: URL
  private var previous: [URL] = []

  public init(start: URL) {
    current = start.standardizedFileURL
  }

  public var canGoBack: Bool { !previous.isEmpty }
  public var canGoUp: Bool { current.path != "/" }

  public mutating func visit(_ url: URL) {
    let destination = url.standardizedFileURL
    guard destination != current else { return }
    previous.append(current)
    current = destination
  }

  public mutating func goBack() {
    guard let destination = previous.popLast() else { return }
    current = destination
  }
}
