import AppKit
import MiniCore
import MiniUI
import Observation
import SwiftUI

@MainActor @Observable
final class DesktopModel {
  let applications: [any MiniApplication]
  private(set) var openIDs: [String]
  private(set) var minimisedIDs: Set<String>
  private(set) var zoomedIDs: Set<String>
  private(set) var shadedIDs: Set<String>
  var showBackups = false
  var sessionBackups: [DesktopBackup] { store.backups() }
  func restoreBackup(_ session: DesktopSession) {
    guard session.version == 1 else { return }
    store.recover()
    sessionRecoveryNeeded = false
    showSessionRecovery = false
    apply(session)
  }
  var showSessionRecovery = false
  private(set) var sessionRecoveryNeeded = false
  func recoverSession() {
    store.recover()
    sessionRecoveryNeeded = false
    windows = [:]
    minimisedIDs = []
    zoomedIDs = []
    shadedIDs = []
    persist()
  }
  private var windows: [String: WindowPlacement]
  @ObservationIgnored private let store: DesktopSessionStore
  var visibleIDs: [String] { openIDs.filter { !minimisedIDs.contains($0) } }
  var active: (any MiniApplication)? { applications.first { $0.id == visibleIDs.last } }

  init(
    applications: [any MiniApplication], initiallyOpen: [String], defaults: UserDefaults = .standard
  ) {
    precondition(
      Set(applications.map(\.id)).count == applications.count, "Application IDs must be unique")
    self.applications = applications
    store = DesktopSessionStore(defaults: defaults)
    let saved = store.load()
    sessionRecoveryNeeded = store.recoveryNeeded
    showSessionRecovery = store.recoveryNeeded
    windows = saved?.windows ?? [:]
    let knownIDs = Set(applications.map(\.id))
    var seen = Set<String>()
    let restoredIDs = (saved?.openIDs ?? initiallyOpen).filter {
      knownIDs.contains($0) && seen.insert($0).inserted
    }
    openIDs = restoredIDs
    minimisedIDs = Set(saved?.minimisedIDs ?? []).intersection(restoredIDs)
    zoomedIDs = Set(saved?.zoomedIDs ?? []).intersection(restoredIDs)
    shadedIDs = Set(saved?.shadedIDs ?? []).intersection(restoredIDs)
  }

  func launch(_ app: any MiniApplication) {
    guard active?.id != app.id else { return }
    NSApp?.keyWindow?.makeFirstResponder(nil)
    minimisedIDs.remove(app.id)
    openIDs = openIDs.filter { $0 != app.id } + [app.id]
    persist()
  }

  func close(_ app: any MiniApplication) {
    if active?.id == app.id { NSApp?.keyWindow?.makeFirstResponder(nil) }
    openIDs.removeAll { $0 == app.id }
    minimisedIDs.remove(app.id)
    zoomedIDs.remove(app.id)
    shadedIDs.remove(app.id)
    persist()
  }

  func minimise(_ app: any MiniApplication) {
    guard openIDs.contains(app.id) else { return }
    if active?.id == app.id { NSApp?.keyWindow?.makeFirstResponder(nil) }
    minimisedIDs.insert(app.id)
    persist()
  }

  func toggleZoom(_ app: any MiniApplication) {
    guard openIDs.contains(app.id) else { return }
    launch(app)
    if !zoomedIDs.insert(app.id).inserted { zoomedIDs.remove(app.id) }
    persist()
  }

  /// Window shade rolls a window up to its title bar while its application keeps running.
  func toggleShade(_ app: any MiniApplication) {
    guard openIDs.contains(app.id) else { return }
    if !shadedIDs.insert(app.id).inserted { shadedIDs.remove(app.id) }
    persist()
  }

  func displayedPlacement(
    for app: any MiniApplication, desktop: CGSize, menuBarHeight: CGFloat
  ) -> WindowPlacement {
    guard zoomedIDs.contains(app.id) else { return placement(for: app) }
    return WindowPlacement(
      origin: CGPoint(x: 8, y: menuBarHeight + 10),
      size: CGSize(
        width: max(1, desktop.width - 16), height: max(1, desktop.height - menuBarHeight - 18)))
  }

  func placement(for app: any MiniApplication) -> WindowPlacement {
    if let saved = windows[app.id] { return saved }
    let index = applications.firstIndex { $0.id == app.id } ?? 0
    let origin =
      app.defaultSize.width < 450
      ? CGPoint(x: 870, y: 400) : CGPoint(x: 48 + index * 24, y: 72 + index * 20)
    return WindowPlacement(origin: origin, size: app.defaultSize)
  }

  func place(_ app: any MiniApplication, at placement: WindowPlacement) {
    guard placement.isValid else { return }
    windows[app.id] = placement
    zoomedIDs.remove(app.id)
    persist()
  }

  func resetLayout() {
    windows = [:]
    zoomedIDs = []
    persist()
  }

  func snapshot() -> DesktopSession {
    let placements = Dictionary(
      uniqueKeysWithValues: applications.filter { openIDs.contains($0.id) }.map {
        ($0.id, placement(for: $0))
      })
    return DesktopSession(
      openIDs: openIDs, windows: placements, minimisedIDs: minimisedIDs.sorted(),
      zoomedIDs: zoomedIDs.sorted(), shadedIDs: shadedIDs.sorted())
  }

  func apply(_ session: DesktopSession) {
    let known = Set(applications.map(\.id))
    var seen = Set<String>()
    let requested = session.openIDs.filter { known.contains($0) && seen.insert($0).inserted }
    let other = openIDs.filter { !requested.contains($0) }
    // Keep other app views alive, including unsaved editors and drawings.
    openIDs = other + requested
    minimisedIDs = Set(other).union(Set(session.minimisedIDs ?? []).intersection(requested))
    zoomedIDs = zoomedIDs.intersection(other).union(
      Set(session.zoomedIDs ?? []).intersection(requested))
    shadedIDs = shadedIDs.intersection(other).union(
      Set(session.shadedIDs ?? []).intersection(requested))
    for (id, placement) in session.windows where known.contains(id) && placement.isValid {
      windows[id] = placement
    }
    persist()
  }

  private func persist() {
    store.save(
      DesktopSession(
        openIDs: openIDs, windows: windows,
        minimisedIDs: minimisedIDs.sorted(), zoomedIDs: zoomedIDs.sorted(),
        shadedIDs: shadedIDs.sorted()))
  }
}
