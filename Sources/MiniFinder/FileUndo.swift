import Darwin
import Foundation

/// One session-only receipt. No persisted path is ever treated as permission to remove a file.
struct FileUndoReceipt: Sendable {
  let kind: FileOperationDraft.Kind
  let item: URL
  let original: URL?
  let fingerprint: [String: FileUndoIdentity]
  let parent: FileUndoIdentity
  let originalParent: FileUndoIdentity?

  var title: String {
    switch kind {
    case .newFolder: "Undo New Folder"
    case .rename: "Undo Rename"
    case .move: "Undo Move"
    case .copy: "Undo"
    }
  }
}

/// Redo is available only immediately after a successful Undo in this session.
enum FileRedoReceipt: Sendable {
  case folder(URL, FileUndoIdentity)
  case transfer(FileUndoReceipt)
  var title: String {
    switch self {
    case .folder: "Redo New Folder"
    case .transfer(let receipt): receipt.title.replacingOccurrences(of: "Undo", with: "Redo")
    }
  }
}

struct FileUndoIdentity: Equatable, Sendable {
  let device: dev_t
  let inode: ino_t
  let mode: mode_t
  let size: off_t
  let modifiedSeconds: Int
  let modifiedNanos: Int
  let changedSeconds: Int
  let changedNanos: Int

  init(_ url: URL) throws {
    var info = stat()
    guard lstat(url.path, &info) == 0 else { throw POSIXError(.ENOENT) }
    device = info.st_dev
    inode = info.st_ino
    mode = info.st_mode
    size = info.st_size
    modifiedSeconds = info.st_mtimespec.tv_sec
    modifiedNanos = info.st_mtimespec.tv_nsec
    changedSeconds = info.st_ctimespec.tv_sec
    changedNanos = info.st_ctimespec.tv_nsec
  }

  func sameDirectory(as other: Self) -> Bool {
    device == other.device && inode == other.inode && mode == other.mode
      && (mode & S_IFMT) == S_IFDIR
  }
}

extension DirectoryReader {
  func performWithUndo(
    _ draft: FileOperationDraft, progress: @Sendable (Int64) -> Void = { _ in }
  ) throws -> (URL, FileUndoReceipt?) {
    // Resolve parents once; a later symlink retarget must not redirect Undo.
    let parent = draft.folder.resolvingSymlinksInPath().standardizedFileURL
    let original = draft.source.map {
      $0.deletingLastPathComponent().resolvingSymlinksInPath()
        .appendingPathComponent($0.lastPathComponent)
    }
    let result = try perform(draft, progress: progress)
    guard draft.kind != .copy else { return (result, nil) }
    let item = parent.appendingPathComponent(draft.name)
    // Failure to capture a receipt does not turn a successful mutation into a reported failure.
    let receipt = try? FileUndoReceipt(
      kind: draft.kind, item: item, original: original,
      fingerprint: Self.undoFingerprint(item), parent: FileUndoIdentity(parent),
      originalParent: original.map { try FileUndoIdentity($0.deletingLastPathComponent()) })
    return (result, receipt)
  }

  func undo(_ receipt: FileUndoReceipt) throws {
    guard receipt.kind != .copy,
      try receipt.parent.sameDirectory(
        as: FileUndoIdentity(receipt.item.deletingLastPathComponent())),
      try Self.undoFingerprint(receipt.item) == receipt.fingerprint
    else { throw Self.undoRefused() }
    if receipt.kind == .newFolder {
      // rmdir is atomic and refuses a non-empty folder, including files added after inspection.
      guard rmdir(receipt.item.path) == 0 else { throw Self.undoRefused() }
    } else {
      guard let original = receipt.original, let parent = receipt.originalParent,
        try parent.sameDirectory(as: FileUndoIdentity(original.deletingLastPathComponent()))
      else { throw Self.undoRefused() }
      // An occupied original path, even a dangling symlink, is never replaced.
      guard
        renameatx_np(AT_FDCWD, receipt.item.path, AT_FDCWD, original.path, UInt32(RENAME_EXCL)) == 0
      else { throw Self.undoRefused() }
    }
  }

  func undoWithRedo(_ receipt: FileUndoReceipt) throws -> FileRedoReceipt? {
    try undo(receipt)
    // A successful Undo stays successful if recording Redo is unavailable.
    if receipt.kind == .newFolder {
      return try? .folder(receipt.item, FileUndoIdentity(receipt.item.deletingLastPathComponent()))
    }
    guard let original = receipt.original else { return nil }
    return try? .transfer(
      FileUndoReceipt(
        kind: receipt.kind, item: original, original: receipt.item,
        fingerprint: Self.undoFingerprint(original),
        parent: FileUndoIdentity(original.deletingLastPathComponent()),
        originalParent: FileUndoIdentity(receipt.item.deletingLastPathComponent())))
  }

  func redo(_ receipt: FileRedoReceipt) throws -> FileUndoReceipt? {
    switch receipt {
    case .folder(let item, let parent):
      guard try parent.sameDirectory(as: FileUndoIdentity(item.deletingLastPathComponent()))
      else { throw Self.undoRefused() }
      return try performWithUndo(
        FileOperationDraft(
          kind: .newFolder, source: nil, folder: item.deletingLastPathComponent(),
          name: item.lastPathComponent)
      ).1
    case .transfer(let inverse):
      try undo(inverse)
      guard let item = inverse.original else { return nil }
      return try? FileUndoReceipt(
        kind: inverse.kind, item: item, original: inverse.item,
        fingerprint: Self.undoFingerprint(item),
        parent: FileUndoIdentity(item.deletingLastPathComponent()),
        originalParent: FileUndoIdentity(inverse.item.deletingLastPathComponent()))
    }
  }

  private static func undoRefused() -> NSError {
    NSError(
      domain: "HelloMini.FinderUndo", code: 1,
      userInfo: [
        NSLocalizedDescriptionKey:
          "Undo or Redo stopped because the item or a folder changed, the original name is occupied, or access is unavailable. Nothing was replaced. Use macOS Finder to review it."
      ])
  }

  private static func undoFingerprint(_ root: URL) throws -> [String: FileUndoIdentity] {
    var result: [String: FileUndoIdentity] = [:]
    func visit(_ url: URL, path: String, depth: Int = 0) throws {
      guard result.count < 10_000, depth < 64 else { throw undoRefused() }
      let identity = try FileUndoIdentity(url)
      result[path] = identity
      if (identity.mode & S_IFMT) == S_IFDIR {
        for child in try FileManager.default.contentsOfDirectory(
          at: url, includingPropertiesForKeys: nil)
        {
          try visit(child, path: path + "/" + child.lastPathComponent, depth: depth + 1)
        }
      }
    }
    try visit(root, path: "")
    return result
  }
}
