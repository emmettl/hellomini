import Foundation
import MiniCore
import MiniUI
import Observation
import SwiftUI

@MainActor @Observable final class AlarmModel {
  private(set) var deadline: Date?
  private(set) var ringing = false
  private(set) var label = "Timer"
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let onAlarm: () -> Void
  init(defaults: UserDefaults = .standard, onAlarm: @escaping () -> Void = {}) {
    self.defaults = defaults
    self.onAlarm = onAlarm
    deadline = defaults.object(forKey: "alarm.deadline") as? Date
    ringing = defaults.bool(forKey: "alarm.ringing")
    label = defaults.string(forKey: "alarm.label") ?? "Timer"
  }
  func start(minutes: Int, label: String, now: Date = .now) {
    guard (1...1440).contains(minutes) else { return }
    self.label = label
    ringing = false
    deadline = now.addingTimeInterval(Double(minutes) * 60)
    save()
  }
  func tick(now: Date = .now) {
    guard let deadline, now >= deadline else { return }
    self.deadline = nil
    ringing = true
    save()
    onAlarm()
  }
  func dismiss() {
    ringing = false
    save()
  }
  func cancel() {
    deadline = nil
    ringing = false
    save()
  }
  func remaining(now: Date) -> String {
    let seconds = max(0, Int(ceil((deadline ?? now).timeIntervalSince(now))))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
  }
  private func save() {
    defaults.set(deadline, forKey: "alarm.deadline")
    defaults.set(ringing, forKey: "alarm.ringing")
    defaults.set(label, forKey: "alarm.label")
  }
}

@MainActor public final class AlarmClockApplication: MiniApplication {
  public let id = "alarm-clock"
  public let name = "Alarm Clock"
  public let icon = MiniApplicationIcon.clock
  public let defaultSize = CGSize(width: 380, height: 330)
  private let model: AlarmModel
  public init(onAlarm: @escaping () -> Void = {}) { model = AlarmModel(onAlarm: onAlarm) }
  public func tick() { model.tick() }
  public var status: MiniApplicationStatus? {
    guard model.ringing || model.deadline != nil else { return nil }
    return MiniApplicationStatus(
      symbol: model.ringing ? "alarm.fill" : "alarm",
      message: model.ringing ? model.label + " finished" : model.label + " running",
      attention: model.ringing)
  }
  public func content() -> AnyView { AnyView(AlarmClockView(model: model)) }
}

private struct AlarmClockView: View {
  @Environment(\.miniTheme) private var theme
  let model: AlarmModel
  @State private var minutes = 10
  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      VStack(spacing: 14) {
        Text(model.ringing ? model.label + " finished!" : model.label).font(theme.typography.title)
        Text(
          model.ringing
            ? "Time’s up." : model.deadline == nil ? "Ready." : model.remaining(now: context.date)
        )
        .font(theme.typography.display(32)).monospacedDigit()
        HStack {
          TextField("Minutes", value: $minutes, format: .number).frame(width: 65)
            .accessibilityLabel("Timer minutes, 1 to 1440")
          Text("minutes")
          Button("Start") { model.start(minutes: minutes, label: "Timer") }
            .disabled(!(1...1440).contains(minutes))
        }
        HStack {
          Button("Pomodoro · 25m") { model.start(minutes: 25, label: "Focus session") }
          Button("Break · 5m") { model.start(minutes: 5, label: "Break") }
        }
        HStack {
          Button("Cancel") { model.cancel() }.disabled(model.deadline == nil && !model.ringing)
          if model.ringing { Button("Dismiss alarm") { model.dismiss() } }
        }
        Text(
          "Timers continue with this window closed. Sleep counts toward the timer; overdue alarms fire on wake or next launch. Start each focus session or break when ready."
        )
        .font(theme.typography.small).fixedSize(horizontal: false, vertical: true)
      }.buttonStyle(RetroButtonStyle()).padding(16)
    }
  }
}
