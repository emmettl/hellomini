import AppKit
import MiniCore
import MiniUI
import SwiftUI

@MainActor public final class KeyCapsApplication: MiniApplication {
  public let id = "key-caps"
  public let name = "Key Caps"
  public let icon = MiniApplicationIcon.calculator
  public let defaultSize = CGSize(width: 600, height: 380)
  public let minimumSize = CGSize(width: 490, height: 240)
  public init() {}
  public func content() -> AnyView { AnyView(KeyCapsView()) }
}

struct KeyCapsView: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.miniWindowActive) private var active
  @Environment(\.miniWindowVisible) private var visible
  @Environment(\.miniDesktopSuspended) private var suspended
  @Environment(\.scenePhase) private var scenePhase
  @State private var pressed = Set<UInt16>()
  @State private var modifiers: NSEvent.ModifierFlags = []
  @State private var shifted = false
  @State private var symbols = false
  @State private var custom = ""
  @State private var notice = "Click a key to copy it. US keyboard layout."
  private let rows = ["1234567890-=", "qwertyuiop[]", "asdfghjkl;'", "zxcvbnm,./"]
  private let upperRows = ["!@#$%^&*()_+", "QWERTYUIOP{}", "ASDFGHJKL:\"", "ZXCVBNM<>?"]
  private let characters = Array("⌘⌥⇧⌃⎋⌫↩⇥←→↑↓±×÷≠≤≥∞πµ°©®™€£¥•…—“”‘’✓✗♥★😀😂🥹😍🤔🙃😎😭👍👋🎉🐟🐠🐕🖨️💾🗑️☕🍅")
  private var inputEnabled: Bool { active && visible && !suspended && scenePhase == .active }
  private var showingShift: Bool {
    shifted || modifiers.contains(.shift)
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        ViewThatFits(in: .horizontal) {
          header(short: false)
          header(short: true)
        }.buttonStyle(RetroButtonStyle())
        Group {
          if symbols {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 34))], spacing: 6) {
              ForEach(Array(characters.enumerated()), id: \.offset) { _, char in key(String(char)) }
            }
          } else {
            VStack(spacing: 6) {
              ForEach(0..<rows.count, id: \.self) { row in
                HStack(spacing: 5) {
                  ForEach(
                    Array(
                      KeyCapsInput.characters(
                        rows[row], shifted: upperRows[row], shift: showingShift,
                        caps: modifiers.contains(.capsLock)
                      ).enumerated()), id: \.offset
                  ) {
                    index, char in
                    key(String(char), pressed: pressed.contains(KeyCapsInput.rows[row][index]))
                  }
                }.padding(.leading, CGFloat(row) * 8)
              }
              Button(pressed.contains(49) ? "Space · pressed" : "Space") { copy(" ") }.frame(
                width: 210
              ).buttonStyle(RetroButtonStyle())
            }.miniControlBounds("keycaps.keyboard")
          }
        }
        HStack {
          TextField("Any Unicode text", text: $custom).onSubmit { copy(custom) }
          Button("Copy") { copy(custom) }.disabled(custom.isEmpty).buttonStyle(RetroButtonStyle())
        }
        HStack(spacing: 8) {
          modifier("⇧", name: "Shift", flag: .shift)
          modifier("⌃", name: "Control", flag: .control)
          modifier("⌥", name: "Option", flag: .option)
          modifier("⌘", name: "Command", flag: .command)
          modifier("⇪", name: "Caps Lock", flag: .capsLock)
        }.accessibilityElement(children: .contain)
        Text("Live keys while this accessory is active · US positions")
          .font(theme.typography.small)
        Text(notice).font(theme.typography.small).lineLimit(2)
      }.padding(12)
    }
    .background(
      KeyCapsEventSource(
        enabled: inputEnabled
      ) { keys, flags in
        pressed = keys
        modifiers = flags
      }.frame(width: 0, height: 0).accessibilityHidden(true)
    )
    .onChange(of: inputEnabled) { _, enabled in
      if !enabled {
        pressed = []
        modifiers = []
      }
    }
  }
  private func header(short: Bool) -> some View {
    HStack {
      Toggle("Shift", isOn: $shifted)
      Toggle(short ? "Symbols" : "Symbols & emoji", isOn: $symbols)
        .accessibilityLabel("Symbols and emoji")
      Spacer(minLength: 4)
      Button(short ? "Characters…" : "macOS Characters…") { NSApp.orderFrontCharacterPalette(nil) }
        .accessibilityLabel("macOS Characters")
    }
  }

  private func modifier(_ title: String, name: String, flag: NSEvent.ModifierFlags) -> some View {
    Text(title).font(theme.typography.body)
      .padding(3)
      .foregroundStyle(modifiers.contains(flag) ? theme.paper : theme.ink)
      .background(modifiers.contains(flag) ? theme.ink : theme.paper)
      .accessibilityLabel(name + (modifiers.contains(flag) ? " pressed" : " released"))
  }
  private func key(_ value: String, pressed: Bool = false) -> some View {
    Button {
      copy(value)
    } label: {
      Text(value).font(.system(size: 17)).frame(width: 31, height: 32)
        .foregroundStyle(pressed ? theme.paper : theme.ink)
        .background(pressed ? theme.ink : theme.paper)
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.ink, lineWidth: 1))
    }.buttonStyle(.plain).accessibilityLabel("Copy " + value)
  }
  private func copy(_ value: String) {
    guard !value.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
    notice =
      "Copied " + (value == " " ? "Space" : value) + " · "
      + value.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " ")
  }
}
