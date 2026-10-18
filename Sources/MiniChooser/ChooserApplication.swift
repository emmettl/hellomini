import AppKit
import MiniCore
import MiniUI
import Observation
import SwiftUI

enum ServiceKind: String, CaseIterable, Codable {
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

struct SavedService: Identifiable, Codable, Equatable {
  let id: UUID
  let host: String
  let port: Int?
  let kind: ServiceKind
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
  var manualPort = ""
  private(set) var saved: [SavedService] = []
  @ObservationIgnored private let defaults: UserDefaults
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    super.init()
    if let data = defaults.data(forKey: "chooser.savedServices"),
      let decoded = try? JSONDecoder().decode([SavedService].self, from: data)
    {
      saved = Array(
        decoded.filter {
          Self.connectionURL(host: $0.host, port: $0.port, kind: $0.kind) != nil
        }.prefix(40))
    }
  }
  func use(_ destination: SavedService) {
    stop()
    services = []
    kind = destination.kind
    selected = nil
    manualHost = destination.host
    manualPort = destination.port.map(String.init) ?? ""
    message = "Saved address selected. Connect opens it in a macOS application."
  }
  func forget(_ id: UUID) {
    saved.removeAll { $0.id == id }
    persist()
    message = "Saved service forgotten."
  }
  private func persist() {
    if let data = try? JSONEncoder().encode(saved) {
      defaults.set(data, forKey: "chooser.savedServices")
    }
  }
  private func destination() -> (String, Int?)? {
    let service = services.first { $0.name == selected }
    let manual = !manualHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let host =
      manual ? manualHost.trimmingCharacters(in: .whitespacesAndNewlines) : service?.hostName ?? ""
    let portText = manualPort.trimmingCharacters(in: .whitespacesAndNewlines)
    let port = manual ? (portText.isEmpty ? nil : Int(portText)) : service?.port
    guard !manual || portText.isEmpty || port != nil,
      Self.connectionURL(host: host, port: port, kind: kind) != nil
    else {
      message = "Choose a resolved service or enter a hostname/IP and a port from 1 to 65535."
      return nil
    }
    return (host, port)
  }
  func save() {
    guard let (host, port) = destination() else { return }
    guard
      !saved.contains(where: {
        $0.host.lowercased() == host.lowercased() && $0.port == port && $0.kind == kind
      })
    else {
      message = "That service is already saved."
      return
    }
    guard saved.count < 40 else {
      message = "Forty services saved. Forget one before adding another."
      return
    }
    saved.append(SavedService(id: UUID(), host: host, port: port, kind: kind))
    persist()
    message = "Saved \(host) for \(kind.rawValue)."
  }
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
    if browsing { message = "Discovery stopped. Saved and resolved addresses remain available." }
    browsing = false
  }
  func netServiceBrowser(
    _ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool
  ) {
    guard browser === self.browser else { return }
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
    guard browser === self.browser else { return }
    services.removeAll { $0.name == service.name }
    if selected == service.name { selected = nil }
    message = "\(services.count) services found."
  }
  func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
    guard browser === self.browser else { return }
    stop()
    message =
      "Discovery could not start. Check Local Network access for Hello Mini in macOS Settings."
  }
  func netServiceDidResolveAddress(_ sender: NetService) {
    guard services.contains(where: { $0 === sender }) else { return }
    // Reassign so a newly resolved address becomes visible through Observation.
    services = Array(services)
  }
  func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
    guard services.contains(where: { $0 === sender }) else { return }
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
    guard let (host, port) = destination(),
      let url = Self.connectionURL(host: host, port: port, kind: kind)
    else { return }
    message = "Opening \(kind.rawValue) at \(host) in macOS…"
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
  public let minimumSize = CGSize(width: 420, height: 250)
  private let model = ChooserModel()
  public init() {}
  public func content() -> AnyView { AnyView(ChooserView(model: model)) }
  public var menus: [RetroMenu] {
    [
      RetroMenu(
        id: "connections", title: "Connections",
        items: [
          RetroMenuItem(
            id: "save", title: "Save Service", shortcut: RetroShortcut(key: "s", label: "⌘S")
          ) { self.model.save() },
          RetroMenuItem(id: "connect", title: "Connect") { self.model.connect() },
          RetroMenuItem(id: "browse", title: model.browsing ? "Stop Browsing" : "Browse") {
            if self.model.browsing { self.model.stop() } else { self.model.start() }
          },
        ])
    ]
  }
}

