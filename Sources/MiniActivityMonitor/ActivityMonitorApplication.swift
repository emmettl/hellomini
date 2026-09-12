import MiniCore
import MiniUI
import Observation
import SwiftUI

@MainActor public final class ActivityMonitorApplication: MiniApplication {
  public let id = "activity"
  public let name = "Activity Monitor"
  public let icon = MiniApplicationIcon.activity
  public let defaultSize = CGSize(width: 820, height: 524)
  private let model = ActivityModel()
  public init() {}
  public func content() -> AnyView { AnyView(ActivityView(model: model)) }

  public var menus: [RetroMenu] {
    [
      RetroMenu(
        id: "monitor", title: "Monitor", width: 280,
        items: [
          RetroMenuItem(
            id: "pause", title: model.paused ? "Resume Updates" : "Pause Updates",
            shortcut: RetroShortcut(key: "p", label: "⌘P")
          ) { self.model.paused.toggle() },
          .separator("monitor-sort"),
          RetroMenuItem(id: "sort-cpu", title: "Sort by CPU", checked: !model.sortByMemory) {
            self.model.sortByMemory = false
          },
          RetroMenuItem(id: "sort-memory", title: "Sort by Memory", checked: model.sortByMemory) {
            self.model.sortByMemory = true
          },
          .separator("monitor-history"),
          RetroMenuItem(id: "clear-history", title: "Clear CPU History") {
            self.model.history = []
          },
        ])
    ]
  }
}

@MainActor @Observable
private final class ActivityModel {
  var latest: SystemSample?
  var history: [Double] = []
  var paused = false
  var sortByMemory = false
  var filter = ""
  var error: String?
  private let sampler = SystemSampler()

  var processes: [ProcessSample] {
    (latest?.processes ?? []).filter {
      filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter)
        || String($0.id).contains(filter)
    }.sorted {
      if sortByMemory {
        return $0.residentBytes == $1.residentBytes
          ? $0.id < $1.id : $0.residentBytes > $1.residentBytes
      }
      return $0.cpu == $1.cpu ? $0.id < $1.id : $0.cpu > $1.cpu
    }
  }

  func observe() async {
    // A pause or closed window is a gap, not part of the current two-minute history.
    history = []
    await sampler.reset()
    while !Task.isCancelled {
      do {
        let sample = try await sampler.sample()
        guard !Task.isCancelled else { return }
        latest = sample
        error = nil
        if let cpu = sample.cpu {
          history.append(cpu)
          history = Array(history.suffix(60))
        }
      } catch {
        guard !Task.isCancelled else { return }
        self.error = error.localizedDescription
      }
      do { try await Task.sleep(for: .seconds(2)) } catch { return }
    }
  }
}

