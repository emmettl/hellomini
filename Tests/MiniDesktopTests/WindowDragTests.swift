import Foundation
import Testing

@testable import MiniDesktop

private let bounds = WindowBounds(
  desktopSize: CGSize(width: 1280, height: 720),
  windowSize: CGSize(width: 556, height: 382), menuBarHeight: 30)

@Test func windowTracksThePointerWithoutAccumulatingMovement() {
  var drag = WindowDrag(
    origin: CGPoint(x: 120, y: 132), startLocation: CGPoint(x: 400, y: 147), bounds: bounds)
  for step in 0...400 {
    let dx = CGFloat(step) / 2
    let dy = CGFloat(step % 30) / 2
    drag.location = CGPoint(x: 400 + dx, y: 147 + dy)
    let expected = CGPoint(x: 120 + dx, y: 132 + dy)
    #expect(drag.position(in: bounds) == expected)
    // Repeated layout evaluations at the same pointer location cannot feed back into the drag.
    #expect(drag.position(in: bounds) == expected)
  }
}

@Test func draggingStartsAtTheVisibleOriginAfterDesktopResize() {
  let resized = WindowBounds(
    desktopSize: CGSize(width: 960, height: 600),
    windowSize: CGSize(width: 556, height: 490), menuBarHeight: 30)
  var drag = WindowDrag(
    origin: CGPoint(x: 870, y: 400), startLocation: CGPoint(x: 600, y: 117), bounds: resized)
  #expect(drag.position(in: resized) == CGPoint(x: 396, y: 102))
  drag.location = CGPoint(x: 580, y: 87)
  #expect(drag.position(in: resized) == CGPoint(x: 376, y: 72))
}

@Test func draggingPastEdgesAndReversingKeepsTheOriginalGrabPoint() {
  var drag = WindowDrag(
    origin: CGPoint(x: 120, y: 132), startLocation: CGPoint(x: 400, y: 147), bounds: bounds)
  drag.location = CGPoint(x: -1000, y: -1000)
  #expect(drag.position(in: bounds) == CGPoint(x: 8, y: 40))
  drag.location = CGPoint(x: 2000, y: 2000)
  #expect(drag.position(in: bounds) == CGPoint(x: 716, y: 330))
  drag.location = CGPoint(x: 420, y: 157)
  #expect(drag.position(in: bounds) == CGPoint(x: 140, y: 142))
  drag.location = drag.startLocation
  #expect(drag.position(in: bounds) == drag.startOrigin)
}

@Test func committingAndStartingAnotherDragDoesNotApplyTheDeltaTwice() {
  var drag = WindowDrag(
    origin: CGPoint(x: 120, y: 132), startLocation: CGPoint(x: 400, y: 147), bounds: bounds)
  drag.location = CGPoint(x: 570, y: 206)
  let committed = drag.position(in: bounds)
  #expect(committed == CGPoint(x: 290, y: 191))
  #expect(bounds.constrain(committed) == committed)
  // Publishing the committed binding while the gesture is still present gives the same position.
  #expect(drag.position(in: bounds) == committed)
  var next = WindowDrag(origin: committed, startLocation: drag.location, bounds: bounds)
  #expect(next.position(in: bounds) == committed)
  next.location = CGPoint(x: 550, y: 196)
  #expect(next.position(in: bounds) == CGPoint(x: 270, y: 181))
}

@Test func oversizedWindowsKeepTheirTitleBarsBelowTheThemedMenu() {
  let smallDesktop = WindowBounds(
    desktopSize: CGSize(width: 500, height: 300),
    windowSize: CGSize(width: 556, height: 382), menuBarHeight: 50)
  #expect(smallDesktop.constrain(CGPoint(x: 200, y: 200)) == CGPoint(x: 8, y: 60))
}
