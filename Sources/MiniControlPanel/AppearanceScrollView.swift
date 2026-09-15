import MiniUI
import SwiftUI

/// The theme strip keeps a visible, themed scrollbar regardless of the macOS overlay-scrollbar
/// preference. It is pure SwiftUI so tiny-screen scaling moves drawing and clicks together; an
/// embedded AppKit hosting view drew at 2× but resolved clicks at 1×.
struct AppearanceScrollView<Content: View>: View {
  @Environment(\.miniTheme) private var theme
  @State private var position = ScrollPosition(edge: .leading)
  @State private var metrics = StripScrollMetrics()
  @State private var dragOrigin: CGFloat?
  let step: CGFloat
  @ViewBuilder let content: () -> Content

  init(step: CGFloat = 174, @ViewBuilder content: @escaping () -> Content) {
    self.step = step
    self.content = content
  }

  var body: some View {
    VStack(spacing: 4) {
      ScrollView(.horizontal) {
        content().fixedSize()
      }
      .scrollIndicators(.hidden)
      .scrollPosition($position)
      .onScrollGeometryChange(for: StripScrollMetrics.self) { geometry in
        StripScrollMetrics(
          offset: geometry.contentOffset.x, content: geometry.contentSize.width,
          visible: geometry.containerSize.width)
      } action: { _, new in
        metrics = new
      }
      .accessibilityElement(children: .contain)
      .accessibilityLabel("Appearance themes")
      scrollbar
    }
  }

  private var scrollbar: some View {
    HStack(spacing: 0) {
      arrow("arrowtriangle.left.fill", label: "Scroll themes left", enabled: metrics.offset > 0.5) {
        scroll(to: metrics.offset - step)
      }
      GeometryReader { geometry in
        let thumb = metrics.thumb(track: geometry.size.width)
        ZStack(alignment: .leading) {
          Rectangle().fill(theme.paper)
          // A classic scrollbar: a paper thumb with grip lines on a toned track.
          Rectangle().fill(theme.ink.opacity(0.22))
          Rectangle().fill(theme.paper)
            .overlay {
              HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                  Rectangle().fill(theme.ink.opacity(0.6)).frame(width: 1, height: 7)
                }
              }
            }
            .overlay(Rectangle().strokeBorder(theme.ink, lineWidth: 1))
            .frame(width: thumb.width)
            .offset(x: thumb.x)
            .opacity(metrics.overflows ? 1 : 0.35)
            .gesture(
              DragGesture(minimumDistance: 0)
                .onChanged { value in
                  let origin = dragOrigin ?? metrics.offset
                  dragOrigin = origin
                  position.scrollTo(
                    x: metrics.offset(
                      from: origin, dragging: value.translation.width, track: geometry.size.width))
                }
                .onEnded { _ in dragOrigin = nil }
            )
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
          guard metrics.overflows else { return }
          scroll(to: metrics.offset + (location.x < thumb.x ? -metrics.visible : metrics.visible))
        }
      }
      .overlay(Rectangle().strokeBorder(theme.ink, lineWidth: 1))
      arrow(
        "arrowtriangle.right.fill", label: "Scroll themes right",
        enabled: metrics.offset < metrics.maxOffset - 0.5
      ) {
        scroll(to: metrics.offset + step)
      }
    }
    .frame(height: 16)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Theme strip position")
    .accessibilityValue(
      metrics.overflows
        ? "\(Int((metrics.offset / metrics.maxOffset * 100).rounded())) percent"
        : "All themes visible"
    )
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: scroll(to: metrics.offset + step)
      case .decrement: scroll(to: metrics.offset - step)
      @unknown default: break
      }
    }
  }

  private func arrow(
    _ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 7))
        .frame(width: 16, height: 16)
        .background(theme.paper)
        .overlay(Rectangle().strokeBorder(theme.ink, lineWidth: 1))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(theme.ink.opacity(enabled ? 1 : 0.35))
    .disabled(!enabled)
    .accessibilityLabel(label)
  }

  private func scroll(to offset: CGFloat) {
    withAnimation(.easeOut(duration: 0.2)) { position.scrollTo(x: metrics.clamp(offset)) }
  }
}

/// Maps between the strip's scroll offset and its scrollbar thumb.
struct StripScrollMetrics: Equatable {
  var offset: CGFloat = 0
  var content: CGFloat = 0
  var visible: CGFloat = 0

  var maxOffset: CGFloat { max(0, content - visible) }
  var overflows: Bool { maxOffset > 0.5 }

  func clamp(_ proposed: CGFloat) -> CGFloat { min(max(0, proposed), maxOffset) }

  func thumb(track: CGFloat) -> (x: CGFloat, width: CGFloat) {
    guard overflows, content > 0 else { return (0, max(0, track)) }
    let width = min(track, max(24, track * visible / content))
    let travel = max(0, track - width)
    return (travel * clamp(offset) / maxOffset, width)
  }

  func offset(from origin: CGFloat, dragging distance: CGFloat, track: CGFloat) -> CGFloat {
    let travel = max(1, track - thumb(track: track).width)
    return clamp(origin + distance * maxOffset / travel)
  }
}
