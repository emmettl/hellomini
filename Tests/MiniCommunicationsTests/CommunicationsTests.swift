import Foundation
import Testing

@testable import MiniCommunications

private let sampleTime = Date(timeIntervalSince1970: 1_790_000_000)

@Test func evidenceCannotBeRenewedByPolling() {
  let channel = StationChannel(evidenceQuery: "source_timestamp", kind: .state)
  let good = ChannelReading(
    point: .init(date: sampleTime, value: 0), evidenceAt: sampleTime, receivedAt: sampleTime)
  #expect(good.state(for: channel, now: sampleTime) == .healthy)
  #expect(good.state(for: channel, now: sampleTime.addingTimeInterval(181)) == .unknown)
  var stale = good
  stale.evidenceAt = sampleTime.addingTimeInterval(-181)
  #expect(stale.state(for: channel, now: sampleTime) == .unknown)
  stale.evidenceAt = sampleTime.addingTimeInterval(31)
  #expect(stale.state(for: channel, now: sampleTime) == .unknown)
  stale.evidenceAt = nil
  #expect(stale.state(for: channel, now: sampleTime) == .unknown)
  stale = good
  stale.error = "Offline"
  #expect(stale.state(for: channel, now: sampleTime) == .unknown)
  stale = good
  stale.point = .init(date: sampleTime.addingTimeInterval(-181), value: 0)
  #expect(stale.state(for: channel, now: sampleTime) == .unknown)
}

@Test func statesAndThresholdBoundaries() {
  var channel = StationChannel(kind: .state)
  for (number, state) in [ChannelState.healthy, .waiting, .degraded, .paused, .unknown].enumerated()
  {
    #expect(channel.classify(Double(number)) == state)
  }
  for value in [Double.nan, .infinity, -1, 1.5, 99] { #expect(channel.classify(value) == .unknown) }
  channel.kind = .seconds
  channel.threshold = 180
  #expect(channel.classify(180) == .healthy)
  #expect(channel.classify(181) == .degraded)
  channel.belowIsBad = true
  #expect(channel.classify(179) == .degraded)
}

@Test func destinationsAndProfilesAreValidated() throws {
  for url in [
    "http://localhost:9090", "http://127.0.0.1:9090", "http://[::1]:9090",
    "https://metrics.example/base",
  ] {
    #expect(throws: Never.self) { try StationConfiguration.baseURL(url) }
  }
  for url in [
    "http://metrics.example", "https://user:secret@example.org", "https://example.org?token=secret",
    "https://example.org/#secret", "file:///tmp/metrics",
  ] {
    #expect(throws: StationError.self) { try StationConfiguration.baseURL(url) }
  }
  var profile = StationConfiguration.motionStudies
  #expect(try profile.validated().channels.count == 7)
  profile.channels.append(profile.channels[0])
  #expect(throws: StationError.self) { try profile.validated() }
  profile = .motionStudies
  profile.connected = true
  #expect(throws: StationError.self) { try profile.validated() }
  profile.connected = false
  profile.channels[0].maxAge = 0
  #expect(throws: StationError.self) { try profile.validated() }
}

private func response(_ type: String, _ result: String, extra: String = "") -> Data {
  Data(
    "{\"status\":\"success\",\"data\":{\"resultType\":\"\(type)\",\"result\":\(result)}\(extra)}"
      .utf8)
}

@Test func decodingRefusesAmbiguityAndPartialResults() throws {
  let vector = "[{\"value\":[1790000000,\"0\"]}]"
  #expect(try PrometheusResponse.decode(response("vector", vector), range: false).first?.value == 0)
  #expect(
    try PrometheusResponse.decode(response("scalar", "[1790000000,\"5\"]"), range: false).first?
      .value == 5)
  #expect(try PrometheusResponse.decode(response("vector", "[]"), range: false).isEmpty)
  #expect(throws: StationError.self) {
    try PrometheusResponse.decode(
      response("vector", "[{\"value\":[1790000000,\"0\"]},{\"value\":[1790000000,\"2\"]}]"),
      range: false)
  }
  #expect(throws: StationError.self) {
    try PrometheusResponse.decode(
      response("vector", vector, extra: ",\"warnings\":[\"partial\"]"), range: false)
  }
  for value in ["NaN", "+Inf", "-Inf"] {
    #expect(
      try PrometheusResponse.decode(response("scalar", "[1790000000,\"\(value)\"]"), range: false)
        .isEmpty)
  }
  #expect(throws: StationError.self) {
    try PrometheusResponse.decode(Data(repeating: 32, count: 2_000_001), range: false)
  }
}

@Test func chartsKeepGapsAndRejectOutOfOrderData() throws {
  let data = response(
    "matrix", "[{\"values\":[[1790000000,\"0\"],[1790000060,\"NaN\"],[1790000120,\"2\"]]}]")
  let points = try PrometheusResponse.decode(data, range: true)
  #expect(points.count == 2)
  #expect(points[1].date.timeIntervalSince(points[0].date) == 120)
  #expect(throws: StationError.self) {
    try PrometheusResponse.decode(
      response("matrix", "[{\"values\":[[1790000060,\"0\"],[1790000000,\"2\"]]}]"), range: true)
  }
}

@Test func requestKeepsCredentialsOutOfURLAndPreservesBasePath() throws {
  let endpoint = try StationConfiguration.baseURL("https://metrics.example/prometheus")
  let request = try PrometheusClient.request(
    endpoint: endpoint, query: "up{job=\"recorder\"}", token: "test-only-token", range: true,
    now: sampleTime)
  #expect(request.httpMethod == "GET")
  #expect(request.url?.path == "/prometheus/api/v1/query_range")
  #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-only-token")
  #expect(request.url?.absoluteString.contains("test-only-token") == false)
  let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
  #expect(items.contains(URLQueryItem(name: "query", value: "up{job=\"recorder\"}")))
  #expect(items.contains(URLQueryItem(name: "step", value: "60")))
  #expect(items.contains(URLQueryItem(name: "limit", value: "2")))
}

