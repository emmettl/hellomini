import SwiftUI

/// Keep an application's minimum layout reachable when the desktop is smaller than its window.
struct WindowContentLayout {
  let visible: CGSize
  let content: CGSize
  var scrollAxes: Axis.Set {
    var axes: Axis.Set = []
    if content.width > visible.width { axes.insert(.horizontal) }
    if content.height > visible.height { axes.insert(.vertical) }
    return axes
  }

  init(window: CGSize, minimum: CGSize, chromeHeight: CGFloat) {
    visible = CGSize(width: max(1, window.width), height: max(1, window.height - chromeHeight))
    content = CGSize(
      width: max(visible.width, minimum.width),
      height: max(visible.height, minimum.height - chromeHeight))
  }
}
