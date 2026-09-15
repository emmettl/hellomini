import AVFoundation
import MiniCore
import MiniUI
import Observation
import SwiftUI

/// A moose with opinions about continuous integration. Silent unless enabled in Playfulness.
@MainActor @Observable public final class TalkingMoose {
  public static let effect = MiniPlayfulEffect(
    id: "moose.talking", name: "Talking Moose",
    description: "A moose pops up to comment on your builds, out loud. Off by default, obviously.",
    enabledByDefault: false)
  public enum Event: Sendable, Equatable {
    case passed(Int)
    case failed(Int)
  }
  /// Remarks are rationed so a busy CI day does not become a monologue.
  public static let quietInterval: TimeInterval = 20
  public static let displayDuration: Duration = .seconds(6)

  public private(set) var remark: String?
  @ObservationIgnored private let settings: PlayfulnessSettings
  @ObservationIgnored private let speak: @MainActor (String) -> Void
  @ObservationIgnored private let silence: @MainActor () -> Void
  @ObservationIgnored private let now: () -> Date
  @ObservationIgnored private let pick: (Int) -> Int
  @ObservationIgnored private var lastRemark = Date.distantPast
  @ObservationIgnored private var dismissal: Task<Void, Never>?

  public init(
    settings: PlayfulnessSettings, speak: (@MainActor (String) -> Void)? = nil,
    now: @escaping () -> Date = Date.init, pick: @escaping (Int) -> Int = { Int.random(in: 0..<$0) }
  ) {
    self.settings = settings
    self.now = now
    self.pick = pick
    if let speak {
      self.speak = speak
      silence = {}
    } else {
      let voice = MooseVoice()
      self.speak = { voice.say($0) }
      silence = { voice.stop() }
    }
  }

  public func react(to event: Event) {
    guard settings.allows(Self.effect.id), now().timeIntervalSince(lastRemark) >= Self.quietInterval
    else { return }
    let line = Self.line(for: event, pick: pick)
    lastRemark = now()
    remark = line
    speak(line)
    dismissal?.cancel()
    dismissal = Task { [weak self] in
      try? await Task.sleep(for: Self.displayDuration)
      guard !Task.isCancelled else { return }
      self?.remark = nil
    }
  }

  public func dismiss() {
    dismissal?.cancel()
    remark = nil
    silence()
  }

  nonisolated static func line(for event: Event, pick: (Int) -> Int) -> String {
    let lines: [String]
    switch event {
    case .failed(let count) where count > 1:
      lines = [
        "\(count) builds failed. I'll fetch the tissues.",
        "\(count) failures at once. Efficient, at least.",
      ]
    case .failed:
      lines = [
        "Your build failed. Again.", "The printer has jammed. I blame the compiler.",
        "That build failed. Have you tried turning it off and on again?",
        "Red again. Very festive.",
      ]
    case .passed(let count) where count > 1:
      lines = [
        "\(count) builds passed. Suspicious.", "\(count) green builds. Somebody tell the fish.",
      ]
    case .passed:
      lines = [
        "A build passed. Don't let it go to your head.", "Green. How unusual.",
        "It compiled. I'm as surprised as you are.", "Build passed. The fish send their regards.",
      ]
    }
    return lines[min(max(0, pick(lines.count)), lines.count - 1)]
  }
}

@MainActor private final class MooseVoice {
  private let synthesizer = AVSpeechSynthesizer()
  func say(_ line: String) {
    synthesizer.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: line)
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    utterance.pitchMultiplier = 0.7
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
    synthesizer.speak(utterance)
  }
  func stop() { synthesizer.stopSpeaking(at: .immediate) }
}

/// Peeks up from the bottom-left corner of the desktop while the moose has something to say.
public struct TalkingMooseOverlay: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let moose: TalkingMoose
  public init(moose: TalkingMoose) { self.moose = moose }

  public var body: some View {
    ZStack(alignment: .bottomLeading) {
      if let remark = moose.remark {
        HStack(alignment: .bottom, spacing: 4) {
          MooseArt().frame(width: 64, height: 52)
            .padding(6).background(theme.paper, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.ink, lineWidth: 2))
          Text(remark).font(theme.typography.body)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 240, alignment: .leading)
            .padding(10)
            .background(theme.paper, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(theme.ink, lineWidth: 2))
            .padding(.bottom, 40)
        }
        .foregroundStyle(theme.ink)
        .padding(.leading, 14).padding(.bottom, 12)
        .contentShape(Rectangle())
        .onTapGesture { moose.dismiss() }
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Talking Moose says: \(remark)")
        .accessibilityAction(named: "Dismiss") { moose.dismiss() }
        .miniHelp("Click the moose to send it away.")
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    .animation(reduceMotion ? nil : .spring(duration: 0.45), value: moose.remark)
  }
}

/// Original pixel artwork: a moose, antlers first.
private struct MooseArt: View {
  @Environment(\.miniTheme) private var theme
  private static let rows = [
    "#  #        #  #",
    "## ##      ## ##",
    " #####    ##### ",
    "   ###    ###   ",
    "     ######     ",
    "    ########    ",
    "   ##.####.##   ",
    "   ##########   ",
    "    ########    ",
    "     ######     ",
    "     ##..##     ",
    "     ######     ",
    "      ####      ",
  ]
  var body: some View {
    Canvas { context, size in
      let scale = min(size.width / 16, size.height / CGFloat(Self.rows.count))
      for (y, row) in Self.rows.enumerated() {
        for (x, pixel) in row.enumerated() where pixel != " " {
          let rect = CGRect(
            x: CGFloat(x) * scale, y: CGFloat(y) * scale, width: scale, height: scale)
          context.fill(Path(rect), with: .color(pixel == "#" ? theme.ink : theme.paper))
        }
      }
    }
    .accessibilityHidden(true)
  }
}
