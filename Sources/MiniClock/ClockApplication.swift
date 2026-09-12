import MiniCore
import MiniUI
import Observation
import SwiftUI

@MainActor public final class ClockApplication: MiniApplication {
  public let id = "clock"
  public let name = "Clock"
  public let icon = MiniApplicationIcon.clock
  public let defaultSize = CGSize(width: 340, height: 288)
  private let model = ClockModel()
  public init() {}
  public func content() -> AnyView { AnyView(ClockView(model: model)) }
  public var menus: [RetroMenu] {
    [
      RetroMenu(
        id: "clock", title: "Clock",
        items: [
          RetroMenuItem(id: "utc", title: "Show UTC", checked: model.utc) {
            self.model.utc.toggle()
          },
          .separator("stopwatch-divider"),
          RetroMenuItem(
            id: "start-stop", title: model.started == nil ? "Start Stopwatch" : "Stop Stopwatch"
          ) { self.model.toggle() },
          RetroMenuItem(id: "reset-watch", title: "Reset Stopwatch", action: model.reset),
        ])
    ]
  }
}

@MainActor @Observable private final class ClockModel {
  var utc = false
  var started: ContinuousClock.Instant?
  var accumulated: Duration = .zero

  func toggle() {
    if let started {
      accumulated += started.duration(to: .now)
      self.started = nil
    } else {
      started = .now
    }
  }

  func reset() {
    accumulated = .zero
    if started != nil { started = .now }
  }

  var elapsed: String {
    let duration = accumulated + (started?.duration(to: .now) ?? .zero)
    let seconds = max(0, duration.components.seconds)
    return String(format: "%02lld:%02lld:%02lld", seconds / 3600, (seconds / 60) % 60, seconds % 60)
  }
}

private struct ClockView: View {
  @Environment(\.miniTheme) private var theme
  @Bindable var model: ClockModel
  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      VStack(spacing: 12) {
        HStack {
          Text(model.utc ? "UTC" : TimeZone.current.identifier).font(theme.typography.small)
            .lineLimit(1)
          Spacer()
          Button(model.utc ? "Local" : "UTC") { model.utc.toggle() }.buttonStyle(RetroButtonStyle())
        }
        Text(
          context.date.formatted(
            Date.FormatStyle(
              date: .omitted, time: .standard, locale: Locale(identifier: "en_GB"),
              timeZone: model.utc ? .gmt : .current))
        )
        .font(theme.typography.display(36)).monospacedDigit()
        Text(
          context.date.formatted(
            Date.FormatStyle(date: .complete, time: .omitted, timeZone: model.utc ? .gmt : .current)
          )
        )
        .font(theme.typography.small)
        Rectangle().frame(height: 1)
        HStack {
          Text("STOPWATCH").font(theme.typography.small)
          Spacer()
          Text(model.elapsed).font(theme.typography.title).monospacedDigit()
        }
        HStack {
          Button(model.started == nil ? "Start" : "Stop", action: model.toggle)
          Button("Reset", action: model.reset)
        }.buttonStyle(RetroButtonStyle())
      }.padding(18)
    }
  }
}
