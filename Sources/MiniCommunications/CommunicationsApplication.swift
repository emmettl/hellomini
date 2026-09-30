import MiniCore
import MiniUI
import SwiftUI

@MainActor public final class CommunicationsApplication: MiniApplication {
  public static let effect = MiniPlayfulEffect(
    id: "communications.instruments", name: "Communications instruments",
    description:
      "Animate the receiving station’s signal lamps and paper transport. Readings always remain visible."
  )
  public let id = "communications"
  public let name = "Communications"
  public let icon = MiniApplicationIcon.chooser
  public let defaultSize = CGSize(width: 720, height: 490)
  public let minimumSize = CGSize(width: 440, height: 250)
  private let model: StationModel
  private let playfulness: PlayfulnessSettings
  public init(
    playfulness: PlayfulnessSettings, defaults: UserDefaults = .standard,
    onSignalChange: @escaping @MainActor (Bool) -> Void = { _ in }
  ) {
    self.playfulness = playfulness
    model = StationModel(defaults: defaults, notify: onSignalChange)
  }
  public func refreshInBackground() async { await model.refresh() }
  public var status: MiniApplicationStatus? {
    guard model.isConnected else { return nil }
    return MiniApplicationStatus(
      symbol: "antenna.radiowaves.left.and.right",
      message: model.demo
        ? "Simulation"
        : model.attention ? "Attention required" : "Receiving",
      attention: !model.demo && model.attention)
  }
  public func content() -> AnyView {
    AnyView(CommunicationsView(model: model, playfulness: playfulness))
  }
  public var menus: [RetroMenu] {
    [
      RetroMenu(
        id: "station", title: "Station",
        items: [
          RetroMenuItem(id: "setup", title: "Station Setup…") { self.model.showSetup = true },
          RetroMenuItem(
            id: "connect",
            title: model.demo ? "End Simulation" : model.isConnected ? "Disconnect" : "Connect"
          ) {
            if self.model.isConnected { self.model.disconnect() } else { self.model.connect() }
          },
          RetroMenuItem(
            id: "refresh", title: "Receive Now", enabled: model.isConnected && !model.busy
          ) {
            Task { await self.model.refresh(force: true) }
          },
          RetroMenuItem(id: "test", title: "Test Lamps", action: model.testLamps),
          RetroMenuItem(
            id: "simulate", title: "Run Simulation", enabled: !model.demo, action: model.simulate),
          RetroMenuItem(id: "export", title: "Export Station…", action: model.exportConfiguration),
        ])
    ]
  }
}

private enum StationPage: String, CaseIterable {
  case switchboard = "Switchboard"
  case chart = "Chart"
  case log = "Log"
}

