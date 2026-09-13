import AppKit
import MetalKit

/// A paused scene still needs its first frame after its window becomes visible.
public class MiniMetalView: MTKView {
  public override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    let center = NotificationCenter.default
    center.removeObserver(self, name: NSWindow.didChangeOcclusionStateNotification, object: nil)
    center.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
    if let window {
      for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didBecomeKeyNotification]
      {
        center.addObserver(
          self, selector: #selector(windowBecameVisible), name: name, object: window)
      }
      needsDisplay = true
    }
  }

  @objc private func windowBecameVisible(_ notification: Notification) {
    if isPaused { needsDisplay = true }
  }
}
