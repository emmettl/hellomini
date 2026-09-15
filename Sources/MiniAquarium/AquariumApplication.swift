import AppKit
import MiniCore
import MiniUI
import Observation
import SwiftUI

@MainActor public final class AquariumApplication: MiniApplication {
  public let id = "aquarium"
  public let name = "Aquarium"
  public let icon = MiniApplicationIcon.aquarium
  public let defaultSize = CGSize(width: 660, height: 440)
  public let minimumSize = CGSize(width: 420, height: 220)
  public static let animation = MiniPlayfulEffect(
    id: "aquarium.animation", name: "Aquarium animation",
    description: "Let fish wander, plants sway, and bubbles rise.")
  public static let activity = MiniPlayfulEffect(
    id: "aquarium.activity", name: "Reflect system activity",
    description: "Aquarium currents follow CPU use; Ethernet and Wi-Fi traffic add bubbles.",
    enabledByDefault: false)
  public static let buildFeeding = MiniPlayfulEffect(
    id: "aquarium.buildFeeding", name: "Feed fish after successful builds",
    description:
      "Print Monitor drops food when newly observed CI builds succeed. Old build history is ignored."
  )
  public static let buildMemory = MiniPlayfulEffect(
    id: "aquarium.buildMemory", name: "Fish remember builds",
    description:
      "Green build streaks grow the fish and bring a tenth resident. A failed build sends them sulking to the gravel."
  )
  public static let effects = [animation, activity, buildFeeding, buildMemory]
  let model: AquariumModel
  private let playfulness: PlayfulnessSettings

  public init(
    playfulness: PlayfulnessSettings, preview: (() -> Void)? = nil,
    onFeed: @escaping () -> Void = {}, defaults: UserDefaults = .standard
  ) {
    model = AquariumModel(defaults: defaults)
    self.playfulness = playfulness
    model.preview = preview
    model.onFeed = onFeed
  }
  public static let screensaver = MiniScreensaver(
    id: "aquarium", name: "Aquarium",
    description: "Nine fish. An entire screen. No responsibilities.")
  public func screensaverContent() -> AnyView {
    AnyView(AquariumTank(model: model, playfulness: playfulness))
  }
  public func setScreensaverPresented(_ presented: Bool) {
    model.presenting = presented
    model.simulation.previousTime = nil
  }
  public func feedFromSuccessfulBuilds(_ count: Int) {
    guard count > 0 else { return }
    if playfulness.allows(Self.buildMemory.id) { model.rememberSuccess(count) }
    guard playfulness.allows(Self.buildFeeding.id) else { return }
    model.feedFromBuilds(count)
  }
  public func recordFailedBuilds(_ count: Int) {
    guard count > 0, playfulness.allows(Self.buildMemory.id) else { return }
    model.rememberFailure()
  }
  public func content() -> AnyView {
    AnyView(AquariumView(model: model, playfulness: playfulness))
  }
  public var menus: [RetroMenu] {
    [
      RetroMenu(
        id: "aquarium", title: "Aquarium",
        items: [
          RetroMenuItem(
            id: "pause-fish", title: model.paused ? "Resume Swimming" : "Pause Swimming",
            shortcut: RetroShortcut(key: "p", label: "⌘P")
          ) { self.model.paused.toggle() },
          RetroMenuItem(id: "feed-fish", title: "Feed Fish", action: model.feed),
          RetroMenuItem(
            id: "fish-activity", title: "Reflect System Activity",
            enabled: playfulness.enabled, checked: playfulness.isSelected(Self.activity.id)
          ) {
            self.playfulness.setSelected(
              !self.playfulness.isSelected(Self.activity.id), for: Self.activity.id)
          },
        ])
    ]
  }
}

@MainActor @Observable final class AquariumModel {
  var paused = false
  var feedRevision = 0
  var feedingNote: String?
  var error: String?
  var activity = AquariumActivity()
  var presenting = false
  let sampler = AquariumSampler()
  @ObservationIgnored var simulation = AquariumSimulation()
  @ObservationIgnored var preview: (() -> Void)?

  @ObservationIgnored var onFeed: () -> Void = {}
  private(set) var streak: Int
  private(set) var sulking: Bool
  @ObservationIgnored private let defaults: UserDefaults
  static let streakKey = "aquarium.buildStreak"
  static let sulkingKey = "aquarium.sulking"
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    streak = min(999, max(0, defaults.integer(forKey: Self.streakKey)))
    sulking = defaults.bool(forKey: Self.sulkingKey)
  }
  /// Ten green builds in a row reach full size; five bring a tenth fish.
  var growth: Float { Float(min(streak, 10)) / 10 }
  var residents: Int { streak >= 5 ? 10 : 9 }
  var moodNote: String? {
    if sulking { return "A build failed. The fish are sulking." }
    return streak >= 2 ? "\(streak) green builds in a row. The fish are thriving." : nil
  }
  func rememberSuccess(_ count: Int) {
    streak = min(999, streak + count)
    sulking = false
    saveMemory()
  }
  func rememberFailure() {
    streak = 0
    sulking = true
    saveMemory()
  }
  private func saveMemory() {
    defaults.set(streak, forKey: Self.streakKey)
    defaults.set(sulking, forKey: Self.sulkingKey)
  }
  func feed() {
    onFeed()
    feedRevision += 1
    feedingNote = nil
  }
  func feedFromBuilds(_ count: Int) {
    onFeed()
    feedRevision += 1
    feedingNote =
      count == 1 ? "A build passed. Lunch is served." : "\(count) builds passed. Lunch is served."
  }
}

