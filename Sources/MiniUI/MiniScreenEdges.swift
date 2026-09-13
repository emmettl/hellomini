import SwiftUI

extension View {
  /// An inset bevel and rounded screen corners survive native full-screen presentation.
  /// Apply after display scaling so the edge treatment has the same physical size in every mode.
  public func miniScreenEdges() -> some View {
    clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [.white.opacity(0.45), .black.opacity(0.5)],
              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1
          )
          .allowsHitTesting(false).accessibilityHidden(true)
      }
  }
}
