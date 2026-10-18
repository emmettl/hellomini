import Foundation
import Testing

@testable import MiniDesktop

@Test func physicalWindowImpulseIsFiniteBoundedAndMotionGated() {
  #expect(PhysicalWindowMotion.impulse(translation: .zero) == 0)
  #expect(PhysicalWindowMotion.impulse(translation: CGSize(width: 10000, height: 10000)) == 1)
  #expect(PhysicalWindowMotion.impulse(translation: CGSize(width: CGFloat.nan, height: 1)) == 0)
  #expect(PhysicalWindowMotion.allows(enabled: true, reduceMotion: false, active: true))
  #expect(!PhysicalWindowMotion.allows(enabled: false, reduceMotion: false, active: true))
  #expect(!PhysicalWindowMotion.allows(enabled: true, reduceMotion: true, active: true))
  #expect(!PhysicalWindowMotion.allows(enabled: true, reduceMotion: false, active: false))
}
