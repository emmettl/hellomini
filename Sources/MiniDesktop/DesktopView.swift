import AppKit
import MiniCore
import MiniUI
import Observation
import SwiftUI

@MainActor @Observable
final class DesktopModel {
  let applications: [any MiniApplication]
  private(set) var openIDs: [String]
  private var windows: [String: WindowPlacement]
  @ObservationIgnored private let store: DesktopSessionStore
  var active: (any MiniApplication)? { applications.first { $0.id == openIDs.last } }

  init(
    applications: [any MiniApplication], initiallyOpen: [String], defaults: UserDefaults = .standard
  ) {
    precondition(
      Set(applications.map(\.id)).count == applications.count, "Application IDs must be unique")
    self.applications = applications
    store = DesktopSessionStore(defaults: defaults)
    let saved = store.load()
    windows = saved?.windows ?? [:]
    let knownIDs = Set(applications.map(\.id))
    var seen = Set<String>()
    openIDs = (saved?.openIDs ?? initiallyOpen).filter {
      knownIDs.contains($0) && seen.insert($0).inserted
    }
  }

  func launch(_ app: any MiniApplication) {
    guard active?.id != app.id else { return }
    NSApp?.keyWindow?.makeFirstResponder(nil)
    openIDs = openIDs.filter { $0 != app.id } + [app.id]
    persist()
  }

  func close(_ app: any MiniApplication) {
    if active?.id == app.id { NSApp?.keyWindow?.makeFirstResponder(nil) }
    openIDs.removeAll { $0 == app.id }
    persist()
  }

  func placement(for app: any MiniApplication) -> WindowPlacement {
    if let saved = windows[app.id] { return saved }
    let index = applications.firstIndex { $0.id == app.id } ?? 0
    let origin =
      app.defaultSize.width < 450
      ? CGPoint(x: 870, y: 400) : CGPoint(x: 48 + index * 24, y: 72 + index * 20)
    return WindowPlacement(origin: origin, size: app.defaultSize)
  }

  func place(_ app: any MiniApplication, at placement: WindowPlacement) {
    guard placement.isValid else { return }
    windows[app.id] = placement
    persist()
  }

  func resetLayout() {
    windows = [:]
    persist()
  }

  private func persist() {
    store.save(DesktopSession(openIDs: openIDs, windows: windows))
  }
}

public struct DesktopView: View {
  @Environment(\.miniDesktopSuspended) private var suspended
  @State private var model: DesktopModel
  private let settings: AppearanceSettings
  private let themes: MiniThemeRegistry
  private let picture: DesktopPicture?
  private var theme: MiniThemeDefinition { themes.definition(for: settings.theme.id)! }

  public init(
    applications: [any MiniApplication], initiallyOpen: [String] = [], settings: AppearanceSettings,
    themes: MiniThemeRegistry = .builtIns, defaults: UserDefaults = .standard,
    picture: DesktopPicture? = nil
  ) {
    precondition(
      settings.availableThemes == themes.metadata, "Settings and desktop must share a theme catalog"
    )
    self.settings = settings
    self.themes = themes
    self.picture = picture
    _model = State(
      initialValue: DesktopModel(
        applications: applications, initiallyOpen: initiallyOpen, defaults: defaults))
  }

