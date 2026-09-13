import MiniCore
import MiniUI
import SwiftUI

@MainActor public final class AboutApplication: MiniApplication {
  public let id = "about"
  public let name = "About Mini"
  public let icon = MiniApplicationIcon.computer
  public let defaultSize = CGSize(width: 320, height: 218)
  public init() {}

  public func content() -> AnyView {
    AnyView(AboutView())
  }
}

private struct AboutView: View {
  @Environment(\.miniTheme) private var theme
  var body: some View {
    VStack(spacing: 14) {
      HStack(spacing: 16) {
        PixelIcon(symbol: .computer, scale: 3)
        VStack(alignment: .leading, spacing: 4) {
          Text("Hello Mini").font(theme.typography.display(23))
          Text(version).font(theme.typography.small)
        }
      }
      Text("Inspired by 1984. Built for today.").font(theme.typography.small)
      Rectangle().frame(height: 1)
      Text(
        "\(ProcessInfo.processInfo.processorCount) cores · \(ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory)) memory"
      ).font(theme.typography.small)
    }.padding(18)
  }
  private var version: String {
    guard
      let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        as? String
    else {
      return "Development build"
    }
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    return "Version \(version) (\(build))"
  }
}
