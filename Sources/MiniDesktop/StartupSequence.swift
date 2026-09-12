import MiniCore
import Observation

public enum MiniStartup {
  public static let effect = MiniPlayfulEffect(
    id: "desktop.startup", name: "Macintosh startup",
    description: "A happy Mac and a welcome screen at launch. Escape skips it.")
}

/// A one-shot presentation, independent of application loading or system boot progress.
@MainActor @Observable final class StartupSequence {
  enum Phase { case happyMac, welcome, desktop }
  private(set) var phase = Phase.happyMac
  private(set) var progress = 0
  private var started = false
  static let steps = 6

  func skip() { phase = .desktop }

  func run(
    enabled: Bool, reduceMotion: Bool,
    sleep: (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
  ) async {
    guard !started, phase != .desktop else { return }
    started = true
    guard enabled, !reduceMotion else {
      skip()
      return
    }
    do {
      try await sleep(.milliseconds(800))
      guard canContinue else { return }
      phase = .welcome
      for step in 1...Self.steps {
        try await sleep(.milliseconds(450))
        guard canContinue else { return }
        progress = step
      }
      try await sleep(.milliseconds(300))
      skip()
    } catch {
      // Cancellation must not leave a half-finished startup waiting to resume.
      skip()
    }
  }

  private var canContinue: Bool {
    if Task.isCancelled {
      skip()
      return false
    }
    return phase != .desktop
  }
}
