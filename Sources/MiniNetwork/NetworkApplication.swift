import Darwin
import Foundation
import MiniCore
import MiniUI
import Network
import Observation
import SwiftUI

struct InterfaceAddress: Identifiable, Sendable {
  var id: String { name + address }
  let name: String
  let address: String
  static func read() -> [Self] {
    var first: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&first) == 0 else { return [] }
    defer { freeifaddrs(first) }
    var result: [Self] = []
    var current = first
    while let pointer = current {
      defer { current = pointer.pointee.ifa_next }
      let entry = pointer.pointee
      guard let addr = entry.ifa_addr, entry.ifa_flags & UInt32(IFF_UP) != 0,
        [UInt8(AF_INET), UInt8(AF_INET6)].contains(addr.pointee.sa_family)
      else { continue }
      var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      if getnameinfo(
        addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
        == 0
      {
        result.append(
          Self(
            name: String(cString: entry.ifa_name),
            address: String(
              decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)))
      }
    }
    return result.sorted { ($0.name, $0.address) < ($1.name, $1.address) }
  }
}
@MainActor @Observable final class NetworkModel {
  var host = ""
  var port = "443"
  private(set) var pathStatus = "Waiting for connection status…"
  private(set) var interfaces: [InterfaceAddress] = []
  private(set) var checking = false
  private(set) var message = "Enter a destination. No calls have been placed."
  private(set) var history: [String] = []
  @ObservationIgnored private var monitor: NWPathMonitor?
  @ObservationIgnored private let probe = NetworkProbe()
  @ObservationIgnored private var generation = UUID()
  func start() {
    guard monitor == nil else { return }
    let monitor = NWPathMonitor()
    self.monitor = monitor
    let generation = UUID()
    self.generation = generation
    monitor.pathUpdateHandler = { [weak self] path in
      let description =
        path.status == .satisfied
        ? "Connection available"
        : path.status == .requiresConnection ? "Connection required" : "No connection available"
      let names = Set(
        path.availableInterfaces.filter { path.usesInterfaceType($0.type) }.map(\.name)
      ).sorted().joined(separator: ", ")
      Task { @MainActor [weak self] in
        guard let self, self.generation == generation else { return }
        self.pathStatus = description + (names.isEmpty ? "" : " · " + names)
        self.refreshAddresses()
      }
    }
    monitor.start(queue: DispatchQueue(label: "HelloMini.NetworkPath"))
  }
  func refreshAddresses() {
    let generation = generation
    Task {
      let entries = await Task.detached { InterfaceAddress.read() }.value
      guard self.generation == generation else { return }
      interfaces = entries
    }
  }
  func stop() {
    monitor?.cancel()
    monitor = nil
    generation = UUID()
    cancel()
  }
  func cancel() {
    probe.cancel()
    if checking { message = "Call cancelled." }
    checking = false
    checkID = UUID()
  }
  @ObservationIgnored private var checkID = UUID()
  func check() {
    guard !checking else { return }
    do {
      let target = try NetworkTarget(host: host, port: port)
      checking = true
      checkID = UUID()
      let id = checkID
      message = "Opening TCP connection to \(target.host):\(target.port)…"
      probe.start(target) { [weak self] result in
        Task { @MainActor [weak self] in
          guard let self, self.checkID == id else { return }
          self.checking = false
          switch result {
          case .success(let milliseconds):
            self.message = String(format: "TCP connected in %.1f ms", milliseconds)
          case .failure(let error): self.message = error.localizedDescription
          }
          self.history.insert(
            Date.now.formatted(date: .omitted, time: .standard)
              + " · \(target.host):\(target.port) · " + self.message, at: 0)
          self.history = Array(self.history.prefix(20))
        }
      }
    } catch { message = error.localizedDescription }
  }
}
@MainActor public final class NetworkApplication: MiniApplication {
  public let id = "network"
  public let name = "Network"
  public let icon = MiniApplicationIcon.network
  public let defaultSize = CGSize(width: 640, height: 440)
  public let minimumSize = CGSize(width: 440, height: 240)
  private let model = NetworkModel()
  private let playfulness: PlayfulnessSettings
  public static let effect = MiniPlayfulEffect(
    id: "network-modem", name: "Modem commentary",
    description: "An unnecessarily solemn telephone operator narrates network tests.")
  public init(playfulness: PlayfulnessSettings) { self.playfulness = playfulness }
  public func content() -> AnyView { AnyView(NetworkView(model: model, playfulness: playfulness)) }
}
private struct NetworkView: View {
  @Environment(\.miniTheme) private var theme
  @Bindable var model: NetworkModel
  let playfulness: PlayfulnessSettings
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(model.pathStatus).font(theme.typography.title).accessibilityLabel(
        "Network status: " + model.pathStatus)
      ViewThatFits(in: .horizontal) {
        controls(short: false)
        controls(short: true)
      }
      Text(model.message).font(theme.typography.small).textSelection(.enabled).lineLimit(3)
      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          Text("INTERFACES").font(theme.typography.title)
          ForEach(model.interfaces) { item in
            Text(item.name + " · " + item.address).textSelection(.enabled)
          }
          if model.interfaces.isEmpty { Text("No active IP addresses reported.") }
          Divider()
          Text("CALL LOG · THIS SESSION").font(theme.typography.title)
          ForEach(Array(model.history.enumerated()), id: \.offset) { _, entry in
            Text(entry).textSelection(.enabled)
          }
          if playfulness.allows(NetworkApplication.effect.id) {
            Text(
              model.checking
                ? "The operator is connecting your very small computer."
                : "The line is yours. Please do not feed packets to the fish.")
          }
          Text(
            "TCP setup time includes name resolution. It is not ICMP ping, bandwidth, TLS verification, or proof of Internet access. Tests run only when you choose Call."
          )
        }.frame(maxWidth: .infinity, alignment: .leading)
      }.font(theme.typography.small)
    }.padding(10).foregroundStyle(theme.ink).background(theme.paper)
      .onAppear { model.start() }.onDisappear { model.stop() }
  }
  private func controls(short: Bool) -> some View {
    HStack(spacing: 6) {
      TextField("Hostname or IP", text: $model.host).accessibilityLabel(
        "Destination hostname or IP address"
      )
      .padding(5).background(theme.paper).overlay(Rectangle().stroke(theme.ink, lineWidth: 1))
      .frame(minWidth: 100).disabled(model.checking)
      Text("Port").font(theme.typography.small)
      TextField("Port", text: $model.port).accessibilityLabel("TCP port")
        .padding(5).background(theme.paper).overlay(Rectangle().stroke(theme.ink, lineWidth: 1))
        .frame(width: 58).disabled(model.checking)
      Button(model.checking ? "Cancel" : "Call") {
        if model.checking { model.cancel() } else { model.check() }
      }
      if !short { Button("Refresh", action: model.refreshAddresses) }
    }.textFieldStyle(.plain).buttonStyle(RetroButtonStyle()).onSubmit { model.check() }
  }
}
