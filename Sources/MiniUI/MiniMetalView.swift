import AppKit
import MetalKit

/// Animated desk accessories keep moving while they are on screen, whichever app has focus,
/// including when Universal Control takes the pointer to another Mac. They pause only when their
/// window cannot be seen, and draw at a lower rate while Hello Mini is in the background.
public class MiniMetalView: MTKView {
  /// The frame rate while Hello Mini is frontmost.
  public var activeFramesPerSecond = 30 {
    didSet { applyPolicy() }
  }
  /// Whether the owning view wants continuous frames; otherwise it draws on demand.
  public var wantsAnimation = false {
    didSet { applyPolicy() }
  }

  nonisolated public static func framesPerSecond(active: Bool, base: Int) -> Int {
    active ? base : max(10, base / 2)
  }

  nonisolated public static func shouldPause(wantsAnimation: Bool, windowVisible: Bool) -> Bool {
    !(wantsAnimation && windowVisible)
  }

  public override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    let center = NotificationCenter.default
    center.removeObserver(self, name: NSWindow.didChangeOcclusionStateNotification, object: nil)
    center.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
    center.removeObserver(self, name: NSApplication.didBecomeActiveNotification, object: nil)
    center.removeObserver(self, name: NSApplication.didResignActiveNotification, object: nil)
    if let window {
      for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didBecomeKeyNotification]
      {
        center.addObserver(self, selector: #selector(stateChanged), name: name, object: window)
      }
      for name in [
        NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification,
      ] {
        center.addObserver(self, selector: #selector(stateChanged), name: name, object: nil)
      }
    }
    applyPolicy()
  }

  @objc private func stateChanged(_ notification: Notification) { applyPolicy() }

  private func applyPolicy() {
    preferredFramesPerSecond = Self.framesPerSecond(
      active: NSApp?.isActive ?? true, base: activeFramesPerSecond)
    let visible = window?.occlusionState.contains(.visible) ?? false
    let pause = Self.shouldPause(wantsAnimation: wantsAnimation, windowVisible: visible)
    enableSetNeedsDisplay = !wantsAnimation
    if isPaused != pause { isPaused = pause }
    // A paused view still needs a still frame once its window becomes visible again.
    if pause { needsDisplay = true }
  }
}

/// A simulation clock for shader animation. Metal uniforms are 32-bit floats, which lose
/// sub-frame precision after roughly a day and stop advancing entirely after about twelve.
public enum AnimationClock {
  /// Wrapping once a day keeps every frame distinct; the pattern restarts at the wrap.
  public static let period: Double = 86_400

  public static func advance(_ time: Double, by delta: Double) -> Double {
    (time + max(0, delta)).truncatingRemainder(dividingBy: period)
  }
}
