import MiniCore
import MiniUI
import SwiftUI

struct ScrapbookShelfRow: View {
  @Environment(\.miniTheme) private var theme
  @Bindable var model: ScrapbookModel
  let scrap: Scrap
  let playfulness: PlayfulnessSettings?
  private var selected: Bool {
    model.selecting ? model.batchSelection.contains(scrap.id) : model.selection == scrap.id
  }
  private var title: String {
    let check = model.selecting ? (selected ? "☑ " : "☐ ") : ""
    return check + (scrap.isFavourite ? "★ " : "") + scrap.title
  }
  private var label: String {
    var parts = [scrap.title, scrap.kind.title, scrap.collection ?? "Unfiled"]
    if scrap.isFavourite { parts.append("favourite") }
    if model.selecting && selected { parts.append("selected for batch action") }
    return parts.joined(separator: ", ")
  }
  private var detail: String {
    guard scrap.kind == .image else { return scrap.kind.title }
    if model.reading == scrap.id { return "Image · reading text…" }
    return scrap.recognizedText?.isEmpty == false
      ? "Image · text searchable" : "Image · caption searchable"
  }
  var body: some View {
    Button {
      if model.selecting { model.toggleSelection(scrap.id) } else { model.selection = scrap.id }
    } label: {
      VStack(alignment: .leading, spacing: 5) {
        Text(title).font(theme.typography.title).lineLimit(2)
        Text(detail).font(theme.typography.small)
      }
      .padding(10).frame(maxWidth: .infinity, alignment: .leading)
      .foregroundStyle(selected ? theme.selectionInk : theme.ink)
      .background { if selected { ThemeSurfaceView(theme.selection) } }
      .contentShape(Rectangle())
    }.buttonStyle(.plain)
      .modifier(
        PaperShuffle(
          enabled: playfulness?.allows(ScrapbookApplication.filingEffect.id) == true,
          pulse: model.filingPulse)
      )
      .accessibilityLabel(label)
      .accessibilityAddTraits(selected ? .isSelected : [])
  }
}
