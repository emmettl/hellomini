import Foundation
import Testing

@testable import MiniDesktop

@Test func fullyCoveredWindowsSleepButExposedSliversStayLive() {
  let window = CGRect(x: 100, y: 80, width: 300, height: 200)
  #expect(WindowVisibility.isVisible(window, behind: []))
  #expect(!WindowVisibility.isVisible(window, behind: [window]))
  #expect(
    !WindowVisibility.isVisible(window, behind: [CGRect(x: 0, y: 0, width: 800, height: 600)]))
  let left = CGRect(x: 100, y: 80, width: 150, height: 200)
  let right = CGRect(x: 250, y: 80, width: 150, height: 200)
  #expect(!WindowVisibility.isVisible(window, behind: [left, right]))
  #expect(WindowVisibility.isVisible(window, behind: [left, right.offsetBy(dx: 1, dy: 0)]))
  #expect(WindowVisibility.isVisible(window, behind: [window.offsetBy(dx: 300, dy: 0)]))
  #expect(WindowVisibility.isVisible(window, behind: [left, left]))
  #expect(!WindowVisibility.isVisible(.zero, behind: []))
}