/// Only the renderer advances this clock. Pauses and hidden windows never accumulate catch-up time.
/// It wraps once a day so long-running tanks keep swimming.
struct AquariumSimulation {
  var time: Double = 0
  var foodAge: Float = 20
  var lastFeed = 0
  var previousTime: TimeInterval?
  var current: Float = 0
  var bubbles: Float = 0
  var sulk: Float = 0

  mutating func advance(
    now: TimeInterval, animate: Bool, feedRevision: Int,
    activity: AquariumActivity = AquariumActivity(), sulking: Bool = false
  ) {
    if lastFeed != feedRevision {
      foodAge = 0
      lastFeed = feedRevision
    }
    if animate, let previousTime {
      let delta = Float(max(0, min(0.1, now - previousTime)))
      time = AnimationClock.advance(time, by: Double(delta))
      foodAge = min(20, foodAge + delta)
      current += (activity.current - current) * min(1, delta * 2)
      bubbles += (activity.bubbles - bubbles) * min(1, delta * 2)
      sulk += ((sulking ? 1 : 0) - sulk) * min(1, delta * 1.2)
    }
    if !animate { sulk = sulking ? 1 : 0 }
    previousTime = animate ? now : nil
  }
}

struct AquariumView: View {
  @Environment(\.miniTheme) private var theme
  let model: AquariumModel
  let playfulness: PlayfulnessSettings

  var body: some View {
    VStack(spacing: 0) {
      ViewThatFits(in: .horizontal) {
        controls(short: false)
        controls(short: true)
      }
      .buttonStyle(RetroButtonStyle()).padding(10)
      Rectangle().frame(height: 1)
      AquariumTank(model: model, playfulness: playfulness, suspended: model.presenting)
      Rectangle().frame(height: 1)
      HStack {
        Text(note).lineLimit(1).miniHelp(note)
        Spacer(minLength: 8)
        Text(playfulness.allows(AquariumApplication.activity.id) ? "System currents" : "Decorative")
      }.font(theme.typography.small).padding(.horizontal, 10).frame(height: 28)
    }
  }

  private var note: String {
    if let feeding = model.feedingNote { return feeding }
    guard playfulness.allows(AquariumApplication.buildMemory.id) else {
      return "NINE FISH. NO RESPONSIBILITIES."
    }
    return model.moodNote
      ?? (model.residents == 10
        ? "TEN FISH. ONE OF THEM IS NEW." : "NINE FISH. NO RESPONSIBILITIES.")
  }

  private func controls(short: Bool) -> some View {
    HStack {
      Button(model.paused ? "Resume" : "Pause") { model.paused.toggle() }
      Button("Feed fish", action: model.feed)
      Spacer(minLength: 4)
      Button(short ? "Preview" : "Screensaver preview") {
        model.preview?()
      }
      .disabled(model.preview == nil || !playfulness.enabled)
      .accessibilityLabel("Screensaver preview")
    }
  }
}

struct AquariumTank: View {
  @Environment(\.miniWindowVisible) private var visible
  @Environment(\.miniTheme) private var theme
  @Environment(\.self) private var environment
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let model: AquariumModel
  let playfulness: PlayfulnessSettings
  var suspended = false

  private var animate: Bool {
    visible && !suspended && !model.paused && !reduceMotion
      && playfulness.allows(AquariumApplication.animation.id)
  }
  private var remembers: Bool { playfulness.allows(AquariumApplication.buildMemory.id) }
  private var sample: Bool {
    visible && !suspended && model.error == nil
      && playfulness.allows(AquariumApplication.activity.id)
  }
  private var status: String {
    if reduceMotion { return "Reduced motion · a moment of stillness" }
    if !playfulness.allows(AquariumApplication.animation.id) {
      return "Animation off in Control Panel"
    }
    if model.paused { return "Swimming paused" }
    if playfulness.allows(AquariumApplication.activity.id) {
      let cpu = model.activity.cpu.map { "CPU \(Int($0 * 100))%" } ?? "CPU awaiting sample"
      let network =
        model.activity.bytesPerSecond.map {
          ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .decimal) + "/s"
        } ?? "network awaiting sample"
      return "\(cpu) · \(network)"
    }
    return "The fish have no deadlines."
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      if let error = model.error {
        VStack(spacing: 12) {
          PixelIcon(symbol: .aquarium)
          Text("The aquarium couldn't start.")
          Text(error).font(theme.typography.small)
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        AquariumMetalView(
          model: model, ink: rgba(theme.ink), paper: rgba(theme.paper), animate: animate,
          suspended: suspended,
          activity: playfulness.allows(AquariumApplication.activity.id)
            ? model.activity : AquariumActivity(), feedRevision: model.feedRevision,
          growth: remembers ? model.growth : 0, sulking: remembers && model.sulking)
      }
      Text(status).font(theme.typography.small)
        .padding(6).background(theme.paper).padding(8).allowsHitTesting(false)
    }
    .clipped()

    .task(id: sample) {
      guard sample else { return }
      await model.sampler.reset()
      model.activity = AquariumActivity()
      while !Task.isCancelled {
        let activity = await model.sampler.sample()
        guard !Task.isCancelled else { return }
        model.activity = activity
        do { try await Task.sleep(for: .seconds(2)) } catch { return }
      }
    }
  }

  private func rgba(_ color: Color) -> SIMD4<Float> {
    let resolved = color.resolve(in: environment)
    return SIMD4(resolved.red, resolved.green, resolved.blue, resolved.opacity)
  }
}
