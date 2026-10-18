import AppKit
import Testing

@testable import MiniUI

@MainActor private final class FocusTestWindow: NSWindow {
  var testSheet: NSWindow?
  override var isKeyWindow: Bool { true }
  override var attachedSheet: NSWindow? { testSheet }
}
@MainActor private func drainFocusQueue() async {
  await withCheckedContinuation { continuation in
    DispatchQueue.main.async { continuation.resume() }
  }
}
@Test @MainActor func focusWaitsForSheetEndAndCoalescesRequestsWithoutTimers() async {
  let window = FocusTestWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
  let anchor = MiniSheetFocusRestoration.Anchor()
  window.contentView = anchor
  window.testSheet = NSWindow()
  var calls = 0
  anchor.update(request: 1, active: true) { calls += 1 }
  await drainFocusQueue()
  #expect(calls == 0)
  window.testSheet = nil
  NotificationCenter.default.post(name: NSWindow.didEndSheetNotification, object: window)
  anchor.update(request: 2, active: true) { calls += 1 }
  await drainFocusQueue()
  #expect(calls == 1)
  anchor.update(request: 3, active: true) { calls += 1 }
  anchor.update(request: 3, active: false) { calls += 1 }
  await drainFocusQueue()
  #expect(calls == 1)
  anchor.update(request: 4, active: true) { calls += 1 }
  anchor.cancel()
  await drainFocusQueue()
  #expect(calls == 1)
}
