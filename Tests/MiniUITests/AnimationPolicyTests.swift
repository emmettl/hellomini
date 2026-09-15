import Testing

@testable import MiniUI

@Test func deskAnimationsKeepGoingWhileVisibleAndSlowDownInTheBackground() {
  #expect(MiniMetalView.framesPerSecond(active: true, base: 30) == 30)
  #expect(MiniMetalView.framesPerSecond(active: false, base: 30) == 15)
  #expect(MiniMetalView.framesPerSecond(active: false, base: 60) == 30)
  #expect(MiniMetalView.framesPerSecond(active: false, base: 12) == 10)
  // Focus no longer matters: only a hidden window, or no request for motion, pauses drawing.
  #expect(!MiniMetalView.shouldPause(wantsAnimation: true, windowVisible: true))
  #expect(MiniMetalView.shouldPause(wantsAnimation: true, windowVisible: false))
  #expect(MiniMetalView.shouldPause(wantsAnimation: false, windowVisible: true))
}

@Test func animationClockNeverFreezesOnLongRunningDesks() {
  let frame = 1.0 / 30
  let wrapped = AnimationClock.advance(AnimationClock.period - 0.01, by: frame)
  #expect(wrapped > 0 && wrapped < frame)
  #expect(AnimationClock.advance(0, by: 20 * 86_400 + 0.5) < AnimationClock.period)
  #expect(AnimationClock.advance(5, by: -1) == 5)
  // The largest value a shader ever receives still resolves individual 30 fps frames.
  let latest = Float(AnimationClock.period - frame)
  #expect(latest.nextUp - latest < Float(frame))
  #expect(
    Float(AnimationClock.advance(AnimationClock.period - 2 * frame, by: frame))
      > Float(AnimationClock.period - 2 * frame))
}
