import AppKit
import Observation

/// The host supplies an image of its own content, never of other apps or displays.
@MainActor @Observable public final class DesktopPicture {
  public private(set) var image: CGImage?
  @ObservationIgnored public var capture: (() -> CGImage?)?
  public init() {}
  public func refresh() { if let image = capture?() { self.image = image } }
}

@MainActor @Observable public final class DesktopCommands {
  public var launchID: String?
  public init() {}
  public func launch(_ id: String) { launchID = id }
}
