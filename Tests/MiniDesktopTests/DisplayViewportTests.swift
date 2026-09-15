import AppKit
import MiniUI
import SwiftUI
import Testing

@testable import MiniDesktop

@Test func tinyScreenUsesTheAvailableAreaWithoutChangingPuristGeometry() {
  for available in [CGSize(width: 1280, height: 720), CGSize(width: 960, height: 600)] {
    let tiny = DisplayViewportLayout(available: available, puristMode: false, tinyScreenMode: true)
    #expect(tiny.presented == available)
    #expect(tiny.logical.width * 2 == available.width)
    #expect(tiny.logical.height * 2 == available.height)
    let normal = DisplayViewportLayout(
      available: available, puristMode: false, tinyScreenMode: false)
    #expect(normal.logical == available)
    let purist = DisplayViewportLayout(available: available, puristMode: true, tinyScreenMode: true)
    #expect(purist.logical == CGSize(width: 512, height: 384))
    #expect(purist.scale == 1)
  }
}

@Test @MainActor func tinyScreenScalesTheWholeContentAndKeepsScreenEdges() throws {
  struct Probe: View {
    @Environment(\.miniDisplay) private var display
    var body: some View {
      ZStack(alignment: .topLeading) {
        Color.white
        // Tests the injected layout context as well as the visible transform.
        if display.logicalSize == CGSize(width: 640, height: 360) && display.scale == 2 {
          Color.red.frame(width: 20, height: 10).offset(x: 50, y: 40)
        }
      }
    }
  }
  let view = MiniDisplayViewport(puristMode: false, tinyScreenMode: true) { Probe() }
    .frame(width: 1280, height: 720)
  let image = NSBitmapImageRep(cgImage: try #require(ImageRenderer(content: view).cgImage))
  func red(_ x: Int, _ y: Int) -> Bool {
    let color = image.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
    return color.redComponent > color.greenComponent + 0.2
      && color.redComponent > color.blueComponent + 0.2
  }
  #expect(red(100, 80) && red(139, 99))
  #expect(!red(99, 80) && !red(140, 99) && !red(100, 100))
  #expect(image.colorAt(x: 0, y: 0)!.usingColorSpace(.deviceRGB)!.redComponent < 0.1)
  #expect(image.colorAt(x: 640, y: 360)!.usingColorSpace(.deviceRGB)!.redComponent > 0.9)
}

@Test func enlargedDesktopRetainsReachableChromeWithEitherLauncher() {
  for available in [CGSize(width: 1280, height: 720), CGSize(width: 960, height: 600)] {
    let layout = DisplayViewportLayout(
      available: available, puristMode: false, tinyScreenMode: true)
    for hasDock in [false, true] {
      let desktop = DesktopDockLayout.windowArea(desktop: layout.logical, hasDock: hasDock)
      let size = WindowResize.constrain(
        CGSize(width: 800, height: 500), minimum: CGSize(width: 640, height: 400),
        maximum: CGSize(width: desktop.width - 16, height: desktop.height - 48))
      let origin = WindowBounds(desktopSize: desktop, windowSize: size, menuBarHeight: 30)
        .constrain(CGPoint(x: 900, y: 500))
      #expect(origin.x >= 8 && origin.y >= 40)
      #expect(origin.x + size.width <= desktop.width - 8)
      #expect(origin.y + size.height <= desktop.height - 8)
    }
  }
}

@Test func shortDesktopsUseTheCompactDockAndLargeOnesKeepTheFullShelf() {
  func height(_ desktop: CGSize) -> CGFloat {
    DesktopDockLayout.windowArea(desktop: desktop, hasDock: true).height
  }
  #expect(height(CGSize(width: 640, height: 360)) == 304)
  #expect(height(CGSize(width: 512, height: 384)) == 328)
  #expect(height(CGSize(width: 1280, height: 720)) == 632)
  #expect(height(CGSize(width: 960, height: 600)) == 512)
  for count in [15, 19, 30] {
    let layout = DesktopDockLayout(
      desktopWidth: 640, entryCount: count, hasMinimised: count > 19, compact: true)
    #expect(layout.iconSize >= 22 && layout.iconSize <= 30)
    #expect(layout.width <= 640 - 32 && layout.scrollWidth > 0)
  }
}
