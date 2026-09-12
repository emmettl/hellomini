import AppKit
import MiniCore
import MiniUI
import Observation
import SwiftUI

@MainActor public final class TeapotApplication: MiniApplication {
  public let id = "teapot"
  public let name = "Teapot"
  public let icon = MiniApplicationIcon.teapot
  public let defaultSize = CGSize(width: 650, height: 480)
  public let minimumSize = CGSize(width: 650, height: 360)
  public static let rotationEffect = MiniPlayfulEffect(
    id: "teapot.rotation", name: "Teapot animation",
    description: "Let the teapot spin by itself. Manual rotation always works.")
  private let model = TeapotModel()
  private let playfulness: PlayfulnessSettings
  public init(playfulness: PlayfulnessSettings) { self.playfulness = playfulness }
  public func content() -> AnyView {
    AnyView(TeapotView(playfulness: playfulness, model: model))
  }
  public var menus: [RetroMenu] {
    [
      RetroMenu(
        id: "teapot", title: "Teapot", width: 270,
        items: [
          RetroMenuItem(
            id: "spin", title: model.spinning ? "Pause Rotation" : "Resume Rotation",
            shortcut: RetroShortcut(key: "p", label: "⌘P"),
            enabled: playfulness.allows(Self.rotationEffect.id)
          ) { self.model.spinning.toggle() },
          RetroMenuItem(id: "reset-teapot", title: "Reset View", action: model.reset),
          .separator("shading"),
        ]
          + TeapotMode.allCases.map { mode in
            RetroMenuItem(
              id: "shading-\(mode.rawValue)", title: mode.name, checked: model.mode == mode
            ) { self.model.mode = mode }
          })
    ]
  }
}

enum TeapotMode: Int, CaseIterable {
  case dither, smooth, wireframe
  var name: String {
    switch self {
    case .dither: "Dither"
    case .smooth: "Smooth"
    case .wireframe: "Wireframe"
    }
  }
}

@MainActor @Observable final class TeapotModel {
  var spinning = true
  var mode = TeapotMode.dither
  var speed: Float = 0.5
  var yaw: Float = -0.35
  var tilt: Float = 0.3
  var error: String?
  var resetRevision = 0
  // Render-loop state is intentionally not observed by SwiftUI.
  @ObservationIgnored var rotation: Float = 0
  func reset() {
    resetRevision += 1
    rotation = 0
    yaw = -0.35
    tilt = 0.3
    speed = 0.5
  }
}

private struct TeapotView: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.self) private var environment
  let playfulness: PlayfulnessSettings
  @Bindable var model: TeapotModel
  @State private var active = NSApp.isActive

  private var rotationAllowed: Bool { playfulness.allows(TeapotApplication.rotationEffect.id) }
  private var status: String {
    if reduceMotion { return "Reduced motion · manual rotation" }
    if !rotationAllowed { return "Animation off in Control Panel" }
    return "\(model.mode.name) · use arrows to rotate"
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Button(model.spinning ? "Pause" : "Spin") { model.spinning.toggle() }
          .accessibilityLabel(model.spinning ? "Pause teapot rotation" : "Resume teapot rotation")
          .disabled(reduceMotion || !rotationAllowed)
        ForEach(TeapotMode.allCases, id: \.rawValue) { mode in
          Button(model.mode == mode ? "✓ " + mode.name : mode.name) { model.mode = mode }
            .accessibilityLabel(mode.name)
            .accessibilityValue(model.mode == mode ? "Selected" : "Not selected")
            .accessibilityAddTraits(model.mode == mode ? .isSelected : [])
        }
        Spacer(minLength: 0)
        Button("←") { model.yaw -= .pi / 8 }.accessibilityLabel("Rotate teapot left")
        Button("→") { model.yaw += .pi / 8 }.accessibilityLabel("Rotate teapot right")
        Button("Reset", action: model.reset)
      }
      .buttonStyle(RetroButtonStyle())
      .padding(10)
      Rectangle().frame(height: 1)
      ZStack {
        if let error = model.error {
          VStack(spacing: 12) {
            PixelIcon(symbol: .teapot)
            Text("The teapot couldn't start.").font(theme.typography.title)
            Text(error).font(theme.typography.small).multilineTextAlignment(.center)
          }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          TeapotMetalView(
            model: model, ink: rgba(theme.ink), paper: rgba(theme.paper),
            animate: model.spinning && active && !reduceMotion && rotationAllowed,
            mode: model.mode, yaw: model.yaw, tilt: model.tilt, resetRevision: model.resetRevision
          )

        }
      }
      .clipped()
      Rectangle().frame(height: 1)
      HStack {
        Text("UTAH TEAPOT").font(theme.typography.small)
        Spacer()
        Text(status)
          .font(theme.typography.small)
      }.padding(.horizontal, 12).frame(height: 28)
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    { _ in active = true }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification))
    { _ in active = false }
  }

  private func rgba(_ color: Color) -> SIMD4<Float> {
    let resolved = color.resolve(in: environment)
    return SIMD4(resolved.red, resolved.green, resolved.blue, resolved.opacity)
  }
}
