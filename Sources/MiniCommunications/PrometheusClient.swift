import Foundation
import Security

protocol TelemetryQuerying: Sendable {
  func query(_ query: String, range: Bool, now: Date) async throws -> [TelemetryPoint]
}

struct PrometheusClient: TelemetryQuerying {
  let endpoint: URL
  let token: String?

  static func request(endpoint: URL, query: String, token: String?, range: Bool, now: Date) throws
    -> URLRequest
  {
    var components = URLComponents(
      url: endpoint.appendingPathComponent(range ? "api/v1/query_range" : "api/v1/query"),
      resolvingAgainstBaseURL: false)!
    components.queryItems = [
      URLQueryItem(name: "query", value: query), URLQueryItem(name: "limit", value: "2"),
      URLQueryItem(name: "timeout", value: "10s"),
    ]
    if range {
      components.queryItems! += [
        URLQueryItem(
          name: "start", value: String(now.addingTimeInterval(-3600).timeIntervalSince1970)),
        URLQueryItem(name: "end", value: String(now.timeIntervalSince1970)),
        URLQueryItem(name: "step", value: "60"),
      ]
    }
    guard let url = components.url else {
      throw StationError("Could not construct the metrics request.")
    }
    var request = URLRequest(url: url)
    request.timeoutInterval = 15
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("HelloMini-Communications", forHTTPHeaderField: "User-Agent")
    if let token, !token.isEmpty {
      request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
    }
    return request
  }
  func query(_ query: String, range: Bool = false, now: Date = .now) async throws
    -> [TelemetryPoint]
  {
    let request = try Self.request(
      endpoint: endpoint, query: query, token: token, range: range, now: now)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpShouldSetCookies = false
    configuration.urlCache = nil
    configuration.timeoutIntervalForResource = 20
    let session = URLSession(
      configuration: configuration, delegate: NoTelemetryRedirects(), delegateQueue: nil)
    defer { session.invalidateAndCancel() }
    let (bytes, response) = try await session.bytes(for: request)
    guard let response = response as? HTTPURLResponse else {
      throw StationError("No response from the receiving station.")
    }
    guard response.statusCode == 200 else {
      switch response.statusCode {
      case 401, 403:
        throw StationError("Access denied. Check the server and read-only token in Station Setup.")
      case 429:
        throw StationError("Server rate limit reached. Automatic checks will try again later.")
      case 300..<400:
        throw StationError("Redirect refused. Enter the final metrics server URL in Station Setup.")
      default: throw StationError("Metrics server returned HTTP \(response.statusCode).")
      }
    }
    guard response.expectedContentLength <= 2_000_000 else {
      throw StationError("Metrics response exceeds 2 MB.")
    }
    var data = Data()
    for try await byte in bytes {
      if data.count >= 2_000_000 { throw StationError("Metrics response exceeds 2 MB.") }
      data.append(byte)
    }
    try Task.checkCancellation()
    return try PrometheusResponse.decode(data, range: range)
  }
}

private final class NoTelemetryRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}

enum StationToken {
  static func key(_ endpoint: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "HelloMini.Communications",
      kSecAttrAccount as String: endpoint,
    ]
  }
  static func read(_ endpoint: String) throws -> String? {
    var query = key(endpoint)
    query[kSecReturnData as String] = true
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data,
      let token = String(data: data, encoding: .utf8)
    else { throw StationError("Could not read the station token from Keychain.") }
    return token
  }
  static func save(_ token: String, endpoint: String) throws {
    guard token.utf8.count <= 4096, !token.contains(where: { $0.isNewline || $0 == "\r" }) else {
      throw StationError("The token must be a single line, at most 4096 bytes.")
    }
    let key = key(endpoint)
    let values = [kSecValueData as String: Data(token.utf8)]
    var status = SecItemUpdate(key as CFDictionary, values as CFDictionary)
    if status == errSecItemNotFound {
      status = SecItemAdd(key.merging(values) { _, new in new } as CFDictionary, nil)
    }
    guard status == errSecSuccess else {
      throw StationError("Could not save the station token in Keychain.")
    }
  }
  static func forget(_ endpoint: String) throws {
    let status = SecItemDelete(key(endpoint) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw StationError("Could not forget the station token.")
    }
  }
}
