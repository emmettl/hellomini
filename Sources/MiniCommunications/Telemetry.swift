import Foundation

struct StationError: LocalizedError, Sendable {
  let message: String
  init(_ message: String) { self.message = message }
  var errorDescription: String? { message }
}

enum ChannelState: String, Codable, CaseIterable, Sendable {
  case healthy, waiting, degraded, paused, unknown
  var title: String {
    switch self {
    case .healthy: "Receiving normally"
    case .waiting: "Standing by"
    case .degraded: "Attention required"
    case .paused: "Channel paused"
    case .unknown: "Signal lost"
    }
  }
  var symbol: String {
    switch self {
    case .healthy: "checkmark.circle.fill"
    case .waiting: "clock.fill"
    case .degraded: "exclamationmark.triangle.fill"
    case .paused: "pause.circle"
    case .unknown: "questionmark.circle"
    }
  }
}

enum ReadingKind: String, Codable, CaseIterable, Sendable {
  case number, seconds, state
}

struct StationChannel: Codable, Identifiable, Equatable, Sendable {
  var id = UUID()
  var name = "New channel"
  var query = "up"
  var evidenceQuery = ""
  var unit = ""
  var kind: ReadingKind = .number
  var threshold: Double? = nil
  var belowIsBad = false
  var maxAge: Double = 180

  func classify(_ value: Double) -> ChannelState {
    guard value.isFinite else { return .unknown }
    if kind == .state {
      switch value {
      case 0: return .healthy
      case 1: return .waiting
      case 2: return .degraded
      case 3: return .paused
      default: return .unknown
      }
    }
    guard let threshold else { return .healthy }
    return (belowIsBad ? value < threshold : value > threshold) ? .degraded : .healthy
  }
  func formatted(_ value: Double) -> String {
    if kind == .state { return classify(value).title }
    return value.formatted(.number.precision(.fractionLength(0...2)))
      + (kind == .seconds ? " s" : unit.isEmpty ? "" : " " + unit)
  }
}

struct StationConfiguration: Codable, Equatable, Sendable {
  var version = 1
  var name = "Communications station"
  var endpoint = ""
  var channels: [StationChannel] = []
  var connected = false
  var audibleAlerts = false

  func validated() throws -> Self {
    guard version == 1, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      name.count <= 80, channels.count <= 8,
      Set(channels.map(\.id)).count == channels.count
    else {
      throw StationError(
        "Use a station name and at most eight distinct channels (format version 1).")
    }
    if !endpoint.isEmpty { _ = try Self.baseURL(endpoint) }
    for channel in channels {
      guard !channel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        channel.name.count <= 80,
        !channel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        channel.query.utf8.count <= 2048, channel.evidenceQuery.utf8.count <= 2048,
        channel.unit.count <= 24, channel.maxAge.isFinite, (30...86400).contains(channel.maxAge),
        channel.threshold == nil || channel.threshold!.isFinite
      else {
        throw StationError(
          "Each channel needs a name, one bounded query, and freshness between 30 and 86400 seconds."
        )
      }
    }
    if connected && (endpoint.isEmpty || channels.isEmpty) {
      throw StationError("Set a server and at least one channel before connecting.")
    }
    return self
  }
  static func baseURL(_ text: String) throws -> URL {
    guard let c = URLComponents(string: text), let url = c.url,
      let host = c.host, !host.isEmpty, c.user == nil, c.password == nil,
      c.query == nil, c.fragment == nil,
      c.scheme == "https"
        || (c.scheme == "http" && ["localhost", "127.0.0.1", "[::1]", "::1"].contains(host)),
      c.port == nil || (1...65535).contains(c.port!)
    else {
      throw StationError(
        "Use an HTTPS server URL without credentials, query, or fragment. HTTP is allowed only on loopback for local Prometheus."
      )
    }
    return url
  }
  static var motionStudies: Self {
    let feeds = [
      ("uk-bus-archive", "UK bus archive"), ("london-arrivals", "London arrivals"),
      ("london-docks", "London cycle docks"), ("swiss-realtime", "Swiss realtime"),
      ("uk-bus-disruptions", "UK bus disruptions"),
    ]
    return Self(
      name: "Motion Studies receiving station",
      channels: [
        StationChannel(
          name: "Observer assessment", query: "motionstudies_observer_state",
          evidenceQuery: "motionstudies_observer_check_timestamp_seconds", kind: .state)
      ]
        + feeds.map { id, name in
          StationChannel(
            name: name,
            query: "motionstudies_feed_state{feed=\"\(id)\"}",
            evidenceQuery: "motionstudies_observer_check_timestamp_seconds",
            kind: .state)
        } + [
          StationChannel(
            name: "Recorder heartbeat", query: "time() - motionstudies_producer_timestamp_seconds",
            evidenceQuery: "motionstudies_observer_check_timestamp_seconds", kind: .seconds,
            threshold: 180)
        ])
  }
}

