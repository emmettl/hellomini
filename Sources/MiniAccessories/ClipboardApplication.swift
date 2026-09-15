import AppKit
import MiniCore
import MiniUI
import SwiftUI

@MainActor public final class ClipboardApplication: MiniApplication {
  public let id = "clipboard"
  public let name = "Clipboard"
  public let icon = MiniApplicationIcon.scrapbook
  public let defaultSize = CGSize(width: 480, height: 340)
  public let minimumSize = CGSize(width: 320, height: 200)
  public init() {}
  public func content() -> AnyView { AnyView(ClipboardView()) }
}

private struct ClipboardView: View {
  @Environment(\.miniTheme) private var theme
  @State private var text = ""
  @State private var image: NSImage?
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Clipboard").font(theme.typography.title)
        Spacer()
        Button("Refresh", action: refresh).buttonStyle(RetroButtonStyle())
      }
      ScrollView {
        if let image {
          Image(nsImage: image).resizable().scaledToFit()
        } else {
          Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      Text("A snapshot of copied text or an image. Refresh to read the clipboard again.")
        .font(theme.typography.small)
    }.padding(16).onAppear(perform: refresh)
  }
  private func refresh() {
    let board = NSPasteboard.general
    image = nil
    if let value = board.string(forType: .string) {
      text = String(value.prefix(100_000)) + (value.count > 100_000 ? "\n[Preview truncated]" : "")
    } else if let data = board.data(forType: .png) ?? board.data(forType: .tiff),
      data.count <= 25_000_000
    {
      image = NSImage(data: data)
      text = image == nil ? "This image could not be displayed." : ""
    } else {
      text = "No supported text or image on the clipboard."
    }
  }
}
