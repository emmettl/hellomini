import AppKit
import SwiftUI

/// Physical US ANSI positions. Displayed characters remain a reference, not a layout translator.
struct KeyCapsInput {
  static let rows: [[UInt16]] = [
    [18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24],
    [12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30],
    [0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39],
    [6, 7, 8, 9, 11, 45, 46, 43, 47, 44],
  ]
  static func characters(_ normal: String, shifted upper: String, shift: Bool, caps: Bool) -> String
  {
    String(
      zip(normal, upper).map { lower, upper in
        let letter = lower.isLetter
        return (letter ? shift != caps : shift) ? upper : lower
      })
  }
  static func pressed(_ keys: Set<UInt16>, code: UInt16, down: Bool) -> Set<UInt16> {
    var next = keys
    if down { next.insert(code) } else { next.remove(code) }
    return next
  }
}

/// Observe only events already delivered to this application; never consume or monitor globally.
struct KeyCapsEventSource: NSViewRepresentable {
  let enabled: Bool
  let changed: @MainActor (Set<UInt16>, NSEvent.ModifierFlags) -> Void

  final class Anchor: NSView {
    var enabled = false
    var keys = Set<UInt16>()
    var flags: NSEvent.ModifierFlags = []
    var changed: (@MainActor (Set<UInt16>, NSEvent.ModifierFlags) -> Void)?
    private var monitor: Any?
    private var observer: NSObjectProtocol?
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      stop()
      guard let window else { return }
      observer = NotificationCenter.default.addObserver(
        forName: NSWindow.didResignKeyNotification, object: window, queue: .main
      ) { [weak self] _ in MainActor.assumeIsolated { self?.clear() } }
      monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) {
        [weak self] event in
        MainActor.assumeIsolated {
          guard let self, self.enabled, self.window?.isKeyWindow == true,
            event.window === self.window, self.window?.attachedSheet == nil,
            NSApp.modalWindow == nil
          else { return }
          if event.type != .flagsChanged {
            self.keys = KeyCapsInput.pressed(
              self.keys, code: event.keyCode, down: event.type == .keyDown)
          }
          self.flags = event.modifierFlags.intersection([
            .shift, .control, .option, .command, .capsLock,
          ])
          self.changed?(self.keys, self.flags)
        }
        return event
      }
    }
    func clear(notify: Bool = true) {
      guard !keys.isEmpty || !flags.isEmpty else { return }
      keys = []
      flags = []
      if notify { changed?([], []) }
    }
    func stop() {
      if let monitor { NSEvent.removeMonitor(monitor) }
      if let observer { NotificationCenter.default.removeObserver(observer) }
      monitor = nil
      observer = nil
      clear()
    }
    isolated deinit {
      if let monitor { NSEvent.removeMonitor(monitor) }
      if let observer { NotificationCenter.default.removeObserver(observer) }
    }
  }
  func makeNSView(context: Context) -> Anchor {
    let view = Anchor()
    view.enabled = enabled
    view.changed = changed
    return view
  }
  func updateNSView(_ view: Anchor, context: Context) {
    view.changed = changed
    if view.enabled && !enabled {
      // SwiftUI clears its own state from onChange; do not notify during updateNSView.
      view.clear(notify: false)
    }
    view.enabled = enabled
  }
  static func dismantleNSView(_ view: Anchor, coordinator: ()) { view.stop() }
}
