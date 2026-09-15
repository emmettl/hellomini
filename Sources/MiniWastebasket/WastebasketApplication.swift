import AppKit
import MiniCore
import MiniStorage
import MiniUI
import SwiftUI

@MainActor public final class WastebasketApplication: MiniApplication {
  public let id = "wastebasket"
  public let name = "Wastebasket"
  public let icon = MiniApplicationIcon.wastebasket
  public let defaultSize = CGSize(width: 750, height: 490)
  public let minimumSize = CGSize(width: 440, height: 250)
  private let onEmpty: () -> Void
  public init(onEmpty: @escaping () -> Void = {}) { self.onEmpty = onEmpty }
  public func content() -> AnyView { AnyView(WastebasketView(onEmpty: onEmpty)) }
}

private struct WastebasketView: View {
  let onEmpty: () -> Void
  @Environment(\.miniTheme) private var theme
  @State private var roots = [
    "Library/Developer/Xcode/DerivedData", "Library/Caches/org.swift.swiftpm",
    "Library/Caches/com.apple.dt.Xcode",
  ].map { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent($0) }
  @State private var items: [CacheItem] = []
  @State private var selected = Set<URL>()
  @State private var busy = false
  @State private var message =
    "Review build caches, then move selected items to macOS Trash. Nothing is selected automatically."
  @State private var confirming = false
  @State private var scanTask: Task<Void, Never>?
  @State private var height: CGFloat = 490
  private var roomy: Bool { height >= 340 }
  private static let guidance =
    "Sizes are estimates; + means a partial scan. Close affected builds before moving caches. Restore mistakes from macOS Trash."
  private let reader = StorageReader()
  var body: some View {
    VStack(alignment: .leading, spacing: roomy ? 12 : 8) {
      ViewThatFits(in: .horizontal) {
        toolbar(short: false)
        toolbar(short: true)
      }.buttonStyle(RetroButtonStyle()).disabled(busy)
      if roomy {
        Text("Capacity: three crumpled pages, apparently.").font(theme.typography.title)
      }
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if items.isEmpty {
            MiniEmptyState(
              busy ? "Counting the rubbish…" : "A remarkably empty basket.",
              message:
                "Scan known build caches, or add a Swift project to review its .build folder. Select only the items you want to move to Trash."
            )
          }
          ForEach(items) { item in
            Toggle(
              isOn: Binding(
                get: { selected.contains(item.id) },
                set: { if $0 { selected.insert(item.id) } else { selected.remove(item.id) } })
            ) {
              VStack(alignment: .leading, spacing: 4) {
                HStack {
                  Text(item.id.lastPathComponent).font(theme.typography.title).lineLimit(1)
                  Spacer()
                  Text(
                    ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file)
                      + (item.partial ? " +" : ""))
                }
                Text(item.id.path).font(theme.typography.small).lineLimit(2).textSelection(.enabled)
              }
            }.disabled(busy)
          }
        }
      }
      Text(message).font(theme.typography.small).lineLimit(roomy ? nil : 2)
        .miniHelp(Self.guidance)
      if roomy { Text(Self.guidance).font(theme.typography.small) }
    }.padding(roomy ? 16 : 10)
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        height = $0
      }
      .confirmationDialog(
        "Move \(selected.count) reviewed cache items to macOS Trash?", isPresented: $confirming,
        titleVisibility: .visible
      ) {
        Button("Move selected items to Trash", action: trash)
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(items.filter { selected.contains($0.id) }.map { $0.id.path }.joined(separator: "\n"))
      }
      .onDisappear { scanTask?.cancel() }
  }
  private func toolbar(short: Bool) -> some View {
    HStack {
      Button(short ? "Scan" : "Scan caches", action: scan).accessibilityLabel("Scan caches")
      Button(short ? "Add project…" : "Add Swift project…", action: addProject)
        .accessibilityLabel("Add Swift project")
      Spacer(minLength: 4)
      Button(short ? "Trash…" : "Move to Trash…") { confirming = true }
        .disabled(selected.isEmpty).accessibilityLabel("Move selected items to Trash")
    }
  }

  private func addProject() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.message =
      "Choose a Swift project. Only the contents of its .build folder will be considered."
    guard panel.runModal() == .OK, let url = panel.url else { return }
    let root = url.appendingPathComponent(".build")
    if !roots.contains(root) { roots.append(root) }
    scan()
  }
  private func scan() {
    busy = true
    selected = []
    items = []
    message = "Counting an unreasonable quantity of rubbish…"
    scanTask = Task {
      defer { busy = false }
      var found: [CacheItem] = []
      var skipped: [String] = []
      for root in roots {
        guard !Task.isCancelled else { return }
        do { found += try await reader.caches(in: root) } catch is CancellationError {
          return
        } catch { skipped.append(root.lastPathComponent) }
      }
      items = found.sorted { $0.bytes > $1.bytes }
      message =
        "\(items.count) items reviewed."
        + (skipped.isEmpty ? "" : " Unavailable or absent: " + skipped.joined(separator: ", "))
    }
  }
  private func trash() {
    let targets = items.filter { selected.contains($0.id) }
    busy = true
    Task {
      defer { busy = false }
      var moved = Set<URL>()
      var failed: [String] = []
      for item in targets {
        do {
          try await reader.trash(item)
          moved.insert(item.id)
        } catch { failed.append(item.id.lastPathComponent) }
      }
      if !moved.isEmpty { onEmpty() }
      items.removeAll { moved.contains($0.id) }
      selected.subtract(moved)
      message =
        "Moved \(moved.count) items to macOS Trash."
        + (failed.isEmpty
          ? ""
          : " Could not move: " + failed.joined(separator: ", ") + ". Scan again if items changed.")
    }
  }
}
