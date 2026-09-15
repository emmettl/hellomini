import AppKit

/// Original PCM tones, played through the normal output so macOS volume and mute apply.
@MainActor public final class SystemSounds {
  public static let effect = MiniPlayfulEffect(
    id: "system.sounds", name: "System sounds",
    description:
      "Original chimes for startup, paper jams, fish food, alarms, and emptying the basket.")
  public enum Cue: CaseIterable, Sendable { case startup, jam, feed, wastebasket, alarm }
  private let settings: PlayfulnessSettings
  private var playing: NSSound?
  private var lastPlayed = Date.distantPast
  public init(settings: PlayfulnessSettings) { self.settings = settings }
  public func play(_ cue: Cue) {
    guard settings.allows(Self.effect.id), Date.now.timeIntervalSince(lastPlayed) > 0.2 else {
      return
    }
    lastPlayed = .now
    playing?.stop()
    playing = NSSound(data: Self.wave(cue))
    playing?.play()
  }
  public func stopIfDisabled() {
    if !settings.allows(Self.effect.id) { playing?.stop() }
  }
  public nonisolated static func wave(_ cue: Cue) -> Data {
    let notes: [Double]
    switch cue {
    case .startup: notes = [262, 330, 392, 523]
    case .jam: notes = [196, 185, 131]
    case .feed: notes = [659, 880]
    case .wastebasket: notes = [330, 247, 165, 82]
    case .alarm: notes = [523, 784, 523, 784]
    }
    let rate = 22050
    let length = rate / 7
    var pcm = Data()
    for frequency in notes {
      for i in 0..<length {
        let t = Double(i) / Double(rate)
        let envelope = min(1, Double(i) / 150) * pow(1 - Double(i) / Double(length), 2)
        let value = Int16(sin(2 * .pi * frequency * t) * envelope * 7000)
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { pcm.append(contentsOf: $0) }
      }
    }
    var result = Data("RIFF".utf8)
    func append<T: FixedWidthInteger>(_ value: T) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { result.append(contentsOf: $0) }
    }
    append(UInt32(pcm.count + 36))
    result.append(Data("WAVEfmt ".utf8))
    append(UInt32(16))
    append(UInt16(1))
    append(UInt16(1))
    append(UInt32(rate))
    append(UInt32(rate * 2))
    append(UInt16(2))
    append(UInt16(16))
    result.append(Data("data".utf8))
    append(UInt32(pcm.count))
    result.append(pcm)
    return result
  }
}

public enum DesktopEffects {
  public static let genie = MiniPlayfulEffect(
    id: "desktop.genie", name: "Genie minimise",
    description: "Pour Aqua windows into the dock when they are minimised, and back out again.")
  public static let dockLaunchBounce = MiniPlayfulEffect(
    id: "desktop.dockLaunchBounce", name: "Dock launch bounce",
    description: "Give newly opened Aqua applications two little hops in the dock.")
  public static let menuBlink = MiniPlayfulEffect(
    id: "desktop.menuBlink", name: "Menu command blink",
    description: "Flash chosen System 7 commands three times before closing the menu.")
  public static let dockMagnification = MiniPlayfulEffect(
    id: "desktop.dockMagnification", name: "Dock magnification",
    description: "Enlarge Aqua dock icons as the pointer passes over them.")
}