struct TelemetryPoint: Equatable, Sendable {
  let date: Date
  let value: Double
}
struct ChannelReading: Sendable {
  var point: TelemetryPoint?
  var evidenceAt: Date?
  var receivedAt: Date?
  var error: String?
  func state(for channel: StationChannel, now: Date) -> ChannelState {
    guard error == nil, let point, let receivedAt,
      fresh(receivedAt, now: now, limit: channel.maxAge),
      fresh(point.date, now: now, limit: channel.maxAge)
    else { return .unknown }
    if !channel.evidenceQuery.isEmpty {
      guard let evidenceAt, fresh(evidenceAt, now: now, limit: channel.maxAge) else {
        return .unknown
      }
    }
    return channel.classify(point.value)
  }
  private func fresh(_ date: Date, now: Date, limit: Double) -> Bool {
    (-30...limit).contains(now.timeIntervalSince(date))
  }
}

/// Bounded Prometheus response decoding. Empty/ambiguous/partial/non-finite results never imply health.
enum PrometheusResponse {
  static func decode(_ data: Data, range: Bool) throws -> [TelemetryPoint] {
    guard data.count <= 2_000_000,
      let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      root["status"] as? String == "success",
      root["warnings"] == nil || (root["warnings"] as? [String])?.isEmpty == true,
      let body = root["data"] as? [String: Any], let type = body["resultType"] as? String
    else {
      throw StationError(
        "The server returned an error, partial result, or invalid metrics response.")
    }
    func point(_ raw: Any) throws -> TelemetryPoint? {
      guard let pair = raw as? [Any], pair.count == 2,
        let seconds = pair[0] as? Double, seconds.isFinite, seconds > 0,
        let text = pair[1] as? String, let value = Double(text)
      else { throw StationError("The server returned an invalid sample.") }
      // Prometheus marks gaps and undefined calculations with NaN/Inf.
      guard value.isFinite else { return nil }
      return TelemetryPoint(date: Date(timeIntervalSince1970: seconds), value: value)
    }
    if !range && type == "scalar" {
      return try point(body["result"] as Any).map { [$0] } ?? []
    }
    guard type == (range ? "matrix" : "vector"), let series = body["result"] as? [[String: Any]],
      series.count <= 1
    else {
      throw StationError(
        "A channel must return one series. Filter its labels or aggregate the query.")
    }
    guard let first = series.first else { return [] }
    if !range { return try point(first["value"] as Any).map { [$0] } ?? [] }
    guard let values = first["values"] as? [Any], values.count <= 720 else {
      throw StationError("The chart response is invalid or too large.")
    }
    var previous = Date.distantPast
    return try values.compactMap { raw in
      guard let value = try point(raw) else { return nil }
      guard value.date > previous else { throw StationError("Chart samples are out of order.") }
      previous = value.date
      return value
    }
  }
}