struct ChooserView: View {
  @Environment(\.miniTheme) private var theme
  @Bindable var model: ChooserModel
  @State private var height: CGFloat = 450
  private var roomy: Bool { height >= 340 }
  private static let privacy =
    "Bonjour advertisements only; no port scanning. Connections open in the appropriate macOS app."
  var body: some View {
    VStack(alignment: .leading, spacing: roomy ? 14 : 8) {
      ViewThatFits(in: .horizontal) {
        controls(compact: false)
        controls(compact: true)
      }.buttonStyle(RetroButtonStyle())

      if roomy {
        Text("A beige computer surveys the network.").font(theme.typography.title)
      }
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          if model.services.isEmpty && model.saved.isEmpty {
            MiniEmptyState(
              model.browsing ? "Listening to the neighborhood…" : "Who else is out there?",
              message: model.browsing
                ? "Only services advertising themselves appear here. You can also enter a known hostname below."
                : "Choose a service and Browse, or connect to a known hostname below.")
          }
          if !model.saved.isEmpty {
            Text("Saved services").font(theme.typography.title)
            ForEach(model.saved) { destination in
              HStack {
                Button {
                  model.use(destination)
                } label: {
                  Text(
                    "\(destination.kind.rawValue) · \(destination.host)\(destination.port.map { ":\($0)" } ?? "")"
                  )
                  .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(RetroButtonStyle())
                Button("Forget") { model.forget(destination.id) }
                  .accessibilityLabel("Forget \(destination.kind.rawValue) at \(destination.host)")
              }
            }
            Text("Discovered services").font(theme.typography.title)
          }
          ForEach(model.services, id: \.name) { service in
            Button {
              model.selected = service.name
              model.manualHost = ""
              model.manualPort = ""
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
              .accessibilityAddTraits(model.selected == service.name ? .isSelected : [])
          }
        }
      }
      HStack {
        TextField("Or enter a hostname / IP address", text: $model.manualHost).accessibilityLabel(
          "Manual connection hostname"
        )
        .onSubmit(model.connect)
        TextField("Port", text: $model.manualPort).frame(width: 52)
          .accessibilityLabel("Connection port, optional")
        Button("Save", action: model.save).buttonStyle(RetroButtonStyle()).miniControlBounds(
          "chooser.save")
        Button("Connect", action: model.connect).buttonStyle(RetroButtonStyle()).miniControlBounds(
          "chooser.connect")
      }
      Text(model.message).font(theme.typography.small).lineLimit(roomy ? nil : 2)
        .miniHelp(Self.privacy)
      if roomy { Text(Self.privacy).font(theme.typography.small) }
    }.padding(roomy ? 16 : 10).onDisappear { model.stop() }
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        height = $0
      }
  }

  private func controls(compact: Bool) -> some View {
    HStack {
      if compact {
        Picker("Service", selection: serviceSelection) { serviceOptions }.labelsHidden()
      } else {
        Picker("Service", selection: serviceSelection) { serviceOptions }
      }
      Button(
        model.browsing ? (compact ? "Again" : "Browse again") : "Browse", action: model.start
      )
      .accessibilityLabel(model.browsing ? "Browse again" : "Browse")
      if model.browsing { Button("Stop", action: model.stop) }
    }
  }

  private var serviceSelection: Binding<ServiceKind> {
    Binding(
      get: { model.kind },
      set: {
        model.stop()
        model.services = []
        model.selected = nil
        model.kind = $0
        model.message = "Choose Browse to discover \($0.rawValue) services."
      })
  }

  private var serviceOptions: some View {
    ForEach(ServiceKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
  }
}