private struct ActivityView: View {
  @Environment(\.miniTheme) private var theme
  @Bindable var model: ActivityModel

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(ProcessInfo.processInfo.hostName).font(theme.typography.title).lineLimit(1)
        Spacer()
        Text("\(ProcessInfo.processInfo.activeProcessorCount) cores").font(theme.typography.small)
        Button(model.paused ? "Resume" : "Pause") { model.paused.toggle() }
          .buttonStyle(RetroButtonStyle())
      }
      .padding(.horizontal, 14).frame(height: 42)
      Rectangle().frame(height: 1)
      if let sample = model.latest {
        HStack(alignment: .top, spacing: 22) {
          VStack(alignment: .leading, spacing: 4) {
            Text("CPU BUSY").font(theme.typography.small)
            Text(sample.cpu.map { String(format: "%.1f%%", $0) } ?? "Sampling…")
              .font(theme.typography.display(30)).monospacedDigit()
            Text("Across all cores").font(theme.typography.small)
          }.frame(width: 190, alignment: .leading)
          VStack(alignment: .leading, spacing: 5) {
            Text("MEMORY · \(bytes(sample.totalMemory))").font(theme.typography.small)
            Text("Wired       \(bytes(sample.wiredMemory))")
            Text("Compressed  \(bytes(sample.compressedMemory))")
            Text("Free        \(bytes(sample.freeMemory))")
          }.font(theme.typography.small).frame(maxWidth: .infinity, alignment: .leading)
          VStack(alignment: .leading, spacing: 5) {
            Text("SYSTEM").font(theme.typography.small)
            Text("Up \(uptime(sample.uptime))")
            Text("Load \(sample.load.map { String(format: "%.2f", $0) }.joined(separator: " / "))")
            Text(
              sample.diskAvailable.map {
                "Disk free \(ByteCountFormatter.string(fromByteCount: $0, countStyle: .file))"
              } ?? "Disk free unavailable")
          }.font(theme.typography.small).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
      } else {
        Text(model.error ?? "Taking the first sample…").padding(20)
      }
      VStack(alignment: .leading, spacing: 5) {
        CPUHistory(values: model.history).frame(height: 48)
        HStack {
          Text("CPU · last 2 minutes · 0–100%")
          Spacer()
          Text("Load averages: 1 / 5 / 15 min")
        }.font(theme.typography.small)
      }.padding(.horizontal, 16).padding(.bottom, 12)
      Rectangle().frame(height: 1)
      HStack(spacing: 10) {
        Text("PROCESSES").font(theme.typography.small)
        TextField("Filter name or PID", text: $model.filter)
          .textFieldStyle(.plain).padding(5)
          .overlay(Rectangle().strokeBorder(theme.ink, lineWidth: 1))
          .frame(maxWidth: 230)
          .accessibilityLabel("Filter processes by name or PID")
        Spacer()
        Button(model.sortByMemory ? "Sort: Memory" : "Sort: CPU") { model.sortByMemory.toggle() }
          .buttonStyle(RetroButtonStyle())
      }.padding(.horizontal, 14).frame(height: 42)
      processHeader
      if let issue = model.latest?.processError {
        Text(issue).font(theme.typography.small).padding(16).frame(
          maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(model.processes) { process in
              HStack {
                Text(process.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                Text(String(process.id)).frame(width: 64, alignment: .trailing)
                Text(String(format: "%.1f", process.cpu)).frame(width: 74, alignment: .trailing)
                Text(bytes(process.residentBytes)).frame(width: 90, alignment: .trailing)
              }
              .font(theme.typography.small).monospacedDigit()
              .padding(.horizontal, 16).frame(height: 24)
              .overlay(alignment: .bottom) {
                Rectangle().fill(theme.ink.opacity(0.12)).frame(height: 1)
              }
            }
            if model.processes.isEmpty {
              Text("No matching processes.").font(theme.typography.small).padding(20)
            }
          }
        }.frame(maxHeight: .infinity)
      }
      Rectangle().frame(height: 1)
      HStack {
        Text(model.error ?? (model.paused ? "Paused" : "Live · every 2 seconds"))
          .lineLimit(1).help(model.error ?? "Sampling stops when this window is closed.")
        Spacer()
        if let date = model.latest?.date {
          Text("Updated \(date.formatted(.dateTime.hour().minute().second()))")
        }
        Text("\(model.latest?.processes.count ?? 0) processes")
      }.font(theme.typography.small).padding(.horizontal, 14).frame(height: 28)
    }
    .font(theme.typography.body)
    .task(id: model.paused) { if !model.paused { await model.observe() } }
  }

  private var processHeader: some View {
    HStack {
      Text("Name").frame(maxWidth: .infinity, alignment: .leading)
      Text("PID").frame(width: 64, alignment: .trailing)
      Text("CPU %¹").frame(width: 74, alignment: .trailing)
      Text("Memory²").frame(width: 90, alignment: .trailing)
    }
    .font(theme.typography.small).padding(.horizontal, 16).frame(height: 24)
    .foregroundStyle(theme.selectionInk).background { ThemeSurfaceView(theme.selection) }
    .help(
      "1: ps reports recent CPU usage; a multithreaded process can exceed 100%. 2: Resident memory (RSS); shared pages may appear in multiple processes. These columns do not sum to system totals."
    )
  }

  private func bytes(_ value: UInt64) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .memory)
  }

  private func uptime(_ value: TimeInterval) -> String {
    let seconds = Int(value)
    return "\(seconds / 86400)d \((seconds / 3600) % 24)h \((seconds / 60) % 60)m"
  }
}

private struct CPUHistory: View {
  @Environment(\.miniTheme) private var theme
  let values: [Double]
  var body: some View {
    Canvas { context, size in
      for fraction in [0.0, 0.5, 1.0] {
        var line = Path()
        line.move(to: CGPoint(x: 0, y: fraction * (size.height - 1)))
        line.addLine(to: CGPoint(x: size.width, y: fraction * (size.height - 1)))
        context.stroke(
          line, with: .color(theme.ink), style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
      }
      let width = size.width / 60
      for (index, value) in values.enumerated() {
        let height = max(1, min(100, max(0, value)) / 100 * size.height)
        context.fill(
          Path(
            CGRect(
              x: Double(60 - values.count + index) * width, y: size.height - height,
              width: max(1, width - 2), height: height)), with: .color(theme.ink))
      }
    }
    .accessibilityLabel("CPU usage over the last two minutes")
    .accessibilityValue(
      values.last.map { String(format: "Latest %.1f percent", $0) } ?? "Waiting for samples")
  }
}
