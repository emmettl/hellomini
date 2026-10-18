import Foundation

struct WindowPlacement: Codable, Equatable {
  var origin: CGPoint
  var size: CGSize

  var isValid: Bool {
    origin.x.isFinite && origin.y.isFinite && size.width.isFinite && size.height.isFinite
      && size.width > 0 && size.height > 0
  }
}

struct DesktopSession: Codable, Equatable {
  var version = 1
  var openIDs: [String]
  var windows: [String: WindowPlacement]
  // Optional fields keep existing version-one sessions readable.
  var minimisedIDs: [String]?
  var zoomedIDs: [String]?
  var shadedIDs: [String]?
}

struct DesktopSessionStore {
  let defaults: UserDefaults
  static let key = "desktop.session"

  var recoveryNeeded: Bool {
    guard let original = defaults.object(forKey: Self.key) else { return false }
    guard let data = original as? Data else { return true }
    guard let session = try? JSONDecoder().decode(DesktopSession.self, from: data),
      session.version == 1
    else { return true }
    return false
  }
  /// Keep the original bytes, including unsupported future versions, until explicit recovery.
  func recover() {
    if let original = defaults.object(forKey: Self.key) {
      let key = "desktop.session.recovery." + UUID().uuidString
      defaults.set(original, forKey: key)
      var dates = defaults.dictionary(forKey: "desktop.recoveryDates") ?? [:]
      dates[key] = Date()
      defaults.set(dates, forKey: "desktop.recoveryDates")
    }
    defaults.removeObject(forKey: Self.key)
  }
  func load() -> DesktopSession? {
    guard let data = defaults.data(forKey: Self.key),
      var session = try? JSONDecoder().decode(DesktopSession.self, from: data), session.version == 1
    else { return nil }
    var seen = Set<String>()
    session.openIDs = session.openIDs.filter { !$0.isEmpty && seen.insert($0).inserted }
    session.windows = session.windows.filter { !$0.key.isEmpty && $0.value.isValid }
    return session
  }

  func save(_ session: DesktopSession) {
    guard !recoveryNeeded else { return }
    guard let data = try? JSONEncoder().encode(session) else { return }
    defaults.set(data, forKey: Self.key)
  }
}
