import AppKit
import SwiftUI

/// Preserve native full-screen support while giving the desktop the entire content area.
struct DesktopWindowConfiguration: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView { WindowProbe() }
  func updateNSView(_ nsView: NSView, context: Context) {}

  private final class WindowProbe: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      guard let window else { return }
      window.titleVisibility = .hidden
      window.titlebarAppearsTransparent = true
      window.styleMask.insert(.fullSizeContentView)
      window.isMovableByWindowBackground = false
      window.standardWindowButton(.closeButton)?.isHidden = true
      window.standardWindowButton(.miniaturizeButton)?.isHidden = true
      window.standardWindowButton(.zoomButton)?.isHidden = true
      window.backgroundColor = .white
    }
  }
}
