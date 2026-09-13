import MiniCore
import MiniUI
import SwiftUI

/// Window geometry uses the same reserved area for zooming, dragging, resizing and visibility.
struct DesktopDockLayout {
  static let reservedHeight: CGFloat = 88
  let iconSize: CGFloat
  let width: CGFloat
  let scrollWidth: CGFloat
  let overflows: Bool

  init(desktopWidth: CGFloat, entryCount: Int, hasMinimised: Bool) {
    let available = max(1, desktopWidth - 32)
    let count = CGFloat(max(1, entryCount))
    let decoration: CGFloat = 16 + max(0, count - 1) * 4 + (hasMinimised ? 16 : 0)
    iconSize = min(48, max(28, floor((available - decoration) / count) - 12))
    let content = count * (iconSize + 12) + decoration
    overflows = content > available
    width = min(available, content)
    scrollWidth = max(1, width - (overflows ? 52 : 0))
  }

  static func windowArea(desktop: CGSize, hasDock: Bool) -> CGSize {
    CGSize(width: desktop.width, height: max(1, desktop.height - (hasDock ? reservedHeight : 0)))
  }
}

struct DesktopDock: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let model: DesktopModel
  let desktopWidth: CGFloat
  let style: ThemeFrameStyle
  let focusRequest: Int
  @State private var hoveredID: String?
  @FocusState private var focusedID: String?

  private struct Entry: Identifiable {
    let app: any MiniApplication
    let minimised: Bool
    let id: String
    let label: String

    @MainActor init(app: any MiniApplication, minimised: Bool) {
      self.app = app
      self.minimised = minimised
      id = "\(minimised ? "window" : "app")-\(app.id)"
      label = app.name + (minimised ? " — minimised window" : "")
    }
  }

  private var entries: [Entry] {
    model.applications.map { Entry(app: $0, minimised: false) }
      + model.openIDs.compactMap { id in
        guard model.minimisedIDs.contains(id),
          let app = model.applications.first(where: { $0.id == id })
        else { return nil }
        return Entry(app: app, minimised: true)
      }
  }

  var body: some View {
    let entries = entries
    let layout = DesktopDockLayout(
      desktopWidth: desktopWidth, entryCount: entries.count,
      hasMinimised: !model.minimisedIDs.isEmpty)
    ScrollViewReader { proxy in
      HStack(spacing: 0) {
        if layout.overflows {
          scrollButton(
            "Show beginning of dock", symbol: "chevron.left.2"
          ) {
            focusedID = entries.first?.id
            if let id = entries.first?.id { proxy.scrollTo(id, anchor: .leading) }
          }
        }
        ScrollView(.horizontal) {
          HStack(spacing: 4) {
            ForEach(entries) { entry in
              if entry.minimised && entry.id == entries.first(where: \.minimised)?.id {
                Rectangle().fill(theme.ink.opacity(0.25)).frame(width: 1, height: 42)
                  .padding(.horizontal, 5.5).accessibilityHidden(true)
              }
              dockButton(entry, iconSize: layout.iconSize)
                .id(entry.id)
            }
          }.padding(.horizontal, 8).frame(height: 72)
        }
        .scrollIndicators(.hidden)
        .frame(width: layout.scrollWidth, height: 72)
        if layout.overflows {
          scrollButton(
            "Show end of dock", symbol: "chevron.right.2"
          ) {
            focusedID = entries.last?.id
            if let id = entries.last?.id { proxy.scrollTo(id, anchor: .trailing) }
          }
        }
      }
      .themeFrame(style)
      .overlay(alignment: .top) {
        if let entry = entries.first(where: { $0.id == (hoveredID ?? focusedID) }) {
          Text(entry.label).font(theme.typography.small)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.8), lineWidth: 1))
            .fixedSize().offset(y: -32).allowsHitTesting(false).accessibilityHidden(true)
        }
      }
      .onChange(of: focusRequest) { _, _ in focusedID = entries.first?.id }
      .onChange(of: focusedID) { _, id in
        if let id { proxy.scrollTo(id) }
      }
      .onChange(of: entries.map(\.id)) { _, ids in
        if let hoveredID, !ids.contains(hoveredID) { self.hoveredID = nil }
        if let focusedID, !ids.contains(focusedID) { self.focusedID = nil }
      }
      .onMoveCommand { direction in
        switch direction {
        case .left: moveFocus(-1, entries: entries)
        case .right: moveFocus(1, entries: entries)
        default: break
        }
      }
      .onExitCommand { focusedID = nil }
    }
    .padding(.bottom, 8)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Dock")
  }

  private func dockButton(_ entry: Entry, iconSize: CGFloat) -> some View {
    let running = model.openIDs.contains(entry.app.id)
    let highlighted = hoveredID == entry.id || focusedID == entry.id
    return Button {
      open(entry)
    } label: {
      VStack(spacing: 3) {
        Group {
          if entry.minimised {
            VStack(spacing: 0) {
              HStack(spacing: 2) {
                ForEach(0..<3) { _ in
                  Circle().fill(theme.ink.opacity(0.4)).frame(width: 3, height: 3)
                }
                Spacer(minLength: 0)
              }.padding(4).background(.white.opacity(0.8))
              PixelIcon(symbol: entry.app.icon.desktopSymbol, scale: iconSize / 26)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: iconSize, height: iconSize * 0.78)
            .background(theme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
              RoundedRectangle(cornerRadius: 3).strokeBorder(
                theme.ink.opacity(0.5), lineWidth: 0.75)
            )
            .frame(width: iconSize, height: iconSize)
          } else {
            PixelIcon(symbol: entry.app.icon.desktopSymbol, scale: iconSize / 16)
          }
        }
        .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 2)
        .offset(y: highlighted && !reduceMotion ? -3 : 0)
        Path { path in
          path.move(to: CGPoint(x: 4, y: 0))
          path.addLine(to: CGPoint(x: 8, y: 5))
          path.addLine(to: CGPoint(x: 0, y: 5))
          path.closeSubpath()
        }.fill(theme.ink).frame(width: 8, height: 5)
          .opacity(running && !entry.minimised ? 1 : 0)
      }
      .frame(width: iconSize + 12, height: 64)
      .background(
        highlighted ? .white.opacity(0.22) : .clear, in: RoundedRectangle(cornerRadius: 8)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .focusable()
    .focusEffectDisabled()
    .focused($focusedID, equals: entry.id)
    .onKeyPress(.space) {
      open(entry)
      return .handled
    }
    .onKeyPress(.return) {
      open(entry)
      return .handled
    }
    .onHover { hovering in
      hoveredID = hovering ? entry.id : (hoveredID == entry.id ? nil : hoveredID)
    }
    .accessibilityLabel("\(entry.minimised ? "Restore" : "Open") \(entry.app.name)")
    .accessibilityValue(
      entry.minimised ? "Minimised window" : (running ? "Running" : "Not running")
    )
    .help(entry.label)
  }

  private func open(_ entry: Entry) {
    focusedID = nil
    hoveredID = nil
    model.launch(entry.app)
  }

  private func scrollButton(_ label: String, symbol: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 11, weight: .bold))
        .frame(width: 26, height: 64).contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityLabel(label).help(label)
  }

  private func moveFocus(_ direction: Int, entries: [Entry]) {
    guard !entries.isEmpty else { return }
    let index = entries.firstIndex { $0.id == focusedID } ?? (direction > 0 ? -1 : entries.count)
    focusedID = entries[min(entries.count - 1, max(0, index + direction))].id
  }
}

extension MiniApplicationIcon {
  var desktopSymbol: PixelSymbol {
    switch self {
    case .folder: .folder
    case .computer: .computer
    case .activity: .activity
    case .clock: .clock
    case .settings: .settings
    case .teapot: .teapot
    case .aquarium: .aquarium
    case .scrapbook: .scrapbook
    case .calculator: .calculator
    case .puzzle: .puzzle
    case .disk: .disk
    case .chooser: .chooser
    case .wastebasket: .wastebasket
    case .printer: .printer
    }
  }
}
