import MiniCore
import MiniStorage
import MiniUI
import SwiftUI

@MainActor public final class DiskFirstAidApplication: MiniApplication {
  public let id = "disk-first-aid"
  public let name = "Disk First Aid"
  public let icon = MiniApplicationIcon.disk
  public let defaultSize = CGSize(width: 690, height: 460)
  public let minimumSize = CGSize(width: 580, height: 370)
  public init() {}
  public func content() -> AnyView { AnyView(DiskView()) }
}

private struct DiskView: View {
  @Environment(\.miniTheme) private var theme
  @State private var volumes: [VolumeReport] = []
  @State private var busy = false
  @State private var error: String?
  private let reader = StorageReader()
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        PixelIcon(symbol: .disk)
        Text("The doctor will see your disks now.").font(theme.typography.title)
        Spacer()
        Button("Refresh") { Task { await refresh() } }.buttonStyle(RetroButtonStyle()).disabled(
          busy)
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          if volumes.isEmpty {
            MiniEmptyState(
              busy ? "Reading the chart…" : "No volumes to examine.",
              message: "Refresh to list mounted disks. Any access problem appears below.")
          }
          ForEach(volumes) { volume in
            VStack(alignment: .leading, spacing: 6) {
              HStack {
                Text(volume.name).font(theme.typography.title)
                Spacer()
                Text(volume.format).font(theme.typography.small)
              }
              Text(volume.id.path).font(theme.typography.small).textSelection(.enabled)
              ProgressView(
                value: Double(max(0, volume.total - volume.available)),
                total: Double(max(1, volume.total)))
              Text(
                "\(bytes(volume.available)) available / \(bytes(volume.total)) total · \(volume.readOnly ? "Read-only" : "Writable")"
              )
              .font(theme.typography.small)
              HStack {
                Text("SMART: \(volume.smart)").font(theme.typography.small)
                Spacer()
                Button("Inspect") { inspect(volume) }.buttonStyle(RetroButtonStyle()).disabled(busy)
                  .accessibilityLabel("Inspect \(volume.name)")
              }
            }
          }
        }
      }
      if let error { Text(error).font(theme.typography.small) }
      Text(
        busy
          ? "Reading the chart…"
          : "Read-only inspection. SMART availability varies; APFS volumes may share free space. No repairs are performed."
      )
      .font(theme.typography.small)
    }.padding(16).task { await refresh() }
  }
  private func bytes(_ n: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
  }
  private func refresh() async {
    guard !busy else { return }
    busy = true
    defer { busy = false }
    do {
      volumes = try await reader.volumes()
      error = nil
    } catch { self.error = error.localizedDescription }
  }
  private func inspect(_ volume: VolumeReport) {
    busy = true
    Task {
      defer { busy = false }
      do {
        let report = try await reader.inspect(volume)
        volumes = volumes.map { $0.id == report.id ? report : $0 }
        error = nil
      } catch { self.error = error.localizedDescription }
    }
  }
}
