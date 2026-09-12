import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Render the same pixel artwork used in the desktop at every native icon resolution.
/// Small icons omit the tile to keep every pixel legible in Finder lists.
@main
struct GenerateIcons {
  static func main() throws {
    let output = URL(fileURLWithPath: ".build/AppIcon.iconset", isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    for points in [16, 32, 128, 256, 512] {
      for scale in [1, 2] {
        let pixels = points * scale
        let suffix = scale == 2 ? "@2x" : ""
        let name = "icon_\(points)x\(points)\(suffix).png"
        try render(pixels: pixels, to: output.appendingPathComponent(name))
      }
    }
    let preview = try Data(contentsOf: output.appendingPathComponent("icon_512x512@2x.png"))
    try preview.write(to: URL(fileURLWithPath: "Support/AppIcon.png"))
  }

  private static func render(pixels: Int, to url: URL) throws {
    guard
      let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      throw CocoaError(.fileWriteUnknown)
    }

    let side = CGFloat(pixels)
    context.translateBy(x: 0, y: side)
    context.scaleBy(x: 1, y: -1)

    if pixels > 32 {
      let inset = (side * 0.08).rounded()
      let tile = CGRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)
      let radius = side * 0.18
      let path = CGPath(
        roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil)
      context.addPath(path)
      context.setFillColor(NSColor.white.cgColor)
      context.fillPath()
      context.addPath(path)
      context.setLineWidth(max(1, (side / 128).rounded()))
      context.setStrokeColor(NSColor.black.cgColor)
      context.strokePath()
    }

    // Integer-sized cells and no antialiasing preserve the bitmap character at every size.
    let cell = pixels <= 32 ? side / 16 : floor(side / 24)
    let origin = CGPoint(x: floor((side - cell * 16) / 2), y: floor((side - cell * 15) / 2))
    context.setShouldAntialias(false)
    for (y, row) in PixelSymbol.computer.rows.enumerated() {
      for (x, pixel) in row.enumerated() where pixel != " " {
        context.setFillColor(pixel == "#" ? NSColor.black.cgColor : NSColor.white.cgColor)
        context.fill(
          CGRect(
            x: origin.x + CGFloat(x) * cell, y: origin.y + CGFloat(y) * cell, width: cell,
            height: cell))
      }
    }

    guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
      throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
  }
}
