import Foundation

/// A website origin, not an arbitrary API URL. API paths are derived by each provider.
public struct BuildServer: Hashable, Sendable {
  public let website: String
  public init(_ address: String) throws {
    let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !address.contains("%"), !address.contains("\\"),
      !address.unicodeScalars.contains(where: CharacterSet.whitespacesAndNewlines.contains),
      var parts = URLComponents(string: address), parts.scheme?.lowercased() == "https",
      let host = parts.host, !host.isEmpty,
      host.unicodeScalars.allSatisfy({
        CharacterSet(
          charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-:[]"
        ).contains($0)
      }),
      parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
      parts.path.isEmpty || parts.path == "/",
      parts.port == nil || (1...65535).contains(parts.port!)
    else {
      throw BuildServiceError(
        "Use the server's HTTPS website address, with no path, query, or credentials. A port is optional."
      )
    }
    parts.scheme = "https"
    parts.host = host.lowercased()
    parts.path = ""
    if parts.port == 443 { parts.port = nil }
    guard let url = parts.url else { throw BuildServiceError("Invalid server address.") }
    website = url.absoluteString
  }
  public static let github = try! BuildServer("https://github.com")
  public static let gitlab = try! BuildServer("https://gitlab.com")
  public var githubAPI: String { self == .github ? "https://api.github.com" : website + "/api/v3" }
  public var gitlabAPI: String { website + "/api/v4" }
}
