import Darwin
import Foundation

struct AquariumCounters: Sendable {
  let ticks: [UInt32]
  let networkBytes: UInt64?
  let time: TimeInterval

  func activity(since previous: Self) -> AquariumActivity {
    let delta = zip(ticks, previous.ticks).map { UInt64($0 &- $1) }
    let total = delta.reduce(0, +)
    let cpu = total > 0 ? Double(total - delta[2]) / Double(total) : nil
    var bytesPerSecond: Double?
    if let networkBytes, let before = previous.networkBytes, networkBytes >= before,
      time > previous.time
    {
      bytesPerSecond = Double(networkBytes - before) / (time - previous.time)
    }
    return AquariumActivity(cpu: cpu, bytesPerSecond: bytesPerSecond)
  }
}

struct AquariumActivity: Sendable {
  var cpu: Double?
  var bytesPerSecond: Double?
  var current: Float { Float(cpu ?? 0) }
  // A logarithmic response keeps both small bursts and large transfers legible.
  var bubbles: Float { Float(min(1, log10(1 + (bytesPerSecond ?? 0)) / 7)) }
}

actor AquariumSampler {
  private var previous: AquariumCounters?

  func reset() { previous = nil }

  func sample() -> AquariumActivity {
    let host = mach_host_self()
    defer { mach_port_deallocate(mach_task_self_, host) }
    var info = host_cpu_load_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / 4)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
      }
    }
    guard result == KERN_SUCCESS else {
      previous = nil
      return AquariumActivity()
    }
    let counters = AquariumCounters(
      ticks: [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3],
      networkBytes: networkBytes(), time: ProcessInfo.processInfo.systemUptime)
    let activity = previous.map { counters.activity(since: $0) } ?? AquariumActivity()
    previous = counters
    return activity
  }

  private func networkBytes() -> UInt64? {
    var head: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&head) == 0 else { return nil }
    defer { freeifaddrs(head) }
    var next = head
    var total: UInt64 = 0
    while let entry = next {
      let interface = entry.pointee
      next = interface.ifa_next
      // Physical Ethernet/Wi-Fi links only; exclude loopback and VPN double counting.
      guard String(cString: interface.ifa_name).hasPrefix("en"),
        interface.ifa_flags & UInt32(IFF_UP) != 0,
        interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
        let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self)
      else { continue }
      total += UInt64(data.pointee.ifi_ibytes) + UInt64(data.pointee.ifi_obytes)
    }
    return total
  }
}
