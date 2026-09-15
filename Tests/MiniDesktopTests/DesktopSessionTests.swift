import AppKit
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

@Test @MainActor func dockKeepsZoomDragAndResizeClearWithoutChangingSavedGeometry() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let app = SessionTestApp("a")
  let model = DesktopModel(applications: [app], initiallyOpen: [app.id], defaults: defaults)
  let saved = WindowPlacement(
    origin: CGPoint(x: 700, y: 400), size: CGSize(width: 550, height: 300))
  model.place(app, at: saved)
  let desktop = CGSize(width: 1280, height: 720)
  let area = DesktopDockLayout.windowArea(desktop: desktop, hasDock: true)
  #expect(area == CGSize(width: 1280, height: 632))
  let bounds = WindowBounds(desktopSize: area, windowSize: saved.size, menuBarHeight: 28)
  #expect(bounds.constrain(saved.origin).y + saved.size.height == area.height - 8)
  var resize = WindowResize(origin: CGPoint(x: 100, y: 90), size: saved.size, startLocation: .zero)
  resize.location = CGPoint(x: 2000, y: 2000)
  #expect(
    resize.size(minimum: app.minimumSize, desktop: area).height + resize.origin.y == area.height - 8
  )
  model.toggleZoom(app)
  let zoomed = model.displayedPlacement(for: app, desktop: area, menuBarHeight: 28)
  #expect(zoomed.origin.y + zoomed.size.height == area.height - 8)
  #expect(model.placement(for: app) == saved)
  let classicArea = DesktopDockLayout.windowArea(desktop: desktop, hasDock: false)
  #expect(classicArea == desktop)
  let classicZoom = model.displayedPlacement(for: app, desktop: classicArea, menuBarHeight: 30)
  #expect(classicZoom.origin.y + classicZoom.size.height == desktop.height - 8)
  model.toggleZoom(app)
  #expect(model.placement(for: app) == saved)
}

@Test func dockFitsTheAppLineupAndProvidesOverflowForCrowdedDesktops() {
  for width: CGFloat in [640, 800, 960, 1280, 1920] {
    for count in [15, 22, 30, 60] {
      let layout = DesktopDockLayout(
        desktopWidth: width, entryCount: count, hasMinimised: count > 15)
      #expect(layout.width <= width - 32)
      #expect(layout.iconSize >= 28 && layout.iconSize <= 48)
      #expect(layout.scrollWidth > 0 && layout.scrollWidth <= layout.width)
      #expect(layout.overflows == (layout.scrollWidth < layout.width))
    }
  }
  #expect(!DesktopDockLayout(desktopWidth: 1280, entryCount: 15, hasMinimised: false).overflows)
  #expect(DesktopDockLayout(desktopWidth: 640, entryCount: 30, hasMinimised: true).overflows)
  #expect(DesktopDockLayout(desktopWidth: 1280, entryCount: 0, hasMinimised: false).width.isFinite)
}

@Test @MainActor func puristDesktopLeavesWindowChromeReachableAndPreservesNormalPlacement() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let app = SessionTestApp("a")
  let model = DesktopModel(applications: [app], initiallyOpen: [app.id], defaults: defaults)
  let saved = WindowPlacement(
    origin: CGPoint(x: 900, y: 450), size: CGSize(width: 800, height: 500))
  model.place(app, at: saved)
  for hasDock in [true, false] {
    let area = DesktopDockLayout.windowArea(
      desktop: CGSize(width: 512, height: 384), hasDock: hasDock)
    let size = WindowResize.constrain(
      saved.size, minimum: app.minimumSize,
      maximum: CGSize(width: area.width - 16, height: area.height - 46))
    let origin = WindowBounds(desktopSize: area, windowSize: size, menuBarHeight: 28).constrain(
      saved.origin)
    #expect(origin.x >= 8 && origin.y >= 38)
    #expect(origin.x + size.width <= area.width - 8)
    #expect(origin.y + size.height <= area.height - 8)
    #expect(model.placement(for: app) == saved)
  }
}

@Test func undersizedWindowsScrollTheirMinimumContentWithoutShrinkingControls() {
  let normal = WindowContentLayout(
    window: CGSize(width: 800, height: 500),
    minimum: CGSize(width: 640, height: 400), chromeHeight: 48)
  #expect(normal.scrollAxes.isEmpty)
  #expect(normal.visible == normal.content)
  let purist = WindowContentLayout(
    window: CGSize(width: 496, height: 250),
    minimum: CGSize(width: 640, height: 400), chromeHeight: 48)
  #expect(purist.visible == CGSize(width: 496, height: 202))
  #expect(purist.content == CGSize(width: 640, height: 352))
  #expect(purist.scrollAxes == [.horizontal, .vertical])
  let narrow = WindowContentLayout(
    window: CGSize(width: 496, height: 500),
    minimum: CGSize(width: 640, height: 400), chromeHeight: 48)
  #expect(narrow.scrollAxes == .horizontal)
}

@Test @MainActor func puristCanvasStays512By384InsideALargerWindow() throws {
  let view = MiniDisplayViewport(puristMode: true) {
    Color(.sRGB, red: 1, green: 0, blue: 0, opacity: 1)
  }
  .frame(width: 1280, height: 720)
  let image = NSBitmapImageRep(cgImage: try #require(ImageRenderer(content: view).cgImage))
  func red(_ x: Int, _ y: Int) -> Bool {
    guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return false }
    return color.redComponent > color.greenComponent + 0.2
      && color.redComponent > color.blueComponent + 0.2
  }
  #expect(red(400, 168))
  #expect(red(879, 551))
  // The screen retains its rounded corners and inset bevel in a larger/full-screen viewport.
  #expect(!red(384, 168))
  #expect(!red(895, 551))
  #expect(!red(383, 168))
  #expect(!red(384, 167))
  #expect(!red(896, 551))
  #expect(!red(895, 552))
}

@Test @MainActor func windowShadeRollsUpSurvivesRelaunchAndClearsOnClose() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let first = SessionTestApp("a")
  let second = SessionTestApp("b")
  let model = DesktopModel(
    applications: [first, second], initiallyOpen: [first.id, second.id], defaults: defaults)
  model.toggleShade(first)
  model.toggleShade(SessionTestApp("never-opened"))
  #expect(model.shadedIDs == [first.id])
  let relaunched = DesktopModel(
    applications: [first, second], initiallyOpen: [], defaults: defaults)
  #expect(relaunched.shadedIDs == [first.id])
  model.toggleShade(second)
  model.close(second)
  #expect(model.shadedIDs == [first.id])
  model.toggleShade(first)
  #expect(model.shadedIDs.isEmpty)
  #expect(
    DesktopModel(applications: [first, second], initiallyOpen: [], defaults: defaults).shadedIDs
      .isEmpty)
}