private struct CommunicationsView: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.miniWindowVisible) private var visible
  @Environment(\.miniDesktopSuspended) private var suspended
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Bindable var model: StationModel
  let playfulness: PlayfulnessSettings
  @State private var page = StationPage.switchboard
  private var moving: Bool {
    visible && !suspended && !reduceMotion
      && playfulness.allows(CommunicationsApplication.effect.id)
  }
  var body: some View {
    GeometryReader { geometry in contents(compact: geometry.size.height < 290) }
  }
  private func contents(compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: compact ? 4 : 7) {
      ViewThatFits(in: .horizontal) {
        controls(compact: false).fixedSize()
        controls(compact: true)
      }.buttonStyle(RetroButtonStyle()).fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 8) {
        Picker("Station view", selection: $page) {
          ForEach(StationPage.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented).labelsHidden()
        Button("Test Lamps", action: model.testLamps).buttonStyle(RetroButtonStyle())
          .help(
            "Illuminate every indicator for three seconds. Does not change real readings or send requests."
          )
      }.fixedSize(horizontal: false, vertical: true)
      TimelineView(.animation(minimumInterval: 1, paused: !visible || suspended)) { context in
        let testing = context.date < model.lampTestUntil
        VStack(alignment: .leading, spacing: 5) {
          HStack {
            Image(systemName: "antenna.radiowaves.left.and.right")
            Text(
              model.demo
                ? (compact ? "SIMULATION" : "SIMULATION · NO LIVE SIGNAL")
                : model.isConnected ? "RECEIVING STATION" : "RECEIVER OFF"
            )
            .font(theme.typography.small)
            Spacer(minLength: 2)
            if testing { Text("LAMP TEST").font(theme.typography.small) }
            ForEach(ChannelState.allCases, id: \.self) { state in
              lamp(
                state,
                lit: testing
                  || (model.isConnected && model.channels.contains { model.state($0) == state }))
            }
          }.accessibilityElement(children: .combine)
          if let error = model.loadError {
            MiniEmptyState("Station records unreadable", message: error)
          } else if model.channels.isEmpty {
            Spacer(minLength: 0)
            MiniEmptyState(
              "The airwaves are quiet.",
              message: "Connect a Prometheus-compatible server, or rehearse with simulated signals."
            )
            HStack {
              Button("Station Setup…") { model.showSetup = true }
              Button("Run Simulation", action: model.simulate)
            }.buttonStyle(RetroButtonStyle())
            Spacer(minLength: 0)
          } else {
            switch page {
            case .switchboard: switchboard(testing: testing, date: context.date)
            case .chart: chart(date: context.date, compact: compact)
            case .log: stationLog
            }
          }
        }
      }
      if let notice = model.notice {
        Text(notice).font(theme.typography.small).lineLimit(2).help(notice)
      }
      if !compact {
        Text(
          model.demo
            ? "Training frequency. No network traffic or audible alerts."
            : "Checks every 30s while Hello Mini runs · click a channel for its evidence"
        )
        .font(theme.typography.small).lineLimit(1)
      }
    }
    .padding(compact ? 8 : 10)
    .font(theme.typography.body)
    .foregroundStyle(theme.ink)
    .background(theme.paper)
    .sheet(isPresented: $model.showSetup) { StationSetupView(model: model).miniSheet(width: 480) }
    .onChange(of: page) { _, page in if page == .chart { model.loadChart() } }
    .onChange(of: model.selection) { _, _ in if page == .chart { model.loadChart() } }
    .onChange(of: model.demo) { _, _ in if page == .chart { model.loadChart() } }
  }
  private func controls(compact: Bool) -> some View {
    HStack(spacing: 6) {
      if !compact {
        Text(model.displayedConfiguration.name).font(theme.typography.title).lineLimit(1)
      }
      Button(compact ? "Setup…" : "Station Setup…") { model.showSetup = true }
        .disabled(model.loadError != nil)
      Button(model.demo ? "End Simulation" : model.isConnected ? "Disconnect" : "Connect") {
        if model.isConnected { model.disconnect() } else { model.connect() }
      }.disabled(model.loadError != nil)
      Button(model.busy ? "Receiving…" : compact ? "Receive" : "Receive Now") {
        Task { await model.refresh(force: true) }
      }.disabled(!model.isConnected || model.busy || model.demo)
      if compact { Spacer(minLength: 0) }
    }
  }
  private func lamp(_ state: ChannelState, lit: Bool) -> some View {
    Image(systemName: state.symbol)
      .font(.system(size: 12, weight: .bold)).opacity(lit ? 1 : 0.22)
      .foregroundStyle(lit && state == .degraded ? theme.accent : theme.ink)
      .accessibilityLabel(state.title + (lit ? ", illuminated" : ", off"))
      .help(state.title)
  }
  private func switchboard(testing: Bool, date: Date) -> some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 4) {
        ForEach(model.channels) { channel in
          let selected = model.selection == channel.id
          VStack(alignment: .leading, spacing: 4) {
            Button {
              model.selection = selected ? nil : channel.id
            } label: {
              HStack(spacing: 8) {
                lamp(model.state(channel), lit: true)
                VStack(alignment: .leading, spacing: 2) {
                  Text(channel.name).lineLimit(1)
                  Text(model.state(channel).title).font(theme.typography.small)
                }
                Spacer(minLength: 4)
                if channel.kind != .state, let value = model.readings[channel.id]?.point?.value {
                  Text(channel.formatted(value)).monospacedDigit().lineLimit(1)
                }
                // A receive light means a recently received sample, not proof that its contents are healthy.
                Text("RX").font(theme.typography.small)
                  .opacity(
                    testing
                      || (moving
                        && model.readings[channel.id]?.receivedAt.map {
                          date.timeIntervalSince($0) < 3
                        } == true)
                      ? 1 : 0.25)
                Image(systemName: selected ? "chevron.up" : "chevron.down").font(.system(size: 9))
              }.padding(7).contentShape(Rectangle())
            }.buttonStyle(.plain)
              .accessibilityLabel(channel.name + ": " + model.state(channel).title)
            if selected {
              VStack(alignment: .leading, spacing: 4) {
                Text(model.explanation(channel))
                if let reading = model.readings[channel.id] {
                  if let at = reading.point?.date {
                    Text("Sample: " + at.formatted(date: .abbreviated, time: .standard))
                  }
                  if let at = reading.evidenceAt {
                    Text("Evidence: " + at.formatted(date: .abbreviated, time: .standard))
                  }
                  if let at = reading.receivedAt {
                    Text("Received: " + at.formatted(date: .omitted, time: .standard))
                  }
                }
                Text(
                  "Freshness limit: \(Int(channel.maxAge)) s"
                    + (channel.evidenceQuery.isEmpty
                      ? " · query sample only" : " · producer evidence required"))
                Text(channel.query).textSelection(.enabled)
                Button("Put on chart") {
                  page = .chart
                  model.loadChart()
                }.buttonStyle(RetroButtonStyle())
              }.font(theme.typography.small).padding([.horizontal, .bottom], 8)
            }
          }.overlay(Rectangle().stroke(theme.ink.opacity(selected ? 1 : 0.3), lineWidth: 1))
        }
      }.padding(2)
    }
  }
  private func chart(date: Date, compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Picker(
        "Chart channel",
        selection: Binding(get: { model.selected?.id ?? UUID() }, set: { model.selection = $0 })
      ) {
        ForEach(model.channels) { Text($0.name).tag($0.id) }
      }.labelsHidden()
      if let error = model.chartError { Text(error).font(theme.typography.small) }
      if model.chart.isEmpty {
        Spacer(minLength: 0)
        Text(model.chartError == nil ? "Threading the paper…" : "No trace available.").font(
          theme.typography.small)
        Spacer(minLength: 0)
      } else {
        let end = model.chartLoadedAt ?? date
        StripChart(
          points: model.chart, end: end, stateCodes: model.selected?.kind == .state,
          moving: moving && model.isConnected, date: date)
        HStack {
          Text(end.addingTimeInterval(-3600).formatted(date: .omitted, time: .shortened))
          Spacer()
          Text("1 hour · 60s samples")
          Spacer()
          Text(end.formatted(date: .omitted, time: .shortened))
        }.font(theme.typography.small)
        if !compact {
          Text(
            model.selected?.kind == .state
              ? "0 healthy · 1 waiting · 2 degraded · 3 paused · 4 unknown"
              : "\(model.selected?.unit ?? "") · gaps remain gaps; history comes from the server"
          )
          .font(theme.typography.small).lineLimit(2)
        }
      }
    }.onAppear { model.loadChart() }
  }
  private var stationLog: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 8) {
        if model.log.isEmpty {
          Text("No transmissions logged. The equipment denies any involvement.")
        }
        ForEach(model.log) { entry in
          HStack(alignment: .top, spacing: 8) {
            Text(entry.date.formatted(date: .omitted, time: .standard)).monospacedDigit()
            Image(systemName: entry.state.symbol)
            VStack(alignment: .leading) {
              Text(entry.channel)
              Text(entry.message).font(theme.typography.small)
            }
          }
          Divider()
        }
      }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
    }.help(
      "The latest 200 observed state changes in this connection session. Closed-app history is available in the chart backend."
    )
  }
}

