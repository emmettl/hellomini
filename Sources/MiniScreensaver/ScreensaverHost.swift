import AppKit
import MiniCore
import MiniUI
import SwiftUI

/// Covers only the desktop's screen while this app is active. Does not inhibit macOS sleep or lock.
public struct ScreensaverHost<Content: View>: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.miniDisplay) private var display
  private let settings: ScreensaverSettings
  private let playfulness: PlayfulnessSettings
  private let definitions: [MiniScreensaverDefinition]
  private let theme: MiniThemeDefinition
  private let displaySize: CGSize?
  private let content: () -> Content

  public init(
    settings: ScreensaverSettings, playfulness: PlayfulnessSettings,
    definitions: [MiniScreensaverDefinition], theme: MiniThemeDefinition,
    displaySize: CGSize? = nil,
    @ViewBuilder content: @escaping () -> Content
  ) {
    precondition(settings.savers == definitions.map(\.metadata))
    self.settings = settings
    self.playfulness = playfulness
    self.definitions = definitions
    self.theme = theme
    self.displaySize = displaySize
    self.content = content
  }
  public var body: some View {
    content()
      .environment(\.miniDesktopSuspended, settings.isPresenting)
      .background {
        ScreensaverProbe(
          settings: settings, definitions: definitions, theme: theme, displaySize: displaySize,
          displayScale: display.scale,
          allowed: playfulness.enabled, reduceMotion: reduceMotion,
          previewRevision: settings.previewRevision, idleMinutes: settings.idleMinutes)
      }
  }
}

private struct ScreensaverProbe: NSViewRepresentable {
  let settings: ScreensaverSettings
  let definitions: [MiniScreensaverDefinition]
  let theme: MiniThemeDefinition
  let displaySize: CGSize?
  let displayScale: CGFloat
  let allowed: Bool
  let reduceMotion: Bool
  let previewRevision: Int
  let idleMinutes: Int

  func makeCoordinator() -> Coordinator { Coordinator(configuration: self) }
  func makeNSView(context: Context) -> NSView {
    let view = ProbeView()
    context.coordinator.install(view: view)
    return view
  }
  func updateNSView(_ view: NSView, context: Context) {
    let coordinator = context.coordinator
    let old = coordinator.configuration
    coordinator.configuration = self
    if old.idleMinutes != idleMinutes || old.allowed != allowed || old.reduceMotion != reduceMotion
    {
      coordinator.reset()
    }
    // Defer changes to observable presentation state until after this SwiftUI update.
    if !allowed || old.theme.id != theme.id || old.reduceMotion != reduceMotion
      || old.displaySize != displaySize || old.displayScale != displayScale
    {
      Task { @MainActor [weak coordinator] in coordinator?.close() }
    }
    if previewRevision != coordinator.previewRevision {
      coordinator.previewRevision = previewRevision
      let id = settings.previewID
      Task { @MainActor [weak coordinator] in coordinator?.show(id: id) }
    }
  }
  static func dismantleNSView(_ view: NSView, coordinator: Coordinator) { coordinator.stop() }

