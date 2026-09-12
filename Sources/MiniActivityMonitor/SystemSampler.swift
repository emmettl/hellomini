import Darwin
import Foundation

struct CPUTicks: Sendable {
  let user: UInt32
  let system: UInt32
  let idle: UInt32
  let nice: UInt32

  func usage(since previous: Self) -> Double? {
    let busy =
      UInt64(user &- previous.user) + UInt64(system &- previous.system)
      + UInt64(nice &- previous.nice)
    let total = busy + UInt64(idle &- previous.idle)
    return total == 0 ? nil : Double(busy) / Double(total) * 100
  }
}

struct ProcessSample: Identifiable, Sendable {
  let id: Int
  let cpu: Double
  let residentBytes: UInt64
  let name: String

  static func parse(_ output: String) -> [Self] {
    output.split(separator: "\n").compactMap { line in
      let fields = line.split(
        maxSplits: 3, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
      guard fields.count == 4, let pid = Int(fields[0]), let cpu = Double(fields[1]), cpu.isFinite,
        cpu >= 0,
        let kib = UInt64(fields[2]), kib <= UInt64.max / 1024
      else { return nil }
      let name = (String(fields[3]) as NSString).lastPathComponent
      return Self(id: pid, cpu: cpu, residentBytes: kib * 1024, name: name)
    }
  }
}

struct SystemSample: Sendable {
  let date: Date
  let cpu: Double?
  let totalMemory: UInt64
  let freeMemory: UInt64
  let wiredMemory: UInt64
  let compressedMemory: UInt64
  let load: [Double]
  let uptime: TimeInterval
  let diskAvailable: Int64?
  let processes: [ProcessSample]
  let processError: String?
}

actor SystemSampler {
  private var previousCPU: CPUTicks?
  func reset() { previousCPU = nil }

  func sample() throws -> SystemSample {
    let host = mach_host_self()
    defer { mach_port_deallocate(mach_task_self_, host) }
    var cpuInfo = host_cpu_load_info_data_t()
    var cpuCount = mach_msg_type_number_t(
      MemoryLayout.size(ofValue: cpuInfo) / MemoryLayout<integer_t>.size)
    let cpuResult = withUnsafeMutablePointer(to: &cpuInfo) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(cpuCount)) {
        host_statistics(host, HOST_CPU_LOAD_INFO, $0, &cpuCount)
      }
    }
    guard cpuResult == KERN_SUCCESS else { throw SamplingError.unavailable("CPU", cpuResult) }
    let ticks = CPUTicks(
      user: cpuInfo.cpu_ticks.0, system: cpuInfo.cpu_ticks.1, idle: cpuInfo.cpu_ticks.2,
      nice: cpuInfo.cpu_ticks.3)
    let cpu = previousCPU.flatMap { ticks.usage(since: $0) }
    previousCPU = ticks

    var vm = vm_statistics64_data_t()
    var vmCount = mach_msg_type_number_t(
      MemoryLayout.size(ofValue: vm) / MemoryLayout<integer_t>.size)
    let vmResult = withUnsafeMutablePointer(to: &vm) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
        host_statistics64(host, HOST_VM_INFO64, $0, &vmCount)
      }
    }
    guard vmResult == KERN_SUCCESS else { throw SamplingError.unavailable("Memory", vmResult) }
    var pageSize: vm_size_t = 0
    let pageResult = host_page_size(host, &pageSize)
    guard pageResult == KERN_SUCCESS else {
      throw SamplingError.unavailable("Page size", pageResult)
    }
    let page = UInt64(pageSize)
    var loads = [Double](repeating: 0, count: 3)
    if getloadavg(&loads, 3) != 3 { loads = [] }
    let disk = try? FileManager.default.homeDirectoryForCurrentUser.resourceValues(forKeys: [
      .volumeAvailableCapacityKey
    ])
    var processes: [ProcessSample] = []
    var processError: String?
    do { processes = try readProcesses() } catch { processError = error.localizedDescription }
    return SystemSample(
      date: .now, cpu: cpu, totalMemory: ProcessInfo.processInfo.physicalMemory,
      freeMemory: UInt64(vm.free_count) * page, wiredMemory: UInt64(vm.wire_count) * page,
      compressedMemory: UInt64(vm.compressor_page_count) * page, load: loads,
      uptime: ProcessInfo.processInfo.systemUptime,
      diskAvailable: disk?.volumeAvailableCapacity.map(Int64.init),
      processes: processes, processError: processError
    )
  }

  private func readProcesses() throws -> [ProcessSample] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/ps")
    // Executable names only: command-line arguments may contain CI secrets.
    process.arguments = ["-A", "-o", "pid=,pcpu=,rss=,comm="]
    process.environment = ["LC_ALL": "C"]
    let output = Pipe()
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw SamplingError.processesUnavailable }
    return ProcessSample.parse(String(decoding: data, as: UTF8.self))
  }
}

private enum SamplingError: LocalizedError {
  case unavailable(String, kern_return_t)
  case processesUnavailable
  var errorDescription: String? {
    switch self {
    case .unavailable(let metric, let status): "\(metric) is unavailable (system error \(status))."
    case .processesUnavailable: "Process information is unavailable. System totals are still shown."
    }
  }
}
