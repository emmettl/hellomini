import Darwin
import Foundation

public struct VolumeReport: Identifiable, Sendable {
  public var id: URL
  public var name: String
  public var format: String
  public var total: Int64
  public var available: Int64
  public var readOnly: Bool
  public var smart: String
}

public struct CacheItem: Identifiable, Sendable {
  public var id: URL
  public var root: URL
  public var bytes: Int64
  public var partial: Bool
  public var inode: UInt64
  public var device: Int32
}

public actor StorageReader {
  public init() {}
  public func volumes() throws -> [VolumeReport] {
    let keys: Set<URLResourceKey> = [
      .volumeNameKey, .volumeLocalizedFormatDescriptionKey,
      .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeIsReadOnlyKey,
    ]
    let urls =
      FileManager.default.mountedVolumeURLs(
        includingResourceValuesForKeys: Array(keys), options: [.skipHiddenVolumes]) ?? []
    return urls.compactMap { url in
      guard let value = try? url.resourceValues(forKeys: keys) else { return nil }
      return VolumeReport(
        id: url, name: value.volumeName ?? url.lastPathComponent,
        format: value.volumeLocalizedFormatDescription ?? "Unknown format",
        total: Int64(value.volumeTotalCapacity ?? 0),
        available: Int64(value.volumeAvailableCapacity ?? 0),
        readOnly: value.volumeIsReadOnly ?? false, smart: "Not inspected")
    }
  }
  public func inspect(_ volume: VolumeReport) throws -> VolumeReport {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
    process.arguments = ["info", "-plist", volume.id.path]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try process.run()
    let bytes = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw CocoaError(.fileReadUnknown) }
    let plist =
      try PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any]
    var report = volume
    report.smart = plist?["SMARTStatus"] as? String ?? "Not reported for this volume"
    return report
  }
  public func caches(in root: URL) throws -> [CacheItem] {
    let canonical = root.resolvingSymlinksInPath().standardizedFileURL
    guard canonical.path == root.standardizedFileURL.path else {
      throw CocoaError(.fileReadNoPermission)
    }
    let children = try FileManager.default.contentsOfDirectory(
      at: root, includingPropertiesForKeys: nil)
    return try children.compactMap { child in
      try Task.checkCancellation()
      var info = stat()
      guard lstat(child.path, &info) == 0, info.st_mode & S_IFMT != S_IFLNK else { return nil }
      let size = try allocatedSize(child)
      return CacheItem(
        id: child, root: canonical, bytes: size.0, partial: size.1,
        inode: UInt64(info.st_ino), device: info.st_dev)
    }.sorted { $0.bytes > $1.bytes }
  }
  public func validate(_ item: CacheItem) throws {
    var info = stat()
    guard item.id.deletingLastPathComponent().standardizedFileURL == item.root,
      item.root.resolvingSymlinksInPath().standardizedFileURL == item.root,
      lstat(item.id.path, &info) == 0, info.st_mode & S_IFMT != S_IFLNK,
      UInt64(info.st_ino) == item.inode, info.st_dev == item.device
    else { throw CocoaError(.fileWriteNoPermission) }
  }
  public func trash(_ item: CacheItem) throws {
    try validate(item)
    try FileManager.default.trashItem(at: item.id, resultingItemURL: nil)
  }
  private func allocatedSize(_ url: URL) throws -> (Int64, Bool) {
    let keys: Set<URLResourceKey> = [
      .isDirectoryKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey,
    ]
    let root = try url.resourceValues(forKeys: keys)
    if root.isDirectory != true {
      return (Int64(root.totalFileAllocatedSize ?? root.fileAllocatedSize ?? 0), false)
    }
    var partial = false
    guard
      let enumerator = FileManager.default.enumerator(
        at: url, includingPropertiesForKeys: Array(keys),
        errorHandler: { _, _ in
          partial = true
          return true
        })
    else { return (0, true) }
    var bytes: Int64 = 0
    var count = 0
    for case let file as URL in enumerator {
      try Task.checkCancellation()
      count += 1
      if count > 200_000 {
        partial = true
        break
      }
      guard let value = try? file.resourceValues(forKeys: keys) else {
        partial = true
        continue
      }
      if value.isSymbolicLink == true {
        enumerator.skipDescendants()
        continue
      }
      if value.isDirectory != true {
        bytes += Int64(value.totalFileAllocatedSize ?? value.fileAllocatedSize ?? 0)
      }
    }
    return (bytes, partial)
  }
}
