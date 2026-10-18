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
