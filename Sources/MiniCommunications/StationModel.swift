import AppKit
import MiniCore
import Observation
import UniformTypeIdentifiers

struct StationLogEntry: Identifiable {
  let id = UUID()
  let date: Date
  let channel: String
  let state: ChannelState
  let message: String
}

@MainActor @Observable final class StationModel {
  private(set) var configuration: StationConfiguration
  private(set) var readings: [UUID: ChannelReading] = [:]
  private(set) var log: [StationLogEntry] = []
  private(set) var chart: [TelemetryPoint] = []
  private(set) var chartError: String?
  private(set) var chartChannel: UUID?
  private(set) var chartLoadedAt: Date?
  private(set) var busy = false
  private(set) var demo = false
  private(set) var loadError: String?
  var notice: String?
  var selection: UUID?
  var showSetup = false
  var lampTestUntil = Date.distantPast
  var now = Date.now
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let makeClient: @MainActor (String) throws -> any TelemetryQuerying
  @ObservationIgnored private let notify: @MainActor (Bool) -> Void
  @ObservationIgnored private var lastStates: [UUID: ChannelState] = [:]
  @ObservationIgnored private var pollTask: Task<Void, Never>?
  @ObservationIgnored private var chartTask: Task<Void, Never>?
  @ObservationIgnored private var revision = UUID()
  @ObservationIgnored private var nextPoll = Date.distantPast
  @ObservationIgnored private var demoConfiguration = StationConfiguration.motionStudies
  static let storageKey = "communications.station.v1"

