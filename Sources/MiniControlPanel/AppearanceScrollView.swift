import AppKit
import SwiftUI

/// This selector must be discoverable even when macOS hides overlay scrollbars.
struct AppearanceScrollView<Content: View>: NSViewRepresentable {
  @ViewBuilder let content: () -> Content

  func makeNSView(context: Context) -> AppearanceScroller {
    AppearanceScroller(content: AnyView(content().fixedSize()))
  }

  func updateNSView(_ view: AppearanceScroller, context: Context) {
    view.host.rootView = AnyView(content().fixedSize())
    view.needsLayout = true
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView: AppearanceScroller, context: Context)
    -> CGSize?
  {
    let size = nsView.host.fittingSize
    return CGSize(
      width: proposal.width ?? size.width,
      height: size.height + NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy))
  }
}

final class AppearanceScroller: NSScrollView {
  let host: NSHostingView<AnyView>

  init(content: AnyView) {
    host = NSHostingView(rootView: content)
    super.init(frame: .zero)
    drawsBackground = false
    borderType = .noBorder
    hasHorizontalScroller = true
    hasVerticalScroller = false
    autohidesScrollers = false
    scrollerStyle = .legacy
    documentView = host
    setAccessibilityLabel("Appearance themes")
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  // AppKit may reapply the system preference when pointing devices change.
  override var scrollerStyle: NSScroller.Style {
    get { super.scrollerStyle }
    set { super.scrollerStyle = .legacy }
  }

  override func layout() {
    super.layout()
    let size = host.fittingSize
    host.setFrameSize(
      CGSize(
        width: max(size.width, contentSize.width), height: max(size.height, contentSize.height)))
    reflectScrolledClipView(contentView)
  }
}
