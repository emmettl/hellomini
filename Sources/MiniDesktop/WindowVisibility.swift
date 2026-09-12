import Foundation

enum WindowVisibility {
  /// Subtract the union of opaque windows, retaining partially exposed accessories.
  static func isVisible(_ rectangle: CGRect, behind covers: [CGRect]) -> Bool {
    var pieces = [rectangle]
    for cover in covers {
      pieces = pieces.flatMap { piece -> [CGRect] in
        let overlap = piece.intersection(cover)
        guard !overlap.isNull && !overlap.isEmpty else { return [piece] }
        return [
          CGRect(
            x: piece.minX, y: piece.minY, width: piece.width, height: overlap.minY - piece.minY),
          CGRect(
            x: piece.minX, y: overlap.maxY, width: piece.width, height: piece.maxY - overlap.maxY),
          CGRect(
            x: piece.minX, y: overlap.minY, width: overlap.minX - piece.minX, height: overlap.height
          ),
          CGRect(
            x: overlap.maxX, y: overlap.minY, width: piece.maxX - overlap.maxX,
            height: overlap.height),
        ].filter { !$0.isEmpty }
      }
      if pieces.isEmpty { return false }
    }
    return !rectangle.isEmpty && !pieces.isEmpty
  }
}
