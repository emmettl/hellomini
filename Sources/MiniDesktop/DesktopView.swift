import AppKit
import MiniCore
import MiniUI
import Observation
import SwiftUI

@MainActor @Observable
final class DesktopModel {
  let applications: [any MiniApplication]
  private(set) var openIDs: [String]
  private(set) var minimisedIDs: Set<String>
  private(set) var zoomedIDs: Set<String>
  private var windows: [String: WindowPlacement]
  @ObservationIgnored private let store: DesktopSessionStore
  var visibleIDs: [String] { openIDs.filter { !minimisedIDs.contains($0) } }
  var active: (any MiniApplication)? { applications.first { $0.id == visibleIDs.last } }

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
    let restoredIDs = (saved?.openIDs ?? initiallyOpen).filter {
      knownIDs.contains($0) && seen.insert($0).inserted
    }
    openIDs = restoredIDs
    minimisedIDs = Set(saved?.minimisedIDs ?? []).intersection(restoredIDs)
    zoomedIDs = Set(saved?.zoomedIDs ?? []).intersection(restoredIDs)
  }

  func launch(_ app: any MiniApplication) {
    guard active?.id != app.id else { return }
    NSApp?.keyWindow?.makeFirstResponder(nil)
    minimisedIDs.remove(app.id)
    openIDs = openIDs.filter { $0 != app.id } + [app.id]
    persist()
  }

  func close(_ app: any MiniApplication) {
    if active?.id == app.id { NSApp?.keyWindow?.makeFirstResponder(nil) }
    openIDs.removeAll { $0 == app.id }
    minimisedIDs.remove(app.id)
    zoomedIDs.remove(app.id)
    persist()
  }

  func minimise(_ app: any MiniApplication) {
    guard openIDs.contains(app.id) else { return }
    if active?.id == app.id { NSApp?.keyWindow?.makeFirstResponder(nil) }
    minimisedIDs.insert(app.id)
    persist()
  }

  func toggleZoom(_ app: any MiniApplication) {
    guard openIDs.contains(app.id) else { return }
    launch(app)
    if !zoomedIDs.insert(app.id).inserted { zoomedIDs.remove(app.id) }
    persist()
  }

  func displayedPlacement(
    for app: any MiniApplication, desktop: CGSize, menuBarHeight: CGFloat
  ) -> WindowPlacement {
    guard zoomedIDs.contains(app.id) else { return placement(for: app) }
    return WindowPlacement(
      origin: CGPoint(x: 8, y: menuBarHeight + 10),
      size: CGSize(
        width: max(1, desktop.width - 16), height: max(1, desktop.height - menuBarHeight - 18)))
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
    zoomedIDs.remove(app.id)
    persist()
  }

  func resetLayout() {
    windows = [:]
    zoomedIDs = []
    persist()
  }

  private func persist() {
    store.save(
      DesktopSession(
        openIDs: openIDs, windows: windows,
        minimisedIDs: minimisedIDs.sorted(), zoomedIDs: zoomedIDs.sorted()))
  }
}