private struct StripChart: View {
  @Environment(\.miniTheme) private var theme
  let points: [TelemetryPoint]
  let end: Date
  let stateCodes: Bool
  let moving: Bool
  let date: Date
  var body: some View {
    let points =
      stateCodes
      ? points.map { point in
        let valid = [0.0, 1, 2, 3].contains(point.value)
        return TelemetryPoint(date: point.date, value: valid ? point.value : 4)
      } : points
    let low = stateCodes ? 0 : min(points.map(\.value).min() ?? 0, 0)
    let high = stateCodes ? 4 : max(points.map(\.value).max() ?? 1, low + 1)
    HStack(spacing: 4) {
      VStack {
        Text(high.formatted(.number.precision(.fractionLength(0...1))))
        Spacer()
        Text(low.formatted(.number.precision(.fractionLength(0...1))))
      }
      .font(theme.typography.small).frame(width: 44)
      Canvas { context, size in
        var grid = Path()
        for x in stride(from: 0.0, through: size.width, by: 16) {
          grid.move(to: CGPoint(x: x, y: 0))
          grid.addLine(to: CGPoint(x: x, y: size.height))
        }
        for y in stride(from: 0.0, through: size.height, by: 16) {
          grid.move(to: CGPoint(x: 0, y: y))
          grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(grid, with: .color(theme.ink.opacity(0.15)), lineWidth: 0.5)
        var trace = Path()
        var previous: TelemetryPoint?
        for point in points {
          let x = point.date.timeIntervalSince(end.addingTimeInterval(-3600)) / 3600 * size.width
          guard x >= 0 && x <= size.width else {
            previous = nil
            continue
          }
          let y = size.height - (point.value / 2 - low / 2) / (high / 2 - low / 2) * size.height
          let p = CGPoint(x: x, y: max(0, min(size.height, y)))
          if let previous, point.date.timeIntervalSince(previous.date) <= 90 {
            if stateCodes {
              let oldY =
                size.height - (previous.value / 2 - low / 2) / (high / 2 - low / 2) * size.height
              trace.addLine(to: CGPoint(x: x, y: max(0, min(size.height, oldY))))
            }
            trace.addLine(to: p)
          } else {
            trace.move(to: p)
          }
          previous = point
        }
        context.stroke(trace, with: .color(theme.ink), lineWidth: 1.5)
        // Sprocket holes are decorative. The trace and time axis never invent samples.
        let shift = moving ? date.timeIntervalSince1970.truncatingRemainder(dividingBy: 4) * 3 : 0
        for x in stride(from: 4.0 + shift, through: size.width, by: 16) {
          context.fill(
            Path(ellipseIn: CGRect(x: x, y: 2, width: 3, height: 3)),
            with: .color(theme.ink.opacity(0.35)))
        }
      }.overlay(Rectangle().stroke(theme.ink, lineWidth: 1))
    }.frame(minHeight: 30)
      .accessibilityLabel("Strip chart. \(points.count) samples. Minimum \(low), maximum \(high).")
  }
}
