import Foundation

/// Writes never follow redirects or automatically repeat an uncertain response.
public enum BuildRetryHTTP {
  public static func post(url: URL, headers: [String: String]) async throws {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("HelloMini", forHTTPHeaderField: "User-Agent")
    for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpShouldSetCookies = false
    configuration.urlCache = nil
    configuration.timeoutIntervalForRequest = 30
    configuration.timeoutIntervalForResource = 30
    let session = URLSession(
      configuration: configuration, delegate: NoRetryRedirects(), delegateQueue: nil)
    defer { session.finishTasksAndInvalidate() }
    let (_, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse else {
      throw BuildServiceError("No retry response. Check the provider before trying again.")
    }
    guard [200, 201, 202, 204].contains(response.statusCode) else {
      throw BuildServiceError(
        "Retry returned HTTP \(response.statusCode). Check token write permissions and the run on the provider before trying again."
      )
    }
  }
}
private final class NoRetryRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}
