import AppKit
import MiniCore
import MiniUI
import SwiftUI

/// A manually invoked app preview, not a macOS lock screen or installed .saver bundle.
@MainActor final class AquariumPresentation: NSObject, NSWindowDelegate {
  private var window: AquariumPreviewWindow?
  private weak var previousWindow: NSWindow?
  private weak var model: AquariumModel?

  func show(model: AquariumModel, playfulness: PlayfulnessSettings, theme: MiniThemeDefinition) {
    guard window == nil, let screen = NSApp.keyWindow?.screen ?? NSScreen.main else { return }
    previousWindow = NSApp.keyWindow
    self.model = model
    let window = AquariumPreviewWindow(
      contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.dismiss = { [weak self] in self?.close() }
    window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
    window.contentView = NSHostingView(
      rootView: AquariumTank(model: model, playfulness: playfulness)
        .overlay(alignment: .bottom) {
          Text("Click or press any key to return")
            .font(theme.typography.small).padding(8).background(theme.paper).padding(16)
            .allowsHitTesting(false)
        }
        .environment(\.miniTheme, theme)
        .environment(\.colorScheme, theme.colorScheme)
        .foregroundStyle(theme.ink))
    self.window = window
    model.presenting = true
    model.simulation.previousTime = nil
    window.makeKeyAndOrderFront(nil)
  }

  func windowDidResignKey(_ notification: Notification) { close() }

  private func close() {
    guard let window else { return }
    self.window = nil
    window.delegate = nil
    window.contentView = nil
    window.close()
    model?.presenting = false
    model?.simulation.previousTime = nil
    if NSApp.isActive { previousWindow?.makeKeyAndOrderFront(nil) }
  }
}

private final class AquariumPreviewWindow: NSWindow {
  var dismiss: (() -> Void)?
  override var canBecomeKey: Bool { true }
  override func sendEvent(_ event: NSEvent) {
    switch event.type {
    case .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown: dismiss?()
    default: super.sendEvent(event)
    }
  }
}
