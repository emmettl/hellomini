import AppKit
import MiniCore
import MiniUI
import Observation
import SwiftUI

enum ServiceKind: String, CaseIterable {
  case ssh = "SSH"
  case screen = "Screen Sharing"
  case http = "Web"
  case https = "Secure Web"
  var type: String {
    switch self {
    case .ssh: "_ssh._tcp."
    case .screen: "_rfb._tcp."
    case .http: "_http._tcp."
    case .https: "_https._tcp."
    }
  }
  var scheme: String {
    switch self {
    case .ssh: "ssh"
    case .screen: "vnc"
    case .http: "http"
    case .https: "https"
    }
  }
}

@MainActor @Observable
final class ChooserModel: NSObject, @preconcurrency NetServiceBrowserDelegate,
  @preconcurrency NetServiceDelegate
{
  var kind = ServiceKind.ssh
  var services: [NetService] = []
  var selected: String?
  var browsing = false
  var message = "Choose a service and browse the local network."
  var manualHost = ""
  @ObservationIgnored private var browser: NetServiceBrowser?
  func start() {
    stop()
    services = []
    selected = nil
    let browser = NetServiceBrowser()
    self.browser = browser
    browser.delegate = self
    browsing = true
    message = "Listening for \(kind.rawValue) advertisements…"
    browser.searchForServices(ofType: kind.type, inDomain: "local.")
  }
  func stop() {
    browser?.stop()
    browser?.delegate = nil
    browser = nil
    for service in services {
      service.stop()
      service.delegate = nil
    }
    browsing = false
  }
  func netServiceBrowser(
    _ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool
  ) {
    guard !services.contains(where: { $0.name == service.name }) else { return }
    services.append(service)
    services.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    service.delegate = self
    service.resolve(withTimeout: 8)
    message = "\(services.count) services found."
  }
  func netServiceBrowser(
    _ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool
  ) {
    services.removeAll { $0.name == service.name }
    if selected == service.name { selected = nil }
    message = "\(services.count) services found."
  }
  func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
    message =
      "Discovery could not start. Check Local Network access for Hello Mini in macOS Settings."
    stop()
  }
  func netServiceDidResolveAddress(_ sender: NetService) {
    // Reassign so a newly resolved address becomes visible through Observation.
    services = Array(services)
  }
  func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
    message = "Could not resolve \(sender.name). It may have gone away; browse again."
  }
  static func connectionURL(host: String, port: Int?, kind: ServiceKind) -> URL? {
    let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !host.isEmpty,
      host.unicodeScalars.allSatisfy({
        CharacterSet(
          charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-:"
        ).contains($0)
      }),
      port == nil || (1...65535).contains(port!)
    else { return nil }
    var url = URLComponents()
    url.scheme = kind.scheme
    url.host = host
    url.port = port
    return url.url
  }
  func connect() {
    let service = services.first { $0.name == selected }
    let host = manualHost.isEmpty ? service?.hostName ?? "" : manualHost
    let port = manualHost.isEmpty ? service?.port : nil
    guard let url = Self.connectionURL(host: host, port: port, kind: kind) else {
      message = "Choose a resolved service or enter a hostname/IP address without a scheme or path."
      return
    }
    if !NSWorkspace.shared.open(url) {
      message = "No macOS application could open \(kind.scheme) connections."
    }
  }
}

@MainActor public final class ChooserApplication: MiniApplication {
  public let id = "chooser"
  public let name = "Chooser"
  public let icon = MiniApplicationIcon.chooser
  public let defaultSize = CGSize(width: 680, height: 450)
  public let minimumSize = CGSize(width: 570, height: 370)
  private let model = ChooserModel()
  public init() {}
  public func content() -> AnyView { AnyView(ChooserView(model: model)) }
}

private struct ChooserView: View {
  @Environment(\.miniTheme) private var theme
  @Bindable var model: ChooserModel
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Picker("Service", selection: $model.kind) {
          ForEach(ServiceKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        Button(model.browsing ? "Browse again" : "Browse", action: model.start)
        if model.browsing { Button("Stop", action: model.stop) }
      }.buttonStyle(RetroButtonStyle())
        .onChange(of: model.kind) { _, _ in
          model.stop()
          model.services = []
          model.selected = nil
          model.manualHost = ""
        }
      Text("A beige computer surveys the network.").font(theme.typography.title)
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          if model.services.isEmpty {
            MiniEmptyState(
              model.browsing ? "Listening to the neighborhood…" : "Who else is out there?",
              message: model.browsing
                ? "Only services advertising themselves appear here. You can also enter a known hostname below."
                : "Choose a service and Browse, or connect to a known hostname below.")
          }
          ForEach(model.services, id: \.name) { service in
            Button {
              model.selected = service.name
              model.manualHost = ""
            } label: {
              HStack {
                PixelIcon(symbol: .computer)
                VStack(alignment: .leading) {
                  Text(service.name)
                  Text(service.hostName.map { "\($0):\(service.port)" } ?? "Resolving…").font(
                    theme.typography.small)
                }
                Spacer()
                if model.selected == service.name { Text("✓") }
              }.padding(8).frame(maxWidth: .infinity).contentShape(Rectangle())
            }.buttonStyle(.plain)
          }
        }
      }
      HStack {
        TextField("Or enter a hostname / IP address", text: $model.manualHost).accessibilityLabel(
          "Manual connection hostname"
        )
        .onSubmit(model.connect)
        Button("Connect", action: model.connect).buttonStyle(RetroButtonStyle())
      }
      Text(model.message).font(theme.typography.small)
      Text(
        "Bonjour advertisements only; no port scanning. Connections open in the appropriate macOS app."
      )
      .font(theme.typography.small)
    }.padding(16).onDisappear { model.stop() }
  }
}
