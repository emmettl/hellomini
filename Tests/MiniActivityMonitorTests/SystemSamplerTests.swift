import Foundation
import Testing

@testable import MiniActivityMonitor

@Test func cpuUsesDeltasAcrossAllCores() {
  let before = CPUTicks(user: 100, system: 200, idle: 600, nice: 100)
  let after = CPUTicks(user: 120, system: 210, idle: 660, nice: 110)
  #expect(after.usage(since: before) == 40)
  #expect(before.usage(since: before) == nil)
}

@Test func cpuHandlesKernelTickCounterWrap() {
  let before = CPUTicks(user: UInt32.max - 4, system: 0, idle: 100, nice: 0)
  let after = CPUTicks(user: 5, system: 0, idle: 110, nice: 0)
  #expect(after.usage(since: before) == 50)
}

@Test func processParserKeepsNamesWithSpacesAndConvertsResidentMemory() {
  let rows = ProcessSample.parse(
    " 123 245.7 2048 /Applications/Build Agent.app/Contents/MacOS/Build Agent\n124 0.0 0 kernel_task"
  )
  #expect(rows.count == 2)
  #expect(rows.first?.name == "Build Agent")
  #expect(rows.first?.cpu == 245.7)
  #expect(rows.first?.residentBytes == 2_097_152)
  #expect(rows.last?.name == "kernel_task")
}

@Test func malformedProcessRowsAreSkipped() {
  let rows = ProcessSample.parse(
    "PID CPU RSS NAME\n1 nan 40 test\n2 -1 40 test\n3 2 -1 test\n4 2 18446744073709551615 test\n5 0 20 valid"
  )
  #expect(rows.map(\.id) == [5])
}