public struct DesktopView: View {
  @Environment(\.miniDesktopSuspended) private var suspended
  @State private var model: DesktopModel
  @State private var dockFocusRequest = 0
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
      let windowArea = DesktopDockLayout.windowArea(
        desktop: geometry.size, hasDock: theme.dock != nil)
      ZStack(alignment: .topLeading) {
        ThemeSurfaceView(theme.desktop)
        if theme.dock == nil {
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
                    PixelIcon(symbol: app.icon.desktopSymbol, scale: 3)
                    Text(app.name).font(theme.typography.small)
                      .foregroundStyle(theme.desktopInk ?? theme.ink)
                      .shadow(color: theme.desktopTextShadow, radius: 1, x: 0, y: 1)
                      .padding(.horizontal, 4).padding(.vertical, 2)
                      .background {
                        ThemeSurfaceView(theme.desktopLabelSurface ?? .solid(theme.paper))
                      }
                  }
                  .frame(width: 134)
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                  "\(model.minimisedIDs.contains(app.id) ? "Restore" : "Launch") \(app.name)"
                )
                .help(
                  model.minimisedIDs.contains(app.id)
                    ? "Restore minimised \(app.name) window" : "Open \(app.name)")
              }
            }
          }
          .scrollIndicators(.hidden)
          .frame(width: 134, height: max(0, geometry.size.height - 72), alignment: .top)
          .offset(x: geometry.size.width - 146, y: 60)
        }

        VStack(alignment: .leading, spacing: 6) {
          Text("hello, again.").font(theme.typography.display(28))
          Text("A little desktop. A lot of possibility.").font(theme.typography.small)
        }
        .foregroundStyle(theme.desktopInk ?? theme.ink)
        .shadow(color: theme.desktopTextShadow, radius: 1, x: 0, y: 1)
        .padding(10)
        .background { ThemeSurfaceView(theme.desktopLabelSurface ?? .solid(theme.paper)) }
        .offset(x: 28, y: windowArea.height - 90)

        ForEach(model.applications.filter { model.openIDs.contains($0.id) }, id: \.id) { app in
          RetroWindow(
            title: app.title,
            minimumSize: app.minimumSize,
            desktopSize: windowArea,
            placement: Binding(
              get: {
                model.displayedPlacement(
                  for: app, desktop: windowArea, menuBarHeight: theme.menuBarHeight)
              }, set: { model.place(app, at: $0) }),
            active: model.active?.id == app.id,
            activate: {
              if model.visibleIDs.contains(app.id) { model.launch(app) }
            },
            close: { model.close(app) },
            minimise: { model.minimise(app) },
            zoom: { model.toggleZoom(app) },
            zoomed: model.zoomedIDs.contains(app.id)
          ) {
            app.content()
              .environment(\.miniWindowActive, !suspended && model.active?.id == app.id)
              .environment(\.miniWindowVisible, isVisible(app, desktop: windowArea))
          }
          .opacity(model.minimisedIDs.contains(app.id) ? 0 : 1)
          .allowsHitTesting(!model.minimisedIDs.contains(app.id))
          .accessibilityHidden(model.minimisedIDs.contains(app.id))
          .zIndex(Double((model.openIDs.firstIndex(of: app.id) ?? 0) + 1))
        }
        if let style = theme.dock {
          DesktopDock(
            model: model, desktopWidth: geometry.size.width, style: style,
            focusRequest: dockFocusRequest
          )
          .frame(
            width: geometry.size.width, height: DesktopDockLayout.reservedHeight, alignment: .bottom
          )
          .offset(y: windowArea.height)
          .zIndex(Double(model.applications.count + 1))
        }
        RetroMenuBar(menus: menus, applicationName: model.active?.name ?? "Hello Mini")
          .zIndex(Double(model.applications.count + 2))
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
    guard !suspended, !model.minimisedIDs.contains(app.id) else { return false }
    func rectangle(_ app: any MiniApplication) -> CGRect {
      let placement = model.displayedPlacement(
        for: app, desktop: desktop, menuBarHeight: theme.menuBarHeight)
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
    guard let index = model.visibleIDs.firstIndex(of: app.id) else { return false }
    let covers = model.visibleIDs.dropFirst(index + 1).compactMap { id in
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
    if theme.dock != nil, let index = appMenus.firstIndex(where: { $0.id == "view" }) {
      appMenus[index].items.append(
        RetroMenuItem(id: "focus-dock", title: "Focus Dock") {
          dockFocusRequest += 1
        })
    }
    result += appMenus
    result.append(
      RetroMenu(
        id: "window", title: "Window", width: 280,
        items: [
          RetroMenuItem(
            id: "minimise", title: "Minimise", shortcut: RetroShortcut(key: "m", label: "⌘M"),
            enabled: model.active != nil
          ) { if let app = model.active { model.minimise(app) } },
          RetroMenuItem(
            id: "zoom",
            title: model.active.map { model.zoomedIDs.contains($0.id) } == true
              ? "Restore Size" : "Zoom",
            enabled: model.active != nil
          ) { if let app = model.active { model.toggleZoom(app) } },
          .separator("window-actions-divider"),
        ]
          + model.applications.map { app in
            RetroMenuItem(
              id: "window-\(app.id)",
              title: app.name + (model.minimisedIDs.contains(app.id) ? " (minimised)" : ""),
              checked: model.active?.id == app.id
            ) { model.launch(app) }
          } + [
            .separator("window-divider"),
            RetroMenuItem(id: "reset", title: "Reset Window Layout", action: model.resetLayout),
          ]
      ))
    return result
  }

}
