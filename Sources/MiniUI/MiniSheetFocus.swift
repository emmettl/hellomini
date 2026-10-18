import AppKit
import SwiftUI

/// A sheet remembers the parent's responder rather than leaving focus on an unrelated Dock item.
struct MiniSheetFocus: NSViewRepresentable {
  final class Anchor: NSView {
    weak var parent: NSWindow?
    weak var previous: NSResponder?
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if let parent = window?.sheetParent, self.parent == nil {
        self.parent = parent
        previous = parent.firstResponder
      }
    }
    func restore() {
      guard let parent, let previous else { return }
      Task { @MainActor [weak parent, weak previous] in
        do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
        guard let parent, let previous, parent.isKeyWindow, parent.attachedSheet == nil,
          NSApp.modalWindow == nil
        else { return }
        if let view = previous as? NSView, view.window !== parent { return }
        parent.makeFirstResponder(previous)
      }
    }
  }
  func makeNSView(context: Context) -> Anchor { Anchor() }
  func updateNSView(_ view: Anchor, context: Context) {}
  static func dismantleNSView(_ view: Anchor, coordinator: ()) { view.restore() }
}
