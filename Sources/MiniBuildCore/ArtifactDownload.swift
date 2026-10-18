import Darwin
import Foundation

/// A download owns one session; its mutable state is guarded by a lock. Files stay compressed.
public final class ArtifactDownload: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
  public static let maximumBytes: Int64 = 512 * 1024 * 1024
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Void, Error>?
  private var session: URLSession?
  private var task: URLSessionDownloadTask?
  private var cancelled = false
  private var committed = false
  private var started = false
  private var destination: URL?
  private var progress: (@Sendable (Int64, Int64?) -> Void)?
  public override init() { super.init() }
  public func download(
    _ request: URLRequest, to destination: URL,
    progress: @escaping @Sendable (Int64, Int64?) -> Void
  ) async throws {
    guard request.url?.scheme == "https", destination.isFileURL else {
      throw BuildServiceError("A secure download and local destination are required.")
    }
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.downloadTask(with: request)
        let start = lock.withLock {
          guard self.continuation == nil, self.session == nil, !cancelled, !started else {
            return false
          }
          self.started = true
          self.continuation = continuation
          self.session = session
          self.task = task
          self.destination = destination
          self.progress = progress
          return true
        }
        if start {
          task.resume()
        } else {
          session.invalidateAndCancel()
          continuation.resume(throwing: CancellationError())
        }
      }
    } onCancel: {
      self.cancel()
    }
  }
  public func cancel() {
    lock.withLock {
      guard !committed else { return }
      cancelled = true
      task?.cancel()
    }
  }
  /// Cross-origin redirects never inherit authentication, cookies or arbitrary custom headers.
  public static func redirected(_ request: URLRequest, from original: URL?) -> URLRequest? {
    guard let url = request.url, url.scheme == "https", url.user == nil, url.password == nil else {
      return nil
    }
    if BuildHTTP.allowsRedirect(from: original, to: url) { return request }
    var clean = URLRequest(url: url)
    clean.httpMethod = "GET"
    clean.setValue("HelloMini", forHTTPHeaderField: "User-Agent")
    return clean
  }
  public func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    completionHandler(Self.redirected(request, from: response.url))
  }
  public func urlSession(
    _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
  ) {
    guard totalBytesWritten <= Self.maximumBytes, totalBytesExpectedToWrite <= Self.maximumBytes
    else {
      finish(.failure(BuildServiceError("Artifact exceeds the 512 MB download limit.")))
      return
    }
    let progress = lock.withLock { self.progress }
    progress?(totalBytesWritten, totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil)
  }
  public func urlSession(
    _ session: URLSession, downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    do {
      guard let response = downloadTask.response as? HTTPURLResponse, response.statusCode == 200
      else {
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
        throw BuildServiceError(
          [404, 410].contains(status)
            ? "Artifact is missing, expired, or unavailable to this token."
            : "Artifact download failed (HTTP \(status)). Check access and try again.")
      }
      // The save panel may offer replacement; this first version deliberately never replaces files.
      try lock.withLock {
        guard !cancelled, continuation != nil, let destination else { throw CancellationError() }
        try Self.commitFile(location, to: destination)
        committed = true
      }
      finish(.success(()))
    } catch { finish(.failure(error)) }
  }
  public func urlSession(
    _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?
  ) {
    if let error { finish(lock.withLock { committed } ? .success(()) : .failure(error)) }
  }
  static func commitFile(_ location: URL, to destination: URL) throws {
    guard let size = try location.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0,
      Int64(size) <= maximumBytes
    else { throw BuildServiceError("Artifact is empty or exceeds the 512 MB limit.") }
    let handle = try FileHandle(forReadingFrom: location)
    defer { try? handle.close() }
    let prefix = try handle.read(upToCount: 4) ?? Data()
    guard prefix == Data([0x50, 0x4b, 0x03, 0x04]) || prefix == Data([0x50, 0x4b, 0x05, 0x06])
    else {
      throw BuildServiceError("The server did not return a ZIP archive.")
    }
    let value =
      "0083;" + String(Int(Date().timeIntervalSince1970), radix: 16) + ";HelloMini;"
      + UUID().uuidString
    guard
      value.withCString({ setxattr(location.path, "com.apple.quarantine", $0, strlen($0), 0, 0) })
        == 0
    else {
      throw BuildServiceError("Could not mark the download for normal macOS security checks.")
    }
    try FileManager.default.moveItem(at: location, to: destination)
  }
  private func finish(_ result: Result<Void, Error>) {
    let state = lock.withLock {
      let values = (continuation, session)
      continuation = nil
      session = nil
      task = nil
      progress = nil
      return values
    }
    state.1?.invalidateAndCancel()
    state.0?.resume(with: result)
  }
}