  private final class ProbeView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
  }

  @MainActor final class Coordinator: NSObject, NSWindowDelegate {
    var configuration: ScreensaverProbe
    var previewRevision: Int
    private weak var probe: NSView?
    private weak var previousWindow: NSWindow?
    private var window: SaverWindow?
    private var definition: MiniScreensaverDefinition?
    private var monitor: Any?
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var clock = ScreensaverIdleClock()
    private weak var mouseWindow: NSWindow?
    private var previousMouseEvents = false
    private var wakingKey: UInt16?

    init(configuration: ScreensaverProbe) {
      self.configuration = configuration
      previewRevision = configuration.previewRevision
    }
    func reset() { clock.reset(now: ProcessInfo.processInfo.systemUptime) }
    private var eligible: Bool {
      guard let desktop = probe?.window else { return false }
      return NSApp.isActive && desktop.isKeyWindow && desktop.isVisible
        && desktop.occlusionState.contains(.visible) && !desktop.isMiniaturized
        && !desktop.inLiveResize && desktop.attachedSheet == nil && NSApp.modalWindow == nil
        && NSEvent.pressedMouseButtons == 0
    }
    func install(view: NSView) {
      probe = view
      reset()
      monitor = NSEvent.addLocalMonitorForEvents(
        matching: [
          .keyDown, .keyUp, .flagsChanged, .mouseMoved, .leftMouseDown, .leftMouseUp,
          .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp, .leftMouseDragged,
          .rightMouseDragged, .otherMouseDragged, .scrollWheel, .magnify, .rotate, .swipe,
        ]
      ) { [weak self] event in
        let consumed = MainActor.assumeIsolated { self?.consume(event) == true }
        return consumed ? nil : event
      }
      timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
        MainActor.assumeIsolated { self?.tick() }
      }
      observe(NSApplication.didResignActiveNotification, center: .default)
      observe(NSApplication.didChangeScreenParametersNotification, center: .default)
      observe(NSWorkspace.willSleepNotification, center: NSWorkspace.shared.notificationCenter)
      observe(
        NSWorkspace.screensDidSleepNotification, center: NSWorkspace.shared.notificationCenter)
    }
    private func consume(_ event: NSEvent) -> Bool {
      reset()
      if let key = wakingKey,
        event.type == .keyUp || (event.type == .keyDown && event.isARepeat), event.keyCode == key
      {
        if event.type == .keyUp { wakingKey = nil }
        return true
      }
      if event.type == .keyDown { wakingKey = nil }
      guard let window, event.window === window else { return false }
      switch event.type {
      case .keyDown:
        wakingKey = event.keyCode
      case .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel,
        .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .magnify, .rotate, .swipe:
        break
      case .mouseMoved:
        guard abs(event.deltaX) + abs(event.deltaY) > 0 else { return false }
      default: return false
      }
      close()
      return true
    }
    private func observe(_ name: Notification.Name, center: NotificationCenter) {
      let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.close() }
      }
      observers.append((center, observer))
    }
    private func tick() {
      if mouseWindow == nil, let desktop = probe?.window {
        mouseWindow = desktop
        previousMouseEvents = desktop.acceptsMouseMovedEvents
        desktop.acceptsMouseMovedEvents = true
      }
      let config = configuration
      if clock.tick(
        now: ProcessInfo.processInfo.systemUptime, delay: Double(config.idleMinutes * 60),
        eligible: eligible && config.allowed && !config.reduceMotion && window == nil
      ) {
        show(id: config.settings.selectedID)
      }
    }
    func show(id: String?) {
      guard window == nil, configuration.allowed, eligible,
        let definition = configuration.definitions.first(where: { $0.metadata.id == id }),
        let desktop = probe?.window, let screen = desktop.screen
      else { return }
      previousWindow = desktop
      self.definition = definition
      let window = SaverWindow(
        contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
      window.isReleasedWhenClosed = false
      window.delegate = self
      window.title = "\(definition.metadata.name) screensaver"
      window.acceptsMouseMovedEvents = true
      window.collectionBehavior = [.fullScreenAuxiliary]
      window.dismiss = { [weak self] in self?.close() }
      let theme = configuration.theme
      let scale = configuration.displayScale
      let logicalSize =
        configuration.displaySize
        ?? CGSize(
          width: screen.frame.width / scale, height: screen.frame.height / scale)
      window.contentView = NSHostingView(
        rootView: definition.content()
          .frame(width: logicalSize.width, height: logicalSize.height)
          .background(theme.paper)
          .overlay(alignment: .bottom) {
            Text("Move the mouse or press any key to return")
              .font(theme.typography.small).padding(8).background(theme.paper).padding(16)
              .allowsHitTesting(false)
          }
          .environment(\.miniDisplay, MiniDisplayContext(scale: scale, logicalSize: logicalSize))
          .scaleEffect(scale)
          .frame(width: logicalSize.width * scale, height: logicalSize.height * scale)
          .miniScreenEdges()
          .environment(\.miniTheme, theme)
          .environment(\.colorScheme, theme.colorScheme)
          .foregroundStyle(theme.ink)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.black))
      self.window = window
      definition.presenting(true)
      configuration.settings.setPresenting(true)
      desktop.addChildWindow(window, ordered: .above)
      window.makeKeyAndOrderFront(nil)
      reset()
    }
    func windowDidResignKey(_ notification: Notification) { close() }
    func close() {
      reset()
      guard let window else { return }
      self.window = nil
      window.delegate = nil
      window.parent?.removeChildWindow(window)
      window.contentView = nil
      window.close()
      definition?.presenting(false)
      definition = nil
      configuration.settings.setPresenting(false)
      // Native dialogs and other app windows keep focus if they caused dismissal.
      if NSApp.isActive && (NSApp.keyWindow == nil || NSApp.keyWindow === window) {
        previousWindow?.makeKeyAndOrderFront(nil)
      }
    }
    func stop() {
      timer?.invalidate()
      timer = nil
      if let monitor { NSEvent.removeMonitor(monitor) }
      monitor = nil
      for (center, observer) in observers { center.removeObserver(observer) }
      observers.removeAll()
      mouseWindow?.acceptsMouseMovedEvents = previousMouseEvents
      close()
    }
  }
}

/// Input belongs to this window, so the waking click/key never reaches desktop commands or editors.
private final class SaverWindow: NSWindow {
  var dismiss: (() -> Void)?
  override var canBecomeKey: Bool { true }
  override func sendEvent(_ event: NSEvent) {
    switch event.type {
    case .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel,
      .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .magnify, .rotate, .swipe:
      dismiss?()
    case .mouseMoved:
      if abs(event.deltaX) + abs(event.deltaY) > 0 { dismiss?() }
    default: super.sendEvent(event)
    }
  }
}