private actor FakeTelemetry: TelemetryQuerying {
  var value: Double = 0
  var fail = false
  func set(value: Double = 0, fail: Bool = false) {
    self.value = value
    self.fail = fail
  }
  func query(_ query: String, range: Bool, now: Date) async throws -> [TelemetryPoint] {
    if fail || query == "broken" { throw StationError("Test connection failed.") }
    return [.init(date: now, value: query == "evidence" ? now.timeIntervalSince1970 : value)]
  }
}

@MainActor @Test func pollingFailuresRecoverWithoutRepeatingAlerts() async throws {
  let name = "CommunicationsTests.\(UUID())"
  let defaults = UserDefaults(suiteName: name)!
  defer { defaults.removePersistentDomain(forName: name) }
  let fake = FakeTelemetry()
  var alerts: [Bool] = []
  let model = StationModel(
    defaults: defaults, notify: { alerts.append($0) }, makeClient: { _ in fake })
  let channel = StationChannel(query: "state", evidenceQuery: "evidence", kind: .state)
  try model.save(
    StationConfiguration(
      endpoint: "http://localhost:9090", channels: [channel], connected: true, audibleAlerts: true),
    token: "", forgetToken: false)
  await model.refresh(force: true)
  #expect(model.state(channel) == .healthy)
  #expect(alerts.isEmpty)
  await fake.set(fail: true)
  await model.refresh(force: true)
  #expect(model.state(channel) == .unknown)
  #expect(alerts == [true])
  await model.refresh(force: true)
  #expect(alerts == [true])
  await fake.set()
  await model.refresh(force: true)
  #expect(model.state(channel) == .healthy)
  #expect(alerts == [true, false])
  #expect(model.log.count == 3)
  model.tick(at: .now.addingTimeInterval(181))
  #expect(model.state(channel) == .unknown)
  #expect(alerts == [true, false, true])
}

@MainActor @Test func oneBrokenChannelDoesNotHideGoodChannelAndDemoDoesNotPersist() async throws {
  let name = "CommunicationsTests.\(UUID())"
  let defaults = UserDefaults(suiteName: name)!
  defer { defaults.removePersistentDomain(forName: name) }
  let fake = FakeTelemetry()
  let model = StationModel(defaults: defaults, makeClient: { _ in fake })
  let good = StationChannel(query: "state", kind: .state)
  let bad = StationChannel(query: "broken", kind: .state)
  try model.save(
    StationConfiguration(
      endpoint: "http://localhost:9090", channels: [good, bad], connected: true), token: "",
    forgetToken: false)
  await model.refresh(force: true)
  #expect(model.state(good) == .healthy)
  #expect(model.state(bad) == .unknown)
  model.testLamps()
  #expect(model.state(bad) == .unknown)
  let saved = defaults.data(forKey: StationModel.storageKey)
  model.simulate()
  await model.refresh(force: true)
  #expect(model.demo)
  #expect(model.channels.count == 7)
  #expect(defaults.data(forKey: StationModel.storageKey) == saved)
  model.disconnect()
  #expect(!model.demo)
  #expect(model.channels.count == 2)
}

@MainActor @Test func corruptSavedConfigurationIsPreserved() throws {
  let name = "CommunicationsTests.\(UUID())"
  let defaults = UserDefaults(suiteName: name)!
  defer { defaults.removePersistentDomain(forName: name) }
  let corrupt = Data("not a profile".utf8)
  defaults.set(corrupt, forKey: StationModel.storageKey)
  let model = StationModel(defaults: defaults)
  #expect(model.loadError != nil)
  #expect(!model.isConnected)
  #expect(throws: StationError.self) {
    try model.save(.motionStudies, token: "", forgetToken: false)
  }
  #expect(defaults.data(forKey: StationModel.storageKey) == corrupt)
}

private actor DelayedTelemetry: TelemetryQuerying {
  var started = false
  var waiter: CheckedContinuation<Void, Never>?
  var response: CheckedContinuation<[TelemetryPoint], Never>?
  func waitUntilStarted() async {
    if started { return }
    await withCheckedContinuation { waiter = $0 }
  }
  func finish() {
    response?.resume(returning: [.init(date: .now, value: 0)])
    response = nil
  }
  func query(_ query: String, range: Bool, now: Date) async throws -> [TelemetryPoint] {
    return await withCheckedContinuation { continuation in
      response = continuation
      started = true
      waiter?.resume()
      waiter = nil
    }
  }
}

@MainActor @Test func disconnectedStationRejectsLateResponses() async throws {
  let name = "CommunicationsTests.\(UUID())"
  let defaults = UserDefaults(suiteName: name)!
  defer { defaults.removePersistentDomain(forName: name) }
  let fake = DelayedTelemetry()
  let model = StationModel(defaults: defaults, makeClient: { _ in fake })
  let channel = StationChannel(kind: .state)
  try model.save(
    StationConfiguration(endpoint: "http://localhost:9090", channels: [channel], connected: true),
    token: "", forgetToken: false)
  let poll = Task { await model.refresh(force: true) }
  await fake.waitUntilStarted()
  model.disconnect()
  await fake.finish()
  await poll.value
  #expect(!model.isConnected)
  #expect(!model.busy)
  #expect(model.readings.isEmpty)
  #expect(model.log.isEmpty)
  #expect(model.state(channel) == .paused)
}
