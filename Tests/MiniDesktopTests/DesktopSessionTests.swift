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
