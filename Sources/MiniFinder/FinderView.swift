import MiniUI
import SwiftUI

struct FinderView: View {
  @Environment(\.miniTheme) private var theme
  @Bindable var model: FinderModel
  let findFile: () -> Void
  private let labelNames = ["None", "Gray", "Green", "Purple", "Blue", "Yellow", "Red", "Orange"]
  private let labelColors: [Color] = [
    .clear, .gray, .green, .purple, .blue, .yellow, .red, .orange,
  ]

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Button("Find…", action: findFile)
        Button("Back", action: model.goBack).disabled(!model.history.canGoBack)
        Button("Up", action: model.goUp).disabled(!model.history.canGoUp)
        Text(model.location.path)
          .font(theme.typography.small)
          .lineLimit(1)
          .truncationMode(.head)
          .textSelection(.enabled)
          .padding(.leading, 4)
          .miniHelp(model.location.path)
        Spacer(minLength: 0)
        Button(model.listView ? "Icons" : "List") { model.listView.toggle() }
          .accessibilityLabel(model.listView ? "Show as icons" : "Show as list")
      }
      .buttonStyle(RetroButtonStyle())
      .padding(10)
      Rectangle().frame(height: 1)
      HStack(spacing: 0) {
        GeometryReader { geometry in
          ScrollView {
            sidebar.frame(minHeight: geometry.size.height)
          }
        }
        .frame(width: 144)
        Rectangle().frame(width: 1)
        VStack(spacing: 0) {
          if let error = model.error {
            VStack(alignment: .leading, spacing: 8) {
              Text("Something needs your attention.").font(theme.typography.title)
              Text(error).font(theme.typography.small).fixedSize(horizontal: false, vertical: true)
              HStack {
                Button("Try Again", action: model.reload)
                Button("Choose Folder…", action: model.chooseFolder)
              }
              .buttonStyle(RetroButtonStyle())
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().frame(height: 1)
          }
          if model.isLoading {
            message("Reading disk…", symbol: .disk)
          } else if model.entries.isEmpty && model.error == nil {
            message("This folder is empty.", symbol: .folder)
          } else {
            ScrollView {
              if model.listView {
                LazyVStack(spacing: 0) {
                  ForEach(model.entries) { entry in fileRow(entry) }
                }
                .padding(8)
              } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 102), spacing: 8)], spacing: 16) {
                  ForEach(model.entries) { entry in fileIcon(entry) }
                }
                .padding(18)
              }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        }
      }
      Rectangle().frame(height: 1)
      HStack {
        Text(
          model.isLoading
            ? "Reading…" : "\(model.entries.count) \(model.entries.count == 1 ? "item" : "items")")
        Spacer()
        if let selected = model.selectedEntry {
          Text(selected.name).lineLimit(1)
        } else {
          Text("Double-click to open")
        }
      }
      .font(theme.typography.small)
      .padding(.horizontal, 12)
      .frame(height: 28)
    }
    .font(theme.typography.body)
    .onAppear { model.reload() }
    .onChange(of: model.showHidden) { model.reload() }
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("PLACES").font(theme.typography.small).padding(.horizontal, 12).padding(.bottom, 10)
      place("Home", url: FileManager.default.homeDirectoryForCurrentUser, symbol: .computer)
      place(
        "Desktop",
        url: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"))
      place(
        "Documents",
        url: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents"))
      place(
        "Downloads",
        url: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"))
      Rectangle().frame(height: 1).padding(.vertical, 12).padding(.horizontal, 12)
      place("Macintosh HD", url: URL(fileURLWithPath: "/"), symbol: .disk)
      Spacer()
      Button("Other folder…", action: model.chooseFolder)
        .buttonStyle(.plain)
        .padding(12)
    }
    .padding(.top, 18)
    .frame(maxHeight: .infinity)
  }

  private func place(_ name: String, url: URL, symbol: PixelSymbol = .folder) -> some View {
    Button {
      model.navigate(to: url)
    } label: {
      HStack(spacing: 8) {
        PixelIcon(symbol: symbol, scale: 1, selected: model.location == url)
        Text(name).font(theme.typography.small)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 12)
      .frame(height: 32)
      .foregroundStyle(model.location == url ? theme.selectionInk : theme.ink)
      .background { ThemeSurfaceView(model.location == url ? theme.selection : .solid(.clear)) }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Open \(name)")
  }

  private func fileIcon(_ entry: FileEntry) -> some View {
    VStack(spacing: 7) {
      PixelIcon(symbol: entry.isBrowsable ? .folder : .document)
        .overlay(alignment: .bottomTrailing) { labelDot(entry) }
      Text(entry.name)
        .font(theme.typography.small)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
        .foregroundStyle(model.selection == entry.url ? theme.selectionInk : theme.ink)
        .background {
          ThemeSurfaceView(model.selection == entry.url ? theme.selection : .solid(.clear))
        }
    }
    .frame(maxWidth: .infinity)
    .frame(height: 84, alignment: .top)
    .contentShape(Rectangle())
    .onTapGesture(count: 2) { model.open(entry) }
    .onTapGesture { model.selection = entry.url }
    .contextMenu { entryMenu(entry) }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(entry.name)
    .accessibilityValue(entry.isBrowsable ? "Folder" : "File")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { model.open(entry) }
    .miniHelp(entry.name)
  }

  private func fileRow(_ entry: FileEntry) -> some View {
    HStack(spacing: 10) {
      PixelIcon(
        symbol: entry.isBrowsable ? .folder : .document, scale: 1,
        selected: model.selection == entry.url)
      labelDot(entry)
      Text(entry.name).lineLimit(1)
      Spacer()
      Text(
        entry.isBrowsable
          ? "Folder" : ByteCountFormatter.string(fromByteCount: entry.byteCount, countStyle: .file)
      )
      .font(theme.typography.small)
    }
    .padding(.horizontal, 8)
    .frame(height: 30)
    .foregroundStyle(model.selection == entry.url ? theme.selectionInk : theme.ink)
    .background {
      ThemeSurfaceView(model.selection == entry.url ? theme.selection : .solid(.clear))
    }
    .contentShape(Rectangle())
    .onTapGesture(count: 2) { model.open(entry) }
    .onTapGesture { model.selection = entry.url }
    .contextMenu { entryMenu(entry) }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(entry.name)
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { model.open(entry) }
  }

  @ViewBuilder private func entryMenu(_ entry: FileEntry) -> some View {
    Button("Open") { model.open(entry) }
    Menu("Label") {
      ForEach(0...7, id: \.self) { index in
        Button((entry.labelNumber == index ? "✓ " : "") + labelNames[index]) {
          model.setLabel(index, entry: entry)
        }
      }
    }
    Button("Reveal in macOS Finder") {
      model.selection = entry.url
      model.revealSelection()
    }
  }

  @ViewBuilder private func labelDot(_ entry: FileEntry) -> some View {
    if (1...7).contains(entry.labelNumber) {
      Circle().fill(labelColors[entry.labelNumber]).frame(width: 10, height: 10)
        .overlay(Circle().strokeBorder(theme.ink.opacity(0.5), lineWidth: 0.5))
        .accessibilityLabel(labelNames[entry.labelNumber] + " label")
        .miniHelp(labelNames[entry.labelNumber] + " Finder label")
    }
  }

  private func message(_ text: String, symbol: PixelSymbol) -> some View {
    VStack(spacing: 16) {
      PixelIcon(symbol: symbol)
      Text(text)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
