import Foundation
import Testing

@testable import MiniDesktop

@Test func resizeTracksPointerFromFixedSizeAndKeepsTheWindowOrigin() {
  var resize = WindowResize(
    origin: CGPoint(x: 100, y: 90), size: CGSize(width: 800, height: 472),
    startLocation: CGPoint(x: 900, y: 562))
  let minimum = CGSize(width: 640, height: 400)
  let desktop = CGSize(width: 1280, height: 720)
  for step in 0...200 {
    resize.location = CGPoint(x: 900 + step, y: 562 + step / 2)
    #expect(
      resize.size(minimum: minimum, desktop: desktop)
        == CGSize(width: 800 + step, height: 472 + step / 2))
    #expect(resize.origin == CGPoint(x: 100, y: 90))
  }
  resize.location = resize.startLocation
  #expect(resize.size(minimum: minimum, desktop: desktop) == resize.startSize)
}

@Test func resizeHonorsMinimumsAndAvailableSpaceAtTheWindowPosition() {
  var resize = WindowResize(
    origin: CGPoint(x: 100, y: 90), size: CGSize(width: 800, height: 472), startLocation: .zero)
  let minimum = CGSize(width: 640, height: 400)
  let desktop = CGSize(width: 1280, height: 720)
  resize.location = CGPoint(x: -2000, y: -2000)
  #expect(resize.size(minimum: minimum, desktop: desktop) == minimum)
  resize.location = CGPoint(x: 2000, y: 2000)
  #expect(resize.size(minimum: minimum, desktop: desktop) == CGSize(width: 1172, height: 622))
  #expect(
    WindowResize.constrain(minimum, minimum: minimum, maximum: CGSize(width: 500, height: 300))
      == CGSize(width: 500, height: 300))
}
