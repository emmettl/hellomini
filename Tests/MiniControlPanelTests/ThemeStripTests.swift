import CoreGraphics
import Testing

@testable import MiniControlPanel

@Test func themeStripScrollbarMapsOffsetsToTheThumbAndBack() {
  let start = StripScrollMetrics(offset: 0, content: 1000, visible: 250)
  #expect(start.maxOffset == 750 && start.overflows)
  #expect(start.thumb(track: 200).x == 0 && start.thumb(track: 200).width == 50)
  var end = start
  end.offset = 750
  #expect(end.thumb(track: 200).x == 150)
  // Dragging the thumb across its travel moves the strip across its whole scroll range.
  #expect(start.offset(from: 0, dragging: 75, track: 200) == 375)
  #expect(start.offset(from: 700, dragging: 500, track: 200) == 750)
  #expect(start.clamp(-20) == 0)
  let fits = StripScrollMetrics(offset: 0, content: 200, visible: 250)
  #expect(!fits.overflows && fits.thumb(track: 120).width == 120)
  let narrow = StripScrollMetrics(offset: 0, content: 10_000, visible: 100)
  #expect(narrow.thumb(track: 100).width == 24)
}
