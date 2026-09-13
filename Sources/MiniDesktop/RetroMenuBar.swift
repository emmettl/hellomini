import AppKit
import MiniCore
import MiniUI
import SwiftUI

private struct MenuAnchors: PreferenceKey {
  static let defaultValue: [String: Anchor<CGRect>] = [:]

  static func reduce(
    value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]
  ) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}

struct RetroMenuBar: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.miniDisplay) private var display
  let menus: [RetroMenu]
  let applicationName: String
  let desktopSize: CGSize
  let model: DesktopModel
  let playfulness: PlayfulnessSettings?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var blinkTask: Task<Void, Never>?
  @State private var blinking = false
  private var compact: Bool { desktopSize.width < 800 }
  @State private var openMenuID: String?
  @State private var highlightedID: String?

  private var openMenu: RetroMenu? { menus.first { $0.id == openMenuID } }

  var body: some View {
    ZStack(alignment: .topLeading) {
      if openMenuID != nil {
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture(perform: dismiss)
          .accessibilityLabel("Dismiss menu")
          .accessibilityAddTraits(.isButton)
          .accessibilityAction { dismiss() }
      }
      HStack(spacing: 0) {
        if compact {
          ScrollView(.horizontal) { menuHeadings }
            .scrollIndicators(.hidden)
        } else {
          menuHeadings
          Spacer(minLength: 0)
        }
        DesktopStatusStrip(model: model, playfulness: playfulness)
        TimelineView(.periodic(from: .now, by: 1)) { context in
          Group {
            if compact {
              Text(context.date, format: .dateTime.hour().minute())
            } else {
              Text(context.date, format: .dateTime.weekday(.abbreviated).hour().minute())
            }
          }.font(compact && !display.tinyScreen ? theme.typography.small : theme.typography.body)
            .fixedSize()
        }
        .padding(.horizontal, compact ? 6 : 20)
      }
      .padding(.leading, compact ? 4 : 12)
      .frame(height: theme.menuBarHeight)
      .background { ThemeSurfaceView(theme.menuBar) }
      .overlay(alignment: .bottom) {
        Rectangle().fill(theme.ink).frame(height: theme.menuBarBorderWidth)
      }
    }
    .frame(
      maxWidth: .infinity, maxHeight: openMenuID == nil ? theme.menuBarHeight : .infinity,
      alignment: .topLeading
    )
    .overlayPreferenceValue(MenuAnchors.self) { anchors in
      GeometryReader { geometry in
        if let menu = openMenu, let anchor = anchors[menu.id] {
          menuPanel(menu)
            .offset(
              x: max(2, min(geometry[anchor].minX, geometry.size.width - menu.width - 4)),
              y: theme.menuBarHeight - theme.menuBarBorderWidth
            )
        }
      }
    }
    .background(DesktopMenuEvents(handle: handleKey).allowsHitTesting(false))
    .onDisappear { dismiss() }
    .onChange(of: applicationName) { dismiss() }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification))
    { _ in
      dismiss()
    }
  }

  private var menuHeadings: some View {
    HStack(spacing: 0) {
      ForEach(menus) { menu in
        menuHeading(menu)
        if menu.id == "mini" && !compact {
          Text(applicationName).font(theme.typography.title).padding(.horizontal, 12)
        }
      }
    }
  }

  private func menuHeading(_ menu: RetroMenu) -> some View {
    Button {
      if openMenuID == menu.id { dismiss() } else { open(menu) }
    } label: {
      Group {
        if menu.id == "mini" {
          PixelIcon(symbol: .computer, scale: 1, selected: openMenuID == menu.id)
        } else {
          Text(menu.title).font(
            compact && !display.tinyScreen ? theme.typography.small : theme.typography.title)
        }
      }
      .padding(.horizontal, compact ? 6 : 12)
      .frame(height: theme.menuBarHeight - theme.menuBarBorderWidth)
      .foregroundStyle(openMenuID == menu.id ? theme.selectionInk : theme.ink)
      .background { ThemeSurfaceView(openMenuID == menu.id ? theme.selection : theme.menuBar) }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(menu.title) menu")
    .accessibilityValue(openMenuID == menu.id ? "Open" : "Closed")
    .accessibilityHint(
      menu.id == "mini"
        ? "Option-Command-M opens this menu. Use arrow keys to browse and Escape to dismiss."
        : "Use arrow keys to browse and Escape to dismiss."
    )
    .anchorPreference(key: MenuAnchors.self, value: .bounds) { [menu.id: $0] }
    .onHover { inside in
      if inside && openMenuID != nil && openMenuID != menu.id { open(menu) }
    }
  }

  private func menuPanel(_ menu: RetroMenu) -> some View {
    let contentHeight = menu.items.reduce(CGFloat(8)) { height, item in
      height + (item.isSeparator ? 11 : theme.menuRowHeight)
    }
    return ScrollViewReader { proxy in
      ScrollView(.vertical) {
        VStack(spacing: 0) {
          ForEach(menu.items) { item in
            if item.isSeparator {
              Rectangle().fill(theme.ink)
                .frame(height: 1).padding(.horizontal, 10).padding(.vertical, 5)
            } else {
              menuRow(item).id(item.id)
            }
          }
        }.padding(.vertical, 4)
      }
      .scrollIndicators(.visible)
      .onChange(of: highlightedID) { _, id in if let id { proxy.scrollTo(id) } }
    }
    .frame(
      width: min(menu.width, desktopSize.width - 4),
      height: min(contentHeight, max(1, desktopSize.height - theme.menuBarHeight - 4))
    )
    .themeFrame(theme.menu)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(menu.title) menu items")
  }

  private func menuRow(_ item: RetroMenuItem) -> some View {
    let selected = highlightedID == item.id && item.enabled
    return Button {
      perform(item)
    } label: {
      HStack(spacing: 0) {
        Text(item.checked ? "✓" : " ").frame(width: 26)
        Text(item.title)
        Spacer(minLength: 16)
        Text(item.shortcut?.label ?? "").font(theme.typography.body)
      }
      .font(theme.typography.body)
      .padding(.trailing, 14)
      .frame(height: theme.menuRowHeight)
      .foregroundStyle(selected ? theme.selectionInk : theme.ink.opacity(item.enabled ? 1 : 0.35))
      .background { ThemeSurfaceView(selected ? theme.selection : .solid(.clear)) }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!item.enabled)
    .padding(.horizontal, 2)
    .onHover { inside in
      if inside && !blinking { highlightedID = item.enabled ? item.id : nil }
    }
    .accessibilityLabel(item.title)
    .accessibilityValue(item.checked ? "Checked" : "")
    .accessibilityHint(item.shortcut.map { "Keyboard shortcut: \($0.label)" } ?? "")
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private func open(_ menu: RetroMenu, selectFirst: Bool = false) {
    guard !blinking else { return }
    openMenuID = menu.id
    highlightedID = selectFirst ? menu.items.first { $0.enabled && !$0.isSeparator }?.id : nil
  }

  private func dismiss() {
    blinkTask?.cancel()
    blinkTask = nil
    blinking = false
    openMenuID = nil
    highlightedID = nil
  }

  private func perform(_ item: RetroMenuItem) {
    guard !blinking, item.enabled, let action = item.action else { return }
    guard theme.id == "system7", !reduceMotion,
      playfulness?.allows(DesktopEffects.menuBlink.id) == true, openMenuID != nil
    else {
      dismiss()
      action()
      return
    }
    blinking = true
    blinkTask = Task { @MainActor in
      for _ in 0..<3 {
        highlightedID = item.id
        do { try await Task.sleep(for: .milliseconds(65)) } catch { return }
        highlightedID = nil
        do { try await Task.sleep(for: .milliseconds(65)) } catch { return }
      }
      guard !Task.isCancelled else { return }
      blinkTask = nil
      dismiss()
      action()
    }
  }

  private func moveSelection(_ direction: Int) {
    guard let menu = openMenu else { return }
    let available = menu.items.filter { $0.enabled && !$0.isSeparator }
    guard !available.isEmpty else { return }
    let current = available.firstIndex { $0.id == highlightedID }
    let next =
      current.map { ($0 + direction + available.count) % available.count }
      ?? (direction > 0 ? 0 : available.count - 1)
    highlightedID = available[next].id
  }

  private func handleKey(_ event: NSEvent) -> Bool {
    if blinking {
      if event.keyCode == 53 { dismiss() }
      return true
    }
    if event.charactersIgnoringModifiers?.lowercased() == "m",
      event.modifierFlags.intersection([.command, .option, .control, .shift]) == [
        .command, .option,
      ],
      let menu = menus.first
    {
      open(menu, selectFirst: true)
      return true
    }
    // Keep shortcuts available when dropdowns are closed; disabled commands are consumed too.
    if let item = menus.flatMap(\.items).first(where: { $0.shortcut?.matches(event) == true }) {
      if !event.isARepeat { perform(item) }
      return true
    }
    guard let menu = openMenu else { return false }
    let modifiers = event.modifierFlags.intersection([.command, .control, .option])
    guard modifiers.isEmpty else {
      dismiss()
      return false
    }
    switch event.keyCode {
    case 53: dismiss()  // Escape
    case 125: moveSelection(1)  // Down
    case 126: moveSelection(-1)  // Up
    case 123, 124:  // Left / Right
      if let index = menus.firstIndex(where: { $0.id == menu.id }) {
        let direction = event.keyCode == 124 ? 1 : -1
        open(menus[(index + direction + menus.count) % menus.count], selectFirst: true)
      }
    case 36, 76, 49:  // Return / keypad Enter / Space
      if let item = menu.items.first(where: { $0.id == highlightedID }) { perform(item) }
    case 48:
      dismiss()  // Let Tab resume regular focus navigation.
      return false
    default:
      if let characters = event.characters, !characters.isEmpty,
        let match = menu.items.first(where: {
          $0.enabled && !$0.isSeparator
            && $0.title.localizedLowercase.hasPrefix(characters.localizedLowercase)
        })
      {
        highlightedID = match.id
      }
    }
    return true
  }
}

/// Observe only this desktop window's events. Native dialogs retain their own key handling.
private struct DesktopMenuEvents: NSViewRepresentable {
  let handle: (NSEvent) -> Bool

  func makeCoordinator() -> Coordinator { Coordinator(handle: handle) }

  func makeNSView(context: Context) -> NSView {
    let view = EventProbe()
    let coordinator = context.coordinator
    coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
      [weak view, weak coordinator] event in
      let handled = MainActor.assumeIsolated {
        guard let window = view?.window, event.window === window, window.isKeyWindow,
          window.attachedSheet == nil, NSApp.modalWindow == nil
        else { return false }
        return coordinator?.handle(event) == true
      }
      return handled ? nil : event
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) { context.coordinator.handle = handle }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    if let monitor = coordinator.monitor { NSEvent.removeMonitor(monitor) }
    coordinator.monitor = nil
  }

  private final class EventProbe: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
  }

  @MainActor final class Coordinator {
    var handle: (NSEvent) -> Bool
    var monitor: Any?

    init(handle: @escaping (NSEvent) -> Bool) { self.handle = handle }
  }
}