  public var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        ThemeSurfaceView(theme.desktop)
        ScrollView(.vertical) {
          VStack(
            spacing: min(
              26,
              max(
                8,
                (geometry.size.height - 80 - CGFloat(model.applications.count) * 73)
                  / CGFloat(max(1, model.applications.count - 1))))
          ) {
            ForEach(model.applications, id: \.id) { app in
              Button {
                model.launch(app)
              } label: {
                VStack(spacing: 8) {
                  PixelIcon(symbol: symbol(for: app.icon), scale: 3)
                  Text(app.name).font(theme.typography.small)
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background { Rectangle().fill(theme.paper) }
                }
                .frame(width: 134)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityLabel("Launch \(app.name)")
            }
          }
        }
        .scrollIndicators(.hidden)
        .frame(width: 134, height: max(0, geometry.size.height - 72), alignment: .top)
        .offset(x: geometry.size.width - 146, y: 60)

        VStack(alignment: .leading, spacing: 6) {
          Text("hello, again.").font(theme.typography.display(28))
          Text("A little desktop. A lot of possibility.").font(theme.typography.small)
        }
        .padding(10)
        .background(theme.paper)
        .offset(x: 28, y: geometry.size.height - 90)

        ForEach(model.applications.filter { model.openIDs.contains($0.id) }, id: \.id) { app in
          RetroWindow(
            title: app.title,
            minimumSize: app.minimumSize,
            desktopSize: geometry.size,
            placement: Binding(
              get: { model.placement(for: app) }, set: { model.place(app, at: $0) }),
            active: model.active?.id == app.id,
            activate: { if model.openIDs.contains(app.id) { model.launch(app) } },
            close: { model.close(app) }
          ) {
            app.content()
              .environment(\.miniWindowActive, !suspended && model.active?.id == app.id)
              .environment(\.miniWindowVisible, isVisible(app, desktop: geometry.size))
          }
          .zIndex(Double((model.openIDs.firstIndex(of: app.id) ?? 0) + 1))
        }
        RetroMenuBar(menus: menus, applicationName: model.active?.name ?? "Hello Mini")
          .zIndex(Double(model.applications.count + 1))
      }
      .coordinateSpace(name: DesktopCoordinateSpace.windows)
      .foregroundStyle(theme.ink)
      .font(theme.typography.body)
      .background(DesktopWindowConfiguration())
      .background { if let picture { DesktopPictureCapture(picture: picture) } }
    }
    .ignoresSafeArea()
    .environment(\.miniTheme, theme)
    .tint(theme.accent)
    .preferredColorScheme(theme.colorScheme)
  }

  private func isVisible(_ app: any MiniApplication, desktop: CGSize) -> Bool {
    guard !suspended else { return false }
    func rectangle(_ app: any MiniApplication) -> CGRect {
      let placement = model.placement(for: app)
      let size = WindowResize.constrain(
        placement.size, minimum: app.minimumSize,
        maximum: CGSize(
          width: desktop.width - 16, height: desktop.height - theme.menuBarHeight - 18))
      let origin = WindowBounds(
        desktopSize: desktop, windowSize: size, menuBarHeight: theme.menuBarHeight
      )
      .constrain(placement.origin)
      return CGRect(origin: origin, size: size)
    }
    guard let index = model.openIDs.firstIndex(of: app.id) else { return false }
    let covers = model.openIDs.dropFirst(index + 1).compactMap { id in
      model.applications.first { $0.id == id }.map(rectangle)
    }
    return WindowVisibility.isVisible(rectangle(app), behind: covers)
  }

  private var menus: [RetroMenu] {
    var result = [
      RetroMenu(
        id: "mini", title: "Hello Mini", width: 260,
        items:
          model.applications.map { app in
            RetroMenuItem(
              id: "launch-\(app.id)", title: app.name, checked: model.active?.id == app.id
            ) { model.launch(app) }
          } + [
            .separator("mini-divider"),
            RetroMenuItem(
              id: "quit", title: "Quit Hello Mini", shortcut: RetroShortcut(key: "q", label: "⌘Q")
            ) { NSApp.terminate(nil) },
          ]
      )
    ]
    var appMenus = model.active?.menus ?? []
    let close = RetroMenuItem(
      id: "close", title: "Close Window", shortcut: RetroShortcut(key: "w", label: "⌘W"),
      enabled: model.active != nil
    ) {
      if let app = model.active { model.close(app) }
    }
    if let index = appMenus.firstIndex(where: { $0.id == "file" }) {
      appMenus[index].items += [.separator("close-divider"), close]
    } else {
      appMenus.insert(RetroMenu(id: "file", title: "File", items: [close]), at: 0)
    }
    let fullScreen = RetroMenuItem(
      id: "fullscreen", title: "Enter / Exit Full Screen",
      shortcut: RetroShortcut(key: "f", modifiers: [.control, .command], label: "⌃⌘F")
    ) { NSApp.keyWindow?.toggleFullScreen(nil) }
    if let index = appMenus.firstIndex(where: { $0.id == "view" }) {
      appMenus[index].items += [.separator("fullscreen-divider"), fullScreen]
    } else {
      appMenus.append(RetroMenu(id: "view", title: "View", width: 330, items: [fullScreen]))
    }
    result += appMenus
    result.append(
      RetroMenu(
        id: "window", title: "Window", width: 280,
        items:
          model.applications.map { app in
            RetroMenuItem(
              id: "window-\(app.id)", title: app.name, checked: model.active?.id == app.id
            ) { model.launch(app) }
          } + [
            .separator("window-divider"),
            RetroMenuItem(id: "reset", title: "Reset Window Layout", action: model.resetLayout),
          ]
      ))
    return result
  }

  private func symbol(for icon: MiniApplicationIcon) -> PixelSymbol {
    switch icon {
    case .folder: .folder
    case .computer: .computer
    case .activity: .activity
    case .clock: .clock
    case .settings: .settings
    case .teapot: .teapot
    case .aquarium: .aquarium
    case .scrapbook: .scrapbook
    case .calculator: .calculator
    case .puzzle: .puzzle
    case .disk: .disk
    case .chooser: .chooser
    case .wastebasket: .wastebasket
    case .printer: .printer
    }
  }
}
