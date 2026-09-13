import SwiftUI

/// A finite two-hop launch cue. Restored sessions and already-running apps do not replay it.
struct DockLaunchBounce: ViewModifier {
  let running: Bool
  let enabled: Bool
  @State private var started: Date?

  func body(content: Content) -> some View {
    TimelineView(.animation(minimumInterval: 1 / 30, paused: started == nil || !enabled)) {
      context in
      content.offset(y: offset(at: context.date))
    }
    .onChange(of: running) { _, running in
      started = running && enabled ? .now : nil
    }
    .onChange(of: enabled) { _, enabled in
      if !enabled { started = nil }
    }
    .task(id: started) {
      guard started != nil else { return }
      do { try await Task.sleep(for: .milliseconds(760)) } catch { return }
      started = nil
    }
    .onDisappear { started = nil }
  }

  private func offset(at date: Date) -> CGFloat {
    guard enabled, running, let started else { return 0 }
    let elapsed = date.timeIntervalSince(started)
    let duration: Double
    let height: Double
    let time: Double
    if elapsed < 0.42 {
      duration = 0.42
      height = 22
      time = elapsed
    } else {
      duration = 0.30
      height = 9
      time = elapsed - 0.42
    }
    guard time > 0, time < duration else { return 0 }
    let progress = time / duration
    return -height * 4 * progress * (1 - progress)
  }
}
