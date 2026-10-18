import Foundation
import Network

struct NetworkTarget: Equatable, Sendable {
  let host: String
  let port: UInt16
  init(host: String, port: String) throws {
    let value = host.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, value.utf8.count <= 253,
      !value.contains(where: { $0.isWhitespace || "/\\@?#".contains($0) }),
      !value.hasPrefix("-"), let number = UInt16(port), number > 0
    else { throw ProbeError.invalidTarget }
    self.host = value
    self.port = number
  }
}
enum ProbeError: LocalizedError {
  case invalidTarget, timeout
  var errorDescription: String? {
    switch self {
    case .invalidTarget:
      "Enter a hostname or IP address and a port from 1 to 65535. Use a host, not a URL."
    case .timeout:
      "No TCP connection within 5 seconds. This does not establish whether the host is offline."
    }
  }
}

/// All connection state, completion and timeout handling run on one serial queue.
final class NetworkProbe: @unchecked Sendable {
  private let queue = DispatchQueue(label: "HelloMini.NetworkProbe")
  private var generation = UUID()
  private var connection: NWConnection?
  private var completion: (@Sendable (Result<Double, Error>) -> Void)?
  private var timeout: DispatchWorkItem?
  func start(
    _ target: NetworkTarget, completion: @escaping @Sendable (Result<Double, Error>) -> Void
  ) {
    queue.async {
      self.finish(.failure(CancellationError()))
      let generation = UUID()
      self.generation = generation
      self.completion = completion
      let connection = NWConnection(
        host: NWEndpoint.Host(target.host), port: NWEndpoint.Port(rawValue: target.port)!,
        using: .tcp)
      self.connection = connection
      let start = ContinuousClock.now
      connection.stateUpdateHandler = { [weak self = self] state in
        guard let self = self, self.generation == generation else { return }
        switch state {
        case .ready:
          let elapsed = start.duration(to: .now).components
          self.finish(.success(Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15))
        case .failed(let error): self.finish(.failure(error))
        default: break
        }
      }
      let timeout = DispatchWorkItem { [weak self = self] in
        guard let self = self, self.generation == generation else { return }
        self.finish(.failure(ProbeError.timeout))
      }
      self.timeout = timeout
      self.queue.asyncAfter(deadline: .now() + 5, execute: timeout)
      connection.start(queue: self.queue)
    }
  }
  func cancel() { queue.async { self.finish(.failure(CancellationError())) } }
  private func finish(_ result: Result<Double, Error>) {
    generation = UUID()
    timeout?.cancel()
    timeout = nil
    connection?.stateUpdateHandler = nil
    connection?.cancel()
    connection = nil
    let callback = completion
    completion = nil
    callback?(result)
  }
}