  init(
    defaults: UserDefaults = .standard, notify: @escaping @MainActor (Bool) -> Void = { _ in },
    makeClient: @escaping @MainActor (String) throws -> any TelemetryQuerying = { endpoint in
      PrometheusClient(
        endpoint: try StationConfiguration.baseURL(endpoint), token: try StationToken.read(endpoint)
      )
    }
  ) {
    self.makeClient = makeClient
    self.defaults = defaults
    self.notify = notify
    if let data = defaults.data(forKey: Self.storageKey) {
      do {
        guard data.count <= 64_000 else { throw StationError("Saved station is too large.") }
        configuration = try JSONDecoder().decode(StationConfiguration.self, from: data).validated()
      } catch {
        configuration = StationConfiguration()
        loadError =
          "Saved station could not be read. Export or repair the saved preferences before replacing it."
      }
    } else {
      configuration = StationConfiguration()
    }
  }
  var displayedConfiguration: StationConfiguration { demo ? demoConfiguration : configuration }
  var channels: [StationChannel] { displayedConfiguration.channels }
  var selected: StationChannel? { channels.first { $0.id == selection } ?? channels.first }
  var isConnected: Bool { demo || configuration.connected }
  var attention: Bool {
    isConnected && channels.contains { [.degraded, .unknown].contains(state($0)) }
  }
  func state(_ channel: StationChannel) -> ChannelState {
    if !isConnected { return .paused }
    return readings[channel.id]?.state(for: channel, now: now) ?? .unknown
  }
  func explanation(_ channel: StationChannel) -> String {
    guard isConnected else { return "Station disconnected. Last readings are historical." }
    guard let reading = readings[channel.id] else { return "No reading received yet." }
    if let error = reading.error { return error }
    if state(channel) == .unknown {
      return
        "Evidence is missing, stale, invalid, or reports an unknown state. A fresh HTTP response alone is not proof of healthy data."
    }
    if channel.kind == .state {
      return "Reported state: " + state(channel).title
        + ". Codes: 0 healthy, 1 waiting, 2 degraded, 3 paused, 4 unknown."
    }
    if let threshold = channel.threshold {
      return
        "Attention when the value is \(channel.belowIsBad ? "below" : "above") \(channel.formatted(threshold))."
    }
    return "Sample is current. No health threshold is configured."
  }
  func save(_ draft: StationConfiguration, token: String, forgetToken: Bool) throws {
    guard loadError == nil else {
      throw StationError("Unreadable saved station is protected from replacement.")
    }
    var draft = draft
    draft.endpoint = draft.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
    if !draft.endpoint.isEmpty {
      draft.endpoint = try StationConfiguration.baseURL(draft.endpoint).absoluteString
    }
    draft = try draft.validated()
    let data = try JSONEncoder().encode(draft)
    if forgetToken {
      try StationToken.forget(draft.endpoint)
    } else if !token.isEmpty {
      guard !draft.endpoint.isEmpty else {
        throw StationError("Enter a server before saving a token.")
      }
      try StationToken.save(token, endpoint: draft.endpoint)
    }
    reset()
    configuration = draft
    defaults.set(data, forKey: Self.storageKey)
    selection = draft.channels.first?.id
    showSetup = false
  }
  func disconnect() {
    if demo {
      reset()
      return
    }
    guard loadError == nil else { return }
    reset()
    configuration.connected = false
    persist()
    notice = "Receiver off. Collection continues at the server."
  }
  func connect() {
    guard loadError == nil else { return }
    if configuration.endpoint.isEmpty || configuration.channels.isEmpty {
      showSetup = true
      return
    }
    reset()
    configuration.connected = true
    persist()
  }
  private func persist() {
    if let data = try? JSONEncoder().encode(configuration) {
      defaults.set(data, forKey: Self.storageKey)
    }
  }
  private func reset() {
    revision = UUID()
    pollTask?.cancel()
    pollTask = nil
    chartTask?.cancel()
    chartTask = nil
    busy = false
    demo = false
    readings = [:]
    lastStates = [:]
    log = []
    chart = []
    chartChannel = nil
    chartError = nil
    chartLoadedAt = nil
    nextPoll = .distantPast
    notice = nil
  }
  func simulate() {
    // Demonstration does not contact a server or replace the saved station.
    reset()
    demo = true
    selection = demoConfiguration.channels.first?.id
    now = .now
    updateDemo()
  }
  func tick(at date: Date = .now) {
    now = date
    if demo { updateDemo() }
    recordTransitions()
  }
  func testLamps() { lampTestUntil = Date.now.addingTimeInterval(3) }
  func recordTransitions() {
    guard isConnected else { return }
    var alarm = false
    var recovery = false
    for channel in channels {
      guard readings[channel.id] != nil else { continue }
      let state = state(channel)
      let previous = lastStates[channel.id]
      guard previous != state else { continue }
      lastStates[channel.id] = state
      let message =
        previous == nil ? "First observation — \(state.title.lowercased())." : state.title + "."
      log.insert(
        StationLogEntry(date: now, channel: channel.name, state: state, message: message), at: 0)
      if let previous {
        alarm =
          alarm
          || ([.degraded, .unknown].contains(state) && ![.degraded, .unknown].contains(previous))
        recovery = recovery || (state == .healthy && [.degraded, .unknown].contains(previous))
      }
    }
    if log.count > 200 { log.removeLast(log.count - 200) }
    if !demo && configuration.audibleAlerts && (alarm || recovery) { notify(alarm) }
  }
  func refresh(force: Bool = false) async {
    tick()
    guard !demo, configuration.connected, !busy, loadError == nil, force || now >= nextPoll else {
      return
    }
    nextPoll = now.addingTimeInterval(30)
    let generation = revision
    let config = configuration
    busy = true
    let task = Task { [weak self] in
      guard let self else { return }
      do {
        let client = try makeClient(config.endpoint)
        // Three channels at a time; one bad channel must not hide the other stations.
        for start in stride(from: 0, to: config.channels.count, by: 3) {
          let batch = Array(config.channels[start..<min(start + 3, config.channels.count)])
          let results = await withTaskGroup(of: (UUID, ChannelReading).self) { group in
            for channel in batch {
              group.addTask {
                do {
                  guard
                    let point = try await client.query(channel.query, range: false, now: .now).first
                  else {
                    throw StationError("No finite sample. Check the query and feed availability.")
                  }
                  var evidence: Date?
                  if !channel.evidenceQuery.isEmpty {
                    guard
                      let stamp = try await client.query(
                        channel.evidenceQuery, range: false, now: .now
                      ).first,
                      stamp.value > 0,
                      (-30...channel.maxAge).contains(Date.now.timeIntervalSince(stamp.date))
                    else { throw StationError("No current evidence timestamp is available.") }
                    evidence = Date(timeIntervalSince1970: stamp.value)
                  }
                  return (
                    channel.id, ChannelReading(point: point, evidenceAt: evidence, receivedAt: .now)
                  )
                } catch {
                  return (
                    channel.id,
                    ChannelReading(
                      error: (error as? StationError)?.message
                        ?? "Connection failed. Check the server, network, and TLS certificate.")
                  )
                }
              }
            }
            var results: [(UUID, ChannelReading)] = []
            for await result in group { results.append(result) }
            return results
          }
          guard generation == self.revision, !Task.isCancelled else { return }
          for (id, reading) in results { self.readings[id] = reading }
          self.tick()
        }
      } catch {
        guard generation == self.revision, !Task.isCancelled else { return }
        let message = (error as? StationError)?.message ?? "Station connection failed."
        for channel in config.channels {
          self.readings[channel.id] = ChannelReading(error: message)
        }
        self.tick()
      }
      guard generation == self.revision else { return }
      self.busy = false
      if self.chartChannel != nil { self.loadChart() }
    }
    pollTask = task
    await task.value
  }
  func loadChart() {
    chartTask?.cancel()
    guard let channel = selected else { return }
    chart = []
    chartError = nil
    chartLoadedAt = nil
    chartChannel = channel.id
    if demo {
      for offset in 0...60 {
        let date = now.addingTimeInterval(Double(offset - 60) * 60)
        let stateValue: Double = offset > 22 && offset < 30 ? 2 : 0
        let value: Double = channel.kind == .state ? stateValue : 25 + sin(Double(offset) / 5) * 12
        chart.append(TelemetryPoint(date: date, value: value))
      }
      chartLoadedAt = now
      return
    }
    guard configuration.connected else {
      chartError = "Connect the station to request recorded history."
      return
    }
    let config = configuration
    let generation = revision
    chartTask = Task {
      do {
        let client = try makeClient(config.endpoint)
        let points = try await client.query(channel.query, range: true, now: .now)
        guard !Task.isCancelled, generation == revision, chartChannel == channel.id else { return }
        chart = points
        chartLoadedAt = .now
        if points.isEmpty { chartError = "No recorded samples in the last hour." }
      } catch {
        guard !Task.isCancelled, generation == revision, chartChannel == channel.id else { return }
        chartError = (error as? StationError)?.message ?? "Could not retrieve the chart."
      }
    }
  }
  private func updateDemo() {
    for (index, channel) in channels.enumerated() {
      let value = channel.kind == .seconds ? 24.0 : index == 2 ? 1.0 : index == 4 ? 2.0 : 0.0
      readings[channel.id] = ChannelReading(
        point: TelemetryPoint(date: now, value: value), evidenceAt: now, receivedAt: now)
    }
  }
  func exportConfiguration() {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "communications-station.json"
    panel.allowedContentTypes = [.json]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      var copy = configuration
      copy.connected = false
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      try encoder.encode(copy).write(to: url, options: .atomic)
      notice = "Station exported. Keychain credentials and readings are not included."
    } catch { notice = "Could not export the station." }
  }
}
