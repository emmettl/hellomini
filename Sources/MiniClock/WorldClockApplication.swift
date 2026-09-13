import Foundation
import MiniCore
import MiniUI
import Observation
import SwiftUI

@MainActor public final class WorldClockApplication: MiniApplication {
  public let id = "world-clock"
  public let name = "World Clock"
  public let icon = MiniApplicationIcon.clock
  public let defaultSize = CGSize(width: 730, height: 480)
  public let minimumSize = CGSize(width: 630, height: 400)
  public static let effect = MiniPlayfulEffect(
    id: "clock.globe", name: "World Clock globe",
    description: "Spin a needlessly elaborate globe beside the clocks.")
  private let model = WorldClockModel()
  private let playfulness: PlayfulnessSettings
  public init(playfulness: PlayfulnessSettings) { self.playfulness = playfulness }
  public func content() -> AnyView {
    AnyView(WorldClockView(model: model, playfulness: playfulness))
  }
}

@MainActor @Observable final class WorldClockModel {
  private(set) var zones: [String]
  var startHour: Int { didSet { defaults.set(startHour, forKey: "worldClock.startHour") } }
  var endHour: Int { didSet { defaults.set(endHour, forKey: "worldClock.endHour") } }
  @ObservationIgnored private let defaults: UserDefaults
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let saved =
      defaults.stringArray(forKey: "worldClock.zones")
      ?? [TimeZone.current.identifier, "Europe/London", "America/New_York", "Asia/Tokyo"]
    var seen = Set<String>()
    zones = saved.filter { TimeZone(identifier: $0) != nil && seen.insert($0).inserted }
    let start = min(23, max(0, defaults.object(forKey: "worldClock.startHour") as? Int ?? 9))
    startHour = start
    endHour = min(
      24, max(start + 1, defaults.object(forKey: "worldClock.endHour") as? Int ?? 17))
  }
  func add(_ zone: String) {
    guard TimeZone(identifier: zone) != nil, !zones.contains(zone) else { return }
    zones.append(zone)
    persist()
  }
  func remove(_ zone: String) {
    zones.removeAll { $0 == zone }
    persist()
  }
  private func persist() { defaults.set(zones, forKey: "worldClock.zones") }
  static func working(_ date: Date, zone: TimeZone, start: Int, end: Int) -> Bool {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    let weekday = calendar.component(.weekday, from: date)
    let hour = calendar.component(.hour, from: date)
    return (2...6).contains(weekday) && hour >= start && hour < end
  }
}

private struct WorldClockView: View {
  @Environment(\.miniTheme) private var theme
  @Bindable var model: WorldClockModel
  let playfulness: PlayfulnessSettings
  @State private var offset: Double = 0
  @State private var adding = false
  @State private var query = ""
  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Button("Add clock…") { adding = true }
        Spacer()
        Text("Working hours")
        Picker("Start hour", selection: $model.startHour) {
          ForEach(0..<24) { Text(String(format: "%02d:00", $0)).tag($0) }
        }.labelsHidden().frame(width: 85)
        Text("to")
        Picker("End hour", selection: $model.endHour) {
          ForEach((model.startHour + 1)...24, id: \.self) {
            Text(String(format: "%02d:00", $0)).tag($0)
          }
        }.labelsHidden().frame(width: 85)
      }.buttonStyle(RetroButtonStyle())
        .onChange(of: model.startHour) { _, start in
          if model.endHour <= start { model.endHour = start + 1 }
        }
      HStack {
        Text(offset == 0 ? "Now" : String(format: "%+.0f hours", offset)).frame(width: 85)
        Slider(value: $offset, in: -12...36, step: 1).accessibilityLabel(
          "Preview time offset in hours")
        Button("Now") { offset = 0 }.buttonStyle(RetroButtonStyle())
      }
      Rectangle().frame(height: 1)
      HStack(spacing: 16) {
        TimelineView(.periodic(from: .now, by: 1)) { context in
          let date = context.date.addingTimeInterval(offset * 3600)
          ScrollView {
            VStack(alignment: .leading, spacing: 14) {
              ForEach(model.zones, id: \.self) { id in
                if let zone = TimeZone(identifier: id) {
                  VStack(alignment: .leading, spacing: 4) {
                    HStack {
                      Text(id.replacingOccurrences(of: "_", with: " ")).font(theme.typography.title)
                        .lineLimit(1)
                      Spacer()
                      Button("×") { model.remove(id) }.buttonStyle(.plain).accessibilityLabel(
                        "Remove \(id) clock")
                    }
                    HStack {
                      Text(
                        date.formatted(
                          Date.FormatStyle(
                            date: .omitted, time: .standard, locale: Locale(identifier: "en_GB"),
                            timeZone: zone))
                      )
                      .font(theme.typography.display(24)).monospacedDigit()
                      Spacer()
                      Text(
                        WorldClockModel.working(
                          date, zone: zone, start: model.startHour, end: model.endHour)
                          ? "At work" : "Off duty"
                      )
                      .font(theme.typography.small)
                    }
                    Text(
                      date.formatted(
                        Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: zone))
                        + " · " + (zone.abbreviation(for: date) ?? id)
                    )
                    .font(theme.typography.small)
                  }
                  Rectangle().frame(height: 1)
                }
              }
              if model.zones.isEmpty { Text("Add a clock for somewhere you'd like to be.") }
            }
          }
        }.frame(maxWidth: .infinity)
        VStack {
          MiniMetalScene(.globe, animate: playfulness.allows(WorldClockApplication.effect.id))
          Text("Decorative globe.\nActual timekeeping above its pay grade.").font(
            theme.typography.small
          ).multilineTextAlignment(.center)
        }.frame(width: 210)
      }
      TimelineView(.periodic(from: .now, by: 60)) { _ in
        Text(
          "Working hours: Monday–Friday in each time zone · Mac uptime: \(Int(ProcessInfo.processInfo.systemUptime / 3600)) hours"
        ).font(theme.typography.small)
      }
    }.padding(16)
      .sheet(isPresented: $adding) {
        VStack(alignment: .leading, spacing: 12) {
          Text("Somewhere on this ridiculous planet.").font(theme.typography.title)
          TextField("Find a time zone", text: $query).accessibilityLabel("Find time zone")
          ScrollView {
            LazyVStack(alignment: .leading) {
              ForEach(
                TimeZone.knownTimeZoneIdentifiers.filter {
                  query.isEmpty || $0.localizedCaseInsensitiveContains(query)
                }, id: \.self
              ) { id in
                Button(id.replacingOccurrences(of: "_", with: " ")) {
                  model.add(id)
                  adding = false
                  query = ""
                }
                .disabled(model.zones.contains(id)).buttonStyle(.plain).padding(.vertical, 3)
              }
            }
          }
          Button("Done") { adding = false }.buttonStyle(RetroButtonStyle())
        }.padding(20).frame(width: 450, height: 380).foregroundStyle(theme.ink).background(
          theme.paper
        )
        .miniSheet(width: 450)
      }
  }
}
