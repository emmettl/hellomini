import AppKit
import MiniCore
import SwiftUI

struct DesktopPictureCapture: NSViewRepresentable {
  let picture: DesktopPicture
  func makeNSView(context: Context) -> NSView { NSView() }
  func updateNSView(_ view: NSView, context: Context) {
    picture.capture = { [weak view] in
      guard NSEvent.pressedMouseButtons == 0,
        let window = view?.window, window.occlusionState.contains(.visible),
        let content = window.contentView, !content.inLiveResize, content.bounds.width > 0
      else { return nil }
      return autoreleasepool {
        guard let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) else {
          return nil
        }
        content.cacheDisplay(in: content.bounds, to: bitmap)
        return bitmap.cgImage
      }
    }
  }
}
