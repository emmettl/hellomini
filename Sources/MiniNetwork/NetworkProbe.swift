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
enum ProbeEvent: Sendable {
  case ready
  case failed(any Error)
}
protocol ProbeTransport: Sendable {
  func start(queue: DispatchQueue, handler: @escaping @Sendable (ProbeEvent) -> Void)
  func cancel()
}
private final class TCPTransport: ProbeTransport, @unchecked Sendable {
  let connection: NWConnection
  init(_ target: NetworkTarget) {
    connection = NWConnection(
      host: NWEndpoint.Host(target.host), port: NWEndpoint.Port(rawValue: target.port)!, using: .tcp
    )
  }
  func start(queue: DispatchQueue, handler: @escaping @Sendable (ProbeEvent) -> Void) {
    connection.stateUpdateHandler = { state in
      switch state {
      case .ready: handler(.ready)
      case .failed(let error): handler(.failed(error))
      case .waiting(let error):
        // DNS failures and refusals are evidence; avoid turning them into generic timeouts.
        switch error {
        case .dns: handler(.failed(error))
        case .posix(let code) where code == .ECONNREFUSED: handler(.failed(error))
        default: break
        }
      default: break
      }
    }
    connection.start(queue: queue)
  }
  func cancel() {
    connection.stateUpdateHandler = nil
    connection.cancel()
  }
}
/// Transport events, cancellation, replacement and deadlines are serialized on this queue.
final class NetworkProbe: @unchecked Sendable {
  typealias Schedule = @Sendable (DispatchQueue, @escaping @Sendable () -> Void) -> DispatchWorkItem
  private let queue = DispatchQueue(label: "HelloMini.NetworkProbe")
  private let factory: @Sendable (NetworkTarget) -> any ProbeTransport
  private let schedule: Schedule
  private var generation = UUID()
  private var connection: (any ProbeTransport)?
  private var completion: (@Sendable (Result<Double, Error>) -> Void)?
  private var timeout: DispatchWorkItem?
  init(
    factory: @escaping @Sendable (NetworkTarget) -> any ProbeTransport = { TCPTransport($0) },
    schedule: @escaping Schedule = { queue, action in
      let item = DispatchWorkItem(block: action)
      queue.asyncAfter(deadline: .now() + 5, execute: item)
      return item
    }
  ) {
    self.factory = factory
    self.schedule = schedule
  }
  func start(
    _ target: NetworkTarget, completion: @escaping @Sendable (Result<Double, Error>) -> Void
  ) {
    queue.async {
      self.finish(.failure(CancellationError()))
      let generation = UUID()
      self.generation = generation
      self.completion = completion
      let connection = self.factory(target)
      self.connection = connection
      let start = ContinuousClock.now
      self.timeout = self.schedule(self.queue) { [weak self = self] in
        guard let self, self.generation == generation else { return }
        self.finish(.failure(ProbeError.timeout))
      }
      guard self.generation == generation else {
        connection.cancel()
        return
      }
      connection.start(queue: self.queue) { [weak self = self] state in
        guard let self, self.generation == generation else { return }
        switch state {
        case .ready:
          let elapsed = start.duration(to: .now).components
          self.finish(.success(Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15))
        case .failed(let error): self.finish(.failure(error))
        }
      }
    }
  }
  func cancel() { queue.async { self.finish(.failure(CancellationError())) } }
  func settle() async {
    await withCheckedContinuation { continuation in queue.async { continuation.resume() } }
  }
  private func finish(_ result: Result<Double, Error>) {
    generation = UUID()
    timeout?.cancel()
    timeout = nil
    connection?.cancel()
    connection = nil
    let callback = completion
    completion = nil
    callback?(result)
  }
}
