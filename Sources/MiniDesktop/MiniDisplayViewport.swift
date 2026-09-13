import AppKit
import SwiftUI

/// The complete system, including startup and screensavers, shares this fixed logical display.
public struct MiniDisplayViewport<Content: View>: View {
  @State private var nativeChromeHeight: CGFloat = 0
  let puristMode: Bool
  let windowChromeChanged: @MainActor (CGFloat) -> Void
  @ViewBuilder let content: () -> Content

  public init(
    puristMode: Bool, windowChromeChanged: @escaping @MainActor (CGFloat) -> Void = { _ in },
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.puristMode = puristMode
    self.windowChromeChanged = windowChromeChanged
    self.content = content
  }

  public var body: some View {
    GeometryReader { geometry in
      content()
        .frame(
          width: puristMode ? 512 : geometry.size.width,
          height: puristMode ? 384 : geometry.size.height
        )
        .clipped()
        .position(
          x: geometry.size.width / 2,
          y: geometry.size.height / 2 + (puristMode ? nativeChromeHeight / 2 : 0))
    }
    .background(.black)
    .background(
      DisplayWindowSizing(
        puristMode: puristMode,
        chromeChanged: { height in
          nativeChromeHeight = height
          windowChromeChanged(height)
        })
    )
    .ignoresSafeArea()
  }
}

private struct DisplayWindowSizing: NSViewRepresentable {
  let puristMode: Bool
  let chromeChanged: @MainActor (CGFloat) -> Void
  func makeNSView(context: Context) -> Probe { Probe() }
  func updateNSView(_ view: Probe, context: Context) {
    view.chromeChanged = chromeChanged
    view.setMode(puristMode)
  }

  final class Probe: NSView {
    var chromeChanged: (@MainActor (CGFloat) -> Void)?
    private var lastChromeHeight: CGFloat?
    private var requestedMode = false
    private var appliedMode: Bool?
    private var normalFrame: NSRect?
    private var restoreNormalAfterFullScreen = false
    private static let normalFrameKey = "display.normalWindowFrame"

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      NotificationCenter.default.removeObserver(
        self, name: NSWindow.didExitFullScreenNotification, object: nil)
      if let window {
        NotificationCenter.default.addObserver(
          self, selector: #selector(leftFullScreen),
          name: NSWindow.didExitFullScreenNotification, object: window)
      }
      setMode(requestedMode)
    }

    @objc private func leftFullScreen() {
      guard requestedMode || restoreNormalAfterFullScreen else { return }
      appliedMode = nil
      applyMode(restoringWindowedMode: restoreNormalAfterFullScreen)
      restoreNormalAfterFullScreen = false
    }

    func setMode(_ enabled: Bool) {
      requestedMode = enabled
      // SwiftUI must finish updating its minimum size before AppKit restores the frame.
      DispatchQueue.main.async { [weak self] in self?.applyMode() }
    }

    private func applyMode(restoringWindowedMode: Bool = false) {
      guard let window else { return }
      let chromeHeight = max(
        0, window.frame.height - window.contentLayoutRect.height)
      if chromeHeight != lastChromeHeight {
        lastChromeHeight = chromeHeight
        chromeChanged?(chromeHeight)
      }
      if !requestedMode && appliedMode != true && !restoringWindowedMode
        && !window.styleMask.contains(.fullScreen)
        && window.frame.width >= 960 && window.frame.height >= 600
      {
        normalFrame = window.frame
        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: Self.normalFrameKey)
      }
      guard appliedMode != requestedMode else { return }
      let entering = requestedMode
      let wasPurist = appliedMode == true
      if normalFrame == nil, let saved = UserDefaults.standard.string(forKey: Self.normalFrameKey) {
        let frame = NSRectFromString(saved)
        if frame.origin.x.isFinite && frame.origin.y.isFinite && frame.width.isFinite
          && frame.height.isFinite && frame.width >= 960 && frame.height >= 600
        {
          normalFrame = frame
        }
      }
      if entering && appliedMode == false && !window.styleMask.contains(.fullScreen)
        && window.frame.width >= 960 && window.frame.height >= 600
      {
        normalFrame = window.frame
        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: Self.normalFrameKey)
      }
      appliedMode = entering
      guard !window.styleMask.contains(.fullScreen) else {
        if !entering && wasPurist { restoreNormalAfterFullScreen = true }
        return
      }
      if entering {
        var frame = window.frame
        frame.origin.y += frame.height - 384
        frame.size = NSSize(width: 512, height: 384)
        window.setFrame(frame, display: true)
      } else {
        window.maxSize = NSSize(
          width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        guard wasPurist || restoringWindowedMode else { return }
        if let normalFrame {
          window.setFrame(window.constrainFrameRect(normalFrame, to: window.screen), display: true)
        } else {
          window.setContentSize(NSSize(width: 1280, height: 720))
        }
      }
    }
  }
}
