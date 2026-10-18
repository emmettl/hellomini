import AppKit
import SwiftUI

/// Restore accessory focus after AppKit finishes sheet dismissal, without a timed guess.
/// Attach to the presenting view and increment request from onDismiss.
public struct MiniSheetFocusRestoration: NSViewRepresentable {
  let request: Int
  let active: Bool
  let action: @MainActor () -> Void
  public init(request: Int, active: Bool, action: @escaping @MainActor () -> Void) {
    self.request = request
    self.active = active
    self.action = action
  }
  public final class Anchor: NSView {
    var request = 0
    var active = true
    var generation = 0
    var pending = false
    var action: (@MainActor () -> Void)?
    private var observers: [NSObjectProtocol] = []
    public override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      for observer in observers { NotificationCenter.default.removeObserver(observer) }
      observers = []
      generation += 1
      guard let window else {
        pending = false
        return
      }
      for name in [
        NSWindow.didEndSheetNotification, NSWindow.didBecomeKeyNotification,
        NSWindow.didUpdateNotification,
      ] {
        observers.append(
          NotificationCenter.default.addObserver(
            forName: name, object: window, queue: .main
          ) { [weak self] _ in MainActor.assumeIsolated { self?.schedule() } })
      }
    }
    func update(request: Int, active: Bool, action: @escaping @MainActor () -> Void) {
      self.action = action
      self.active = active
      if !active {
        generation += 1
        pending = false
      }
      guard self.request != request else { return }
      self.request = request
      pending = active
      schedule()
    }
    func schedule() {
      guard pending, active, let window, window.attachedSheet == nil else { return }
      generation += 1
      let token = generation
      // AppKit's responder changes finish in this event; the next main-queue turn is the barrier.
      DispatchQueue.main.async { [weak self, weak window] in
        guard let self, let window, self.window === window, self.generation == token,
          self.active, self.pending, window.isKeyWindow, window.attachedSheet == nil,
          NSApp.modalWindow == nil
        else { return }
        self.pending = false
        self.action?()
      }
    }
    func cancel() {
      generation += 1
      pending = false
      action = nil
    }
    isolated deinit {
      for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }
  }
  public func makeNSView(context: Context) -> Anchor {
    let view = Anchor()
    view.request = request
    view.active = active
    view.action = action
    return view
  }
  public func updateNSView(_ view: Anchor, context: Context) {
    view.update(request: request, active: active, action: action)
  }
  public static func dismantleNSView(_ view: Anchor, coordinator: ()) { view.cancel() }
}
