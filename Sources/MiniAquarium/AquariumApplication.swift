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
  public let minimumSize = CGSize(width: 480, height: 320)
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
  public static let effects = [animation, activity, buildFeeding]
  let model = AquariumModel()
  private let playfulness: PlayfulnessSettings

  public init(playfulness: PlayfulnessSettings) { self.playfulness = playfulness }
  public func feedFromSuccessfulBuilds(_ count: Int) {
    guard count > 0, playfulness.allows(Self.buildFeeding.id) else { return }
    model.feedFromBuilds(count)
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
  @ObservationIgnored var presentation: AquariumPresentation?

  func feed() {
    feedRevision += 1
    feedingNote = nil
  }
  func feedFromBuilds(_ count: Int) {
    feedRevision += 1
    feedingNote =
      count == 1 ? "A build passed. Lunch is served." : "\(count) builds passed. Lunch is served."
  }
}

/// Only the renderer advances this clock. Pauses and hidden windows never accumulate catch-up time.
struct AquariumSimulation {
  var time: Float = 0
  var foodAge: Float = 20
  var lastFeed = 0
  var previousTime: TimeInterval?
  var current: Float = 0
  var bubbles: Float = 0

  mutating func advance(
    now: TimeInterval, animate: Bool, feedRevision: Int,
    activity: AquariumActivity = AquariumActivity()
  ) {
    if lastFeed != feedRevision {
      foodAge = 0
      lastFeed = feedRevision
    }
    if animate, let previousTime {
      let delta = Float(max(0, min(0.1, now - previousTime)))
      time += delta
      foodAge = min(20, foodAge + delta)
      current += (activity.current - current) * min(1, delta * 2)
      bubbles += (activity.bubbles - bubbles) * min(1, delta * 2)
    }
    previousTime = animate ? now : nil
  }
}

struct AquariumView: View {
  @Environment(\.miniTheme) private var theme
  let model: AquariumModel
  let playfulness: PlayfulnessSettings

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button(model.paused ? "Resume" : "Pause") { model.paused.toggle() }
        Button("Feed fish", action: model.feed)
        Spacer()
        Button("Screensaver preview") {
          model.presentation = AquariumPresentation()
          model.presentation?.show(model: model, playfulness: playfulness, theme: theme)
        }
      }
      .buttonStyle(RetroButtonStyle()).padding(10)
      Rectangle().frame(height: 1)
      AquariumTank(model: model, playfulness: playfulness, suspended: model.presenting)
      Rectangle().frame(height: 1)
      HStack {
        Text(model.feedingNote ?? "NINE FISH. NO RESPONSIBILITIES.").lineLimit(1)
          .help(model.feedingNote ?? "Nine fish. No responsibilities.")
        Spacer(minLength: 8)
        Text(playfulness.allows(AquariumApplication.activity.id) ? "System currents" : "Decorative")
      }.font(theme.typography.small).padding(.horizontal, 10).frame(height: 28)
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
  @State private var active = NSApp.isActive

  private var animate: Bool {
    active && visible && !suspended && !model.paused && !reduceMotion
      && playfulness.allows(AquariumApplication.animation.id)
  }
  private var sample: Bool {
    active && visible && !suspended && model.error == nil
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
            ? model.activity : AquariumActivity(), feedRevision: model.feedRevision)
      }
      Text(status).font(theme.typography.small)
        .padding(6).background(theme.paper).padding(8).allowsHitTesting(false)
    }
    .clipped()
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    {
      _ in active = true
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification))
    {
      _ in active = false
    }
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
