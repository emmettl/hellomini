import AppKit
import MiniCore
import MiniUI
import SwiftUI

@MainActor public final class KeyCapsApplication: MiniApplication {
  public let id = "key-caps"
  public let name = "Key Caps"
  public let icon = MiniApplicationIcon.calculator
  public let defaultSize = CGSize(width: 600, height: 380)
  public let minimumSize = CGSize(width: 510, height: 330)
  public init() {}
  public func content() -> AnyView { AnyView(KeyCapsView()) }
}

private struct KeyCapsView: View {
  @Environment(\.miniTheme) private var theme
  @State private var shifted = false
  @State private var symbols = false
  @State private var custom = ""
  @State private var notice = "Click a key to copy it. US keyboard layout."
  private let rows = ["1234567890-=", "qwertyuiop[]", "asdfghjkl;'", "zxcvbnm,./"]
  private let upperRows = ["!@#$%^&*()_+", "QWERTYUIOP{}", "ASDFGHJKL:\"", "ZXCVBNM<>?"]
  private let characters = Array("⌘⌥⇧⌃⎋⌫↩⇥←→↑↓±×÷≠≤≥∞πµ°©®™€£¥•…—“”‘’✓✗♥★😀😂🥹😍🤔🙃😎😭👍👋🎉🐟🐠🐕🖨️💾🗑️☕🍅")
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Toggle("Shift", isOn: $shifted)
        Toggle("Symbols & emoji", isOn: $symbols)
        Spacer()
        Button("macOS Characters…") { NSApp.orderFrontCharacterPalette(nil) }
      }.buttonStyle(RetroButtonStyle())
      ScrollView {
        if symbols {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 34))], spacing: 6) {
            ForEach(Array(characters.enumerated()), id: \.offset) { _, char in key(String(char)) }
          }
        } else {
          VStack(spacing: 6) {
            ForEach(0..<rows.count, id: \.self) { row in
              HStack(spacing: 5) {
                ForEach(Array((shifted ? upperRows[row] : rows[row]).enumerated()), id: \.offset) {
                  _, char in
                  key(String(char))
                }
              }.padding(.leading, CGFloat(row) * 8)
            }
            Button("Space") { copy(" ") }.frame(width: 210).buttonStyle(RetroButtonStyle())
          }
        }
      }
      HStack {
        TextField("Any Unicode text", text: $custom).onSubmit { copy(custom) }
        Button("Copy") { copy(custom) }.disabled(custom.isEmpty).buttonStyle(RetroButtonStyle())
      }
      Text(notice).font(theme.typography.small).lineLimit(2)
    }.padding(16)
  }
  private func key(_ value: String) -> some View {
    Button {
      copy(value)
    } label: {
      Text(value).font(.system(size: 17)).frame(width: 31, height: 32)
        .foregroundStyle(theme.ink).background(theme.paper)
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
