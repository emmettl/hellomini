import AppKit
import MiniUI
import SwiftUI

struct FileInspectionView: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  let inspection: FileInspection
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(inspection.title).font(theme.typography.title).lineLimit(2)
      if let data = inspection.image, let image = NSImage(data: data) {
        Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 150)
          .accessibilityLabel("File image preview")
      }
      if let text = inspection.text {
        ScrollView([.horizontal, .vertical]) {
          Text(text).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }.frame(height: 100)
      }
      Text(inspection.details).font(theme.typography.small).textSelection(.enabled)
      HStack {
        Spacer()
        Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
      }
      .buttonStyle(RetroButtonStyle())
    }.padding(12).frame(width: 400).foregroundStyle(theme.ink).background(theme.paper)
  }
}
