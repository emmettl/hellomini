import Foundation
import MiniCore
import SwiftUI
import Testing

@testable import MiniDesktop

@MainActor private final class SessionTestApp: MiniApplication {
  let id: String
  var name: String { id }
  let icon = MiniApplicationIcon.computer
  let defaultSize = CGSize(width: 400, height: 300)
  init(_ id: String) { self.id = id }
  func content() -> AnyView { AnyView(EmptyView()) }
}

@Test @MainActor func desktopRestoresOpenAppsTheirOrderAndWindowGeometry() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let a = SessionTestApp("a")
  let b = SessionTestApp("b")
  let c = SessionTestApp("c")
  let model = DesktopModel(applications: [a, b, c], initiallyOpen: [a.id], defaults: defaults)
  model.launch(b)
  model.launch(c)
  model.launch(a)
  let placement = WindowPlacement(
    origin: CGPoint(x: 150, y: 90), size: CGSize(width: 600, height: 450))
  model.place(b, at: placement)
  let restored = DesktopModel(applications: [a, b, c], initiallyOpen: [], defaults: defaults)
  #expect(restored.openIDs == [b.id, c.id, a.id])
  #expect(restored.active?.id == a.id)
  #expect(restored.placement(for: b) == placement)
  restored.close(b)
  restored.launch(b)
  #expect(restored.placement(for: b) == placement)
  restored.resetLayout()
  #expect(restored.placement(for: b).size == b.defaultSize)
  let reset = DesktopModel(applications: [a, b, c], initiallyOpen: [], defaults: defaults)
  #expect(reset.placement(for: b).size == b.defaultSize)
  #expect(reset.openIDs == [c.id, a.id, b.id])
}

@Test @MainActor func anEmptySavedDesktopStaysEmptyAndUnavailableAppsAreIgnored() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let app = SessionTestApp("a")
  let model = DesktopModel(applications: [app], initiallyOpen: [app.id], defaults: defaults)
  model.close(app)
  #expect(
    DesktopModel(applications: [app], initiallyOpen: [app.id], defaults: defaults).openIDs.isEmpty)
  DesktopSessionStore(defaults: defaults).save(
    DesktopSession(openIDs: ["missing", app.id, app.id], windows: [:]))
  #expect(
    DesktopModel(applications: [app], initiallyOpen: [], defaults: defaults).openIDs == [app.id])
}

@Test @MainActor func corruptOrFutureSessionsFallBackAndInvalidGeometryIsDiscarded() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let store = DesktopSessionStore(defaults: defaults)
  let app = SessionTestApp("a")
  defaults.set(Data("broken".utf8), forKey: DesktopSessionStore.key)
  #expect(store.load() == nil)
  #expect(
    DesktopModel(applications: [app], initiallyOpen: [app.id], defaults: defaults).openIDs == [
      app.id
    ])
  store.save(DesktopSession(version: 99, openIDs: [], windows: [:]))
  #expect(store.load() == nil)
  store.save(
    DesktopSession(
      openIDs: [app.id],
      windows: [
        app.id: WindowPlacement(origin: .zero, size: CGSize(width: -1, height: 300))
      ]))
  #expect(store.load()?.windows.isEmpty == true)
  #expect(store.load()?.openIDs == [app.id])
}

@Test @MainActor func minimisingPreservesOpenWindowsAndRestoresFocusAndSession() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let a = SessionTestApp("a")
  let b = SessionTestApp("b")
  let model = DesktopModel(applications: [a, b], initiallyOpen: [a.id, b.id], defaults: defaults)
  let placement = WindowPlacement(
    origin: CGPoint(x: 90, y: 70), size: CGSize(width: 510, height: 400))
  model.place(b, at: placement)
  model.minimise(b)
  #expect(model.openIDs == [a.id, b.id])
  #expect(model.visibleIDs == [a.id])
  #expect(model.active?.id == a.id)
  let restored = DesktopModel(applications: [a, b], initiallyOpen: [], defaults: defaults)
  #expect(restored.minimisedIDs == [b.id])
  #expect(restored.active?.id == a.id)
  restored.minimise(a)
  #expect(restored.active == nil)
  restored.launch(b)
  #expect(restored.active?.id == b.id)
  #expect(restored.visibleIDs == [b.id])
  #expect(restored.placement(for: b) == placement)
  restored.close(a)
  #expect(restored.minimisedIDs.isEmpty)
}

@Test @MainActor func zoomPreservesNormalGeometryAcrossDisplaysAndRelaunch() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let app = SessionTestApp("a")
  let model = DesktopModel(applications: [app], initiallyOpen: [app.id], defaults: defaults)
  let normal = WindowPlacement(
    origin: CGPoint(x: 120, y: 90), size: CGSize(width: 560, height: 410))
  model.place(app, at: normal)
  model.toggleZoom(app)
  let large = model.displayedPlacement(
    for: app, desktop: CGSize(width: 1280, height: 720), menuBarHeight: 28)
  #expect(
    large == WindowPlacement(origin: CGPoint(x: 8, y: 38), size: CGSize(width: 1264, height: 674)))
  #expect(model.placement(for: app) == normal)
  let restored = DesktopModel(applications: [app], initiallyOpen: [], defaults: defaults)
  #expect(restored.zoomedIDs == [app.id])
  let small = restored.displayedPlacement(
    for: app, desktop: CGSize(width: 800, height: 600), menuBarHeight: 30)
  #expect(
    small == WindowPlacement(origin: CGPoint(x: 8, y: 40), size: CGSize(width: 784, height: 552)))
  restored.minimise(app)
  restored.launch(app)
  #expect(restored.zoomedIDs == [app.id])
  restored.toggleZoom(app)
  #expect(
    restored.displayedPlacement(
      for: app, desktop: CGSize(width: 1280, height: 720), menuBarHeight: 28) == normal)
  restored.toggleZoom(app)
  restored.place(app, at: large)
  #expect(restored.zoomedIDs.isEmpty)
  restored.toggleZoom(app)
  restored.resetLayout()
  #expect(restored.zoomedIDs.isEmpty)
  #expect(restored.placement(for: app).size == app.defaultSize)
  restored.toggleZoom(app)
  restored.close(app)
  #expect(restored.zoomedIDs.isEmpty)
}

@Test @MainActor func legacySessionsAndUnknownWindowStatesRemainSafe() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let app = SessionTestApp("a")
  defaults.set(
    Data(#"{"version":1,"openIDs":["a"],"windows":{}}"#.utf8), forKey: DesktopSessionStore.key)
  let legacy = DesktopModel(applications: [app], initiallyOpen: [], defaults: defaults)
  #expect(legacy.visibleIDs == [app.id])
  #expect(legacy.zoomedIDs.isEmpty)
  DesktopSessionStore(defaults: defaults).save(
    DesktopSession(
      openIDs: [app.id], windows: [:], minimisedIDs: ["missing", "closed", app.id],
      zoomedIDs: ["missing"]))
  let restored = DesktopModel(
    applications: [app, SessionTestApp("closed")], initiallyOpen: [], defaults: defaults)
  #expect(restored.minimisedIDs == [app.id])
  #expect(restored.zoomedIDs.isEmpty)
}
