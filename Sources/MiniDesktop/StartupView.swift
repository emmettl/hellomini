import MiniCore
import MiniUI
import SwiftUI

/// Gates desktop creation so its windows and keyboard handlers cannot receive startup input.
public struct StartupView<Content: View>: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var sequence = StartupSequence()
  private let playfulness: PlayfulnessSettings
  private let theme: MiniThemeDefinition
  private let content: () -> Content

  public init(
    playfulness: PlayfulnessSettings, theme: MiniThemeDefinition,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.playfulness = playfulness
    self.theme = theme
    self.content = content
  }

  public var body: some View {
    Group {
      if sequence.phase == .desktop || !playfulness.allows(MiniStartup.effect.id) || reduceMotion {
        content()
      } else {
        StartupScreen(sequence: sequence)
          .environment(\.miniTheme, theme)
          .foregroundStyle(theme.ink)
          .preferredColorScheme(theme.colorScheme)
          .background(DesktopWindowConfiguration())
      }
    }
    .task {
      await sequence.run(
        enabled: playfulness.allows(MiniStartup.effect.id), reduceMotion: reduceMotion)
    }
    .onChange(of: reduceMotion) { _, reduced in
      if reduced { sequence.skip() }
    }
    .onChange(of: playfulness.allows(MiniStartup.effect.id)) { _, allowed in
      if !allowed { sequence.skip() }
    }
  }
}

private struct StartupScreen: View {
  @Environment(\.miniTheme) private var theme
  let sequence: StartupSequence
  private let symbols: [PixelSymbol] = [.disk, .folder, .activity, .clock, .settings, .teapot]

  var body: some View {
    ZStack {
      ThemeSurfaceView(sequence.phase == .happyMac ? .solid(theme.paper) : theme.desktop)
      if sequence.phase == .happyMac {
        VStack(spacing: 24) {
          PixelIcon(symbol: .computer, scale: 4)
          Text("hello.").font(theme.typography.title)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Happy Macintosh. Starting Hello Mini.")
      } else {
        VStack(spacing: 24) {
          VStack(spacing: 22) {
            PixelIcon(symbol: .computer, scale: 3)
            Text("Welcome to Macintosh.").font(theme.typography.display(22))
            Text("Hello Mini").font(theme.typography.title)
            progressBar
            Text("A little desktop is waking up.").font(theme.typography.small)
          }
          .padding(32)
          .frame(width: 460)
          .themeFrame(theme.window)

          HStack(spacing: 16) {
            ForEach(symbols.indices, id: \.self) { index in
              PixelIcon(symbol: symbols[index], scale: 2)
                .opacity(index < sequence.progress ? 1 : 0)
            }
          }
          .frame(height: 32)
          .accessibilityHidden(true)
        }
      }
      VStack {
        Spacer()
        Button("Skip startup", action: sequence.skip)
          .buttonStyle(RetroButtonStyle())
          .keyboardShortcut(.cancelAction)
          .help("Press Escape to open the desktop immediately.")
          .padding(.bottom, 30)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ignoresSafeArea()
  }

  private var progressBar: some View {
    GeometryReader { geometry in
      Rectangle().fill(theme.ink)
        .frame(
          width: geometry.size.width * CGFloat(sequence.progress) / CGFloat(StartupSequence.steps))
    }
    .frame(height: 12)
    .padding(3)
    .overlay(Rectangle().strokeBorder(theme.ink, lineWidth: 1))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Startup presentation")
    .accessibilityValue("\(sequence.progress * 100 / StartupSequence.steps) percent")
  }
}
