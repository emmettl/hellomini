import Testing

@testable import MiniDesktop

@Test @MainActor func startupVisitsWelcomeAndFinishesOnlyOnce() async {
  let sequence = StartupSequence()
  var phases: [StartupSequence.Phase] = []
  var progress: [Int] = []
  var duration = Duration.zero
  await sequence.run(enabled: true, reduceMotion: false) { delay in
    phases.append(sequence.phase)
    progress.append(sequence.progress)
    duration += delay
  }
  #expect(phases.first == .happyMac)
  #expect(phases.dropFirst().allSatisfy { $0 == .welcome })
  #expect(progress == [0, 0, 1, 2, 3, 4, 5, 6])
  #expect(duration == .milliseconds(3800))
  #expect(sequence.phase == .desktop)
  await sequence.run(enabled: true, reduceMotion: false) { _ in
    Issue.record("Startup replayed after completion")
  }
}

@Test @MainActor func disablingStartupOrReducingMotionOpensDesktopImmediately() async {
  for (enabled, reduceMotion) in [(false, false), (true, true), (false, true)] {
    let sequence = StartupSequence()
    await sequence.run(enabled: enabled, reduceMotion: reduceMotion) { _ in
      Issue.record("Bypassed startup must not introduce a delay")
    }
    #expect(sequence.phase == .desktop)
  }
}

@Test @MainActor func skippingDuringADelayDoesNotRestoreTheWelcomeScreen() async {
  for skipDuringHappyMac in [true, false] {
    let sequence = StartupSequence()
    var sleeps = 0
    await sequence.run(enabled: true, reduceMotion: false) { _ in
      sleeps += 1
      if skipDuringHappyMac || sequence.phase == .welcome { sequence.skip() }
    }
    #expect(sequence.phase == .desktop)
    #expect(sequence.progress == 0)
    #expect(sleeps == (skipDuringHappyMac ? 1 : 2))
  }
}

@Test @MainActor func cancelledStartupCannotReplayOrRemainStuck() async {
  let sequence = StartupSequence()
  await sequence.run(enabled: true, reduceMotion: false) { _ in throw CancellationError() }
  #expect(sequence.phase == .desktop)
  await sequence.run(enabled: true, reduceMotion: false) { _ in
    Issue.record("Cancelled startup must not restart")
  }
}
