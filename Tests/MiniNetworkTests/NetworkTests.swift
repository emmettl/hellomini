import Foundation
import Network
import Testing

@testable import MiniNetwork

@Test func targetsRejectURLsCredentialsAndInvalidPorts() throws {
  for host in ["", "https://example.com", "user@host", "a b", "-x", "host/path", "host?query"] {
    #expect(throws: ProbeError.self) { try NetworkTarget(host: host, port: "443") }
  }
  for port in ["0", "65536", "-1", "abc"] {
    #expect(throws: ProbeError.self) { try NetworkTarget(host: "localhost", port: port) }
  }
  #expect(try NetworkTarget(host: " ::1 ", port: "443").host == "::1")
}
@Test(.timeLimit(.minutes(1))) func connectionToLocalListenerCompletesAndCancellationCompletesOnce()
  async throws
{
  let listener = try NWListener(using: .tcp, on: .any)
  let queue = DispatchQueue(label: "NetworkProbeTests")
  listener.newConnectionHandler = { connection in connection.cancel() }
  try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
    listener.stateUpdateHandler = { state in
      switch state {
      case .ready:
        listener.stateUpdateHandler = nil
        continuation.resume()
      case .failed(let error):
        listener.stateUpdateHandler = nil
        continuation.resume(throwing: error)
      default: break
      }
    }
    listener.start(queue: queue)
  }
  defer { listener.cancel() }
  let port = try #require(listener.port)
  let probe = NetworkProbe()
  let result = await withCheckedContinuation { continuation in
    probe.start(try! NetworkTarget(host: "127.0.0.1", port: String(port.rawValue))) {
      continuation.resume(returning: $0)
    }
  }
  #expect(try result.get() >= 0)
  // Start and cancel are serialized; a pending connection must always settle.
  let cancelled = await withCheckedContinuation { continuation in
    probe.start(try! NetworkTarget(host: "127.0.0.1", port: "9")) {
      continuation.resume(returning: $0)
    }
    probe.cancel()
  }
  switch cancelled {
  case .failure: break
  case .success: Issue.record("Cancelled call unexpectedly connected")
  }
}

private final class FakeTransport: ProbeTransport, @unchecked Sendable {
  let lock = NSLock()
  private var handler: (@Sendable (ProbeEvent) -> Void)?
  private var queue: DispatchQueue?
  private var stopped = false
  var cancelled: Bool { lock.withLock { stopped } }
  func start(queue: DispatchQueue, handler: @escaping @Sendable (ProbeEvent) -> Void) {
    lock.withLock {
      self.queue = queue
      self.handler = handler
    }
  }
  func cancel() { lock.withLock { stopped = true } }
  func send(_ event: ProbeEvent) {
    let state = lock.withLock { (queue, handler) }
    if let queue = state.0, let handler = state.1 { queue.async { handler(event) } }
  }
}
private final class Deadlines: @unchecked Sendable {
  let lock = NSLock()
  var entries: [(DispatchQueue, @Sendable () -> Void)] = []
  func add(_ queue: DispatchQueue, _ action: @escaping @Sendable () -> Void) -> DispatchWorkItem {
    lock.withLock { entries.append((queue, action)) }
    return DispatchWorkItem(block: action)
  }
  func fire(_ index: Int) {
    let entry = lock.withLock { entries[index] }
    entry.0.async(execute: entry.1)
  }
}
private final class ProbeResults: @unchecked Sendable {
  let lock = NSLock()
  private var results: [Result<Double, Error>] = []
  var values: [Result<Double, Error>] { lock.withLock { results } }
  func add(_ result: Result<Double, Error>) { lock.withLock { results.append(result) } }
}
@Test func probeDeadlinesReplacementDNSFailureAndLateEventsSettleExactlyOnce() async throws {
  let transport = FakeTransport()
  let deadlines = Deadlines()
  let results = ProbeResults()
  let probe = NetworkProbe(factory: { _ in transport }, schedule: { deadlines.add($0, $1) })
  let target = try NetworkTarget(host: "localhost", port: "443")
  probe.start(target) { results.add($0) }
  await probe.settle()
  deadlines.fire(0)
  await probe.settle()
  #expect(transport.cancelled && results.values.count == 1)
  if case .failure(let error) = results.values[0] {
    #expect(error is ProbeError)
  } else {
    Issue.record("Expected timeout")
  }
  transport.send(.ready)
  deadlines.fire(0)
  await probe.settle()
  #expect(results.values.count == 1)

  let first = FakeTransport()
  let second = FakeTransport()
  let replacementResults = ProbeResults()
  let replacementDeadlines = Deadlines()
  let transportLock = NSLock()
  nonisolated(unsafe) var count = 0
  let replacing = NetworkProbe(
    factory: { _ in
      transportLock.withLock {
        count += 1
        return count == 1 ? first : second
      }
    }, schedule: { replacementDeadlines.add($0, $1) })
  replacing.start(target) { replacementResults.add($0) }
  await replacing.settle()
  replacing.start(target) { replacementResults.add($0) }
  await replacing.settle()
  #expect(first.cancelled && replacementResults.values.count == 1)
  first.send(.ready)
  replacementDeadlines.fire(0)
  await replacing.settle()
  #expect(replacementResults.values.count == 1)
  second.send(.failed(NWError.dns(-65538)))
  await replacing.settle()
  #expect(replacementResults.values.count == 2)
  if case .failure(let error) = replacementResults.values[1] {
    #expect(error is NWError)
  } else {
    Issue.record("Expected DNS failure")
  }
  second.send(.ready)
  replacementDeadlines.fire(1)
  replacing.cancel()
  await replacing.settle()
  #expect(replacementResults.values.count == 2)
}
