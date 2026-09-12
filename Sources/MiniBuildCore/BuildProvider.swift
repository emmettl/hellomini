import Foundation

public enum BuildState: String, Sendable {
  case queued, running, passed, failed, cancelled, waiting, skipped, unknown
}
public struct BuildRun: Identifiable, Sendable {
  public let id: Int
  public let title: String
  public let branch: String
  public let state: BuildState
  public let url: URL
  public let createdAt: Date?
  public let workflow: String?
  public init(
    id: Int, title: String, branch: String, state: BuildState, url: URL, createdAt: Date? = nil,
    workflow: String? = nil
  ) {
    self.id = id
    self.title = title
    self.branch = branch
    self.state = state
    self.url = url
    self.createdAt = createdAt
    self.workflow = workflow
  }
}
public protocol BuildProvider: Sendable {
  func runs(project: String, token: String?) async throws -> [BuildRun]
  func jobs(project: String, runID: Int, page: Int, token: String?) async throws -> BuildJobPage
}
public struct BuildServiceError: LocalizedError, Sendable {
  public let message: String
  public init(_ message: String) { self.message = message }
  public var errorDescription: String? { message }
}
public enum BuildHTTP {
  public static func date(_ value: String?) -> Date? {
    guard let value else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
  }
  public static func validateProject(_ project: String, github: Bool) throws -> String {
    let parts = project.split(separator: "/", omittingEmptySubsequences: false)
    let allowed = CharacterSet(
      charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
    guard project.count <= 250, github ? parts.count == 2 : parts.count >= 2,
      parts.allSatisfy({
        !$0.isEmpty && $0 != "." && $0 != ".." && $0.unicodeScalars.allSatisfy(allowed.contains)
      })
    else {
      throw BuildServiceError("Use an owner/project path, with no URL, query, or credentials.")
    }
    return project
  }
  public static func allowsRedirect(from original: URL?, to destination: URL?) -> Bool {
    guard let original, let destination,
      original.scheme == "https", destination.scheme == "https",
      let originalHost = original.host, !originalHost.isEmpty,
      originalHost.lowercased() == destination.host?.lowercased(),
      (original.port ?? 443) == (destination.port ?? 443),
      destination.user == nil, destination.password == nil
    else { return false }
    return true
  }
  public static func data(url: URL, headers: [String: String]) async throws -> Data {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
    request.setValue("HelloMini", forHTTPHeaderField: "User-Agent")
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpShouldSetCookies = false
    configuration.urlCache = nil
    configuration.timeoutIntervalForRequest = 20
    configuration.timeoutIntervalForResource = 30
    let session = URLSession(
      configuration: configuration, delegate: SameOriginRedirects(), delegateQueue: nil)
    defer { session.finishTasksAndInvalidate() }
    let (data, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse else {
      throw BuildServiceError("No response from the CI service.")
    }
    guard response.statusCode == 200 else {
      switch response.statusCode {
      case 401, 403:
        throw BuildServiceError(
          "Access denied or rate-limited. Check the project and token permissions; try again later."
        )
      case 404: throw BuildServiceError("Project not found, or private project access is missing.")
      case 429: throw BuildServiceError("The CI service rate limit was reached. Try again later.")
      default: throw BuildServiceError("CI service returned HTTP \(response.statusCode).")
      }
    }
    return data
  }
}
private final class SameOriginRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(
      BuildHTTP.allowsRedirect(from: task.originalRequest?.url, to: request.url)
        ? request : nil)
  }
}
