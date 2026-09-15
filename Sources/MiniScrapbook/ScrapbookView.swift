import AppKit
import MiniUI
import SwiftUI

struct ScrapbookView: View {
  @Environment(\.miniTheme) private var theme
  @Bindable var model: ScrapbookModel
  @State private var width: CGFloat = 760
  private var narrow: Bool { width < 600 }

  var body: some View {
    VStack(spacing: 0) {
      ViewThatFits(in: .horizontal) {
        toolbar(short: false)
        toolbar(short: true)
      }.buttonStyle(RetroButtonStyle()).disabled(!model.canChange).padding(narrow ? 8 : 10)
      Rectangle().frame(height: 1)
      HStack(spacing: 0) {
        shelf.frame(width: narrow ? max(150, width * 0.36) : 226)
        Rectangle().frame(width: 1)
        if let scrap = model.selected {
          detail(scrap).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          VStack(spacing: 16) {
            PixelIcon(symbol: .scrapbook, scale: 4)
            Text(
              !model.ready
                ? (model.error == nil ? "Opening the scrapbook…" : "The scrapbook is unavailable.")
                : model.query.isEmpty
                  ? (model.showArchive ? "Nothing in the archive." : "A page for whatever matters.")
                  : "No matching scraps."
            )
            .font(theme.typography.title)
            Text("Notes, commands, links, and pictures.\nSurprisingly little glue.")
              .font(theme.typography.small).multilineTextAlignment(.center)
          }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      Rectangle().frame(height: 1)
      if let error = model.error {
        HStack(alignment: .top) {
          Text(error).font(theme.typography.small).textSelection(.enabled)
          Spacer(minLength: 4)
          if !model.ready {
            Button("Retry") { Task { await model.load() } }.disabled(model.busy)
          } else {
            Button("Dismiss") { model.error = nil }
          }
        }.buttonStyle(RetroButtonStyle()).padding(10)
      } else {
        HStack {
          Text(
            "\(model.visible.count) \(model.showArchive ? "archived" : model.visible.count == 1 ? "scrap" : "scraps")"
          )
          Spacer()
          Text(model.busy ? "Working…" : model.notice).lineLimit(1)
        }.font(theme.typography.small).padding(10)
      }
    }
    .onGeometryChange(for: CGFloat.self) {
      $0.size.width
    } action: {
      width = $0
    }
    .task { await model.load() }
    .onChange(of: model.query) { _, _ in model.selection = model.visible.first?.id }
    .sheet(item: $model.draft) { scrap in
      ScrapEditor(model: model, scrap: scrap)
        .environment(\.miniTheme, theme).environment(\.colorScheme, theme.colorScheme)
        .miniSheet(width: 570)
    }
  }

  private func shelfDetail(_ scrap: Scrap) -> String {
    guard scrap.kind == .image else { return scrap.kind.title }
    if model.reading == scrap.id { return "Image · reading text…" }
    return scrap.recognizedText?.isEmpty == false
      ? "Image · text searchable" : "Image · caption searchable"
  }

  private func toolbar(short: Bool) -> some View {
    HStack(spacing: 8) {
      Button("New…", action: model.newNote)
      Button(short ? "Paste" : "Paste as New", action: model.pasteAsNew)
        .accessibilityLabel("Paste as New")
      Button("Import…", action: model.chooseFile)
      Spacer(minLength: 4)
      Button(
        model.showArchive ? (short ? "Shelf" : "Show Shelf") : (short ? "Archive" : "Show Archive")
      ) {
        model.showArchive.toggle()
        model.selection = model.visible.first?.id
      }
      .accessibilityLabel(model.showArchive ? "Show Shelf" : "Show Archive")
    }
  }

  private var shelf: some View {
    VStack(spacing: 0) {
      TextField("Search scraps", text: $model.query)
        .textFieldStyle(.plain).padding(8)
        .background(theme.paper)
        .overlay(Rectangle().strokeBorder(theme.ink, lineWidth: 1))
        .accessibilityLabel("Search scrapbook").padding(10)
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(model.visible) { scrap in
            Button {
              model.selection = scrap.id
            } label: {
              VStack(alignment: .leading, spacing: 5) {
                Text(scrap.title).font(theme.typography.title).lineLimit(2)
                Text(shelfDetail(scrap))
                  .font(theme.typography.small)
              }
              .padding(10).frame(maxWidth: .infinity, alignment: .leading)
              .foregroundStyle(model.selection == scrap.id ? theme.selectionInk : theme.ink)
              .background {
                if model.selection == scrap.id { ThemeSurfaceView(theme.selection) }
              }
              .contentShape(Rectangle())
            }.buttonStyle(.plain)
              .accessibilityLabel(scrap.title + ", " + scrap.kind.title)
              .accessibilityAddTraits(model.selection == scrap.id ? .isSelected : [])
          }
        }
      }
    }
  }

  private func detail(_ scrap: Scrap) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(scrap.title).font(narrow ? theme.typography.title : theme.typography.display(21))
        .lineLimit(2).textSelection(.enabled)
      HStack {
        Text(scrap.kind.title.uppercased())
        Spacer(minLength: 8)
        ViewThatFits(in: .horizontal) {
          Text(scrap.modified.formatted(date: .abbreviated, time: .shortened))
          Text(scrap.modified.formatted(date: .numeric, time: .omitted))
        }
      }.font(theme.typography.small)
      Rectangle().frame(height: 1)
      if scrap.kind == .image {
        ScrapImage(id: scrap.id, store: model.store).id(scrap.id)
        if let recognized = scrap.recognizedText, !recognized.isEmpty {
          DisclosureGroup("Text in picture") {
            ScrollView {
              Text(recognized).font(theme.typography.small)
                .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }
            .frame(maxHeight: 72)
          }
          .font(theme.typography.small)
          .accessibilityLabel("Text found in this picture")
        }
        if !scrap.text.isEmpty {
          ScrollView {
            Text(scrap.text).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
          }
          .frame(maxHeight: 72)
        }
      } else {
        ScrollView(scrap.kind == .command ? [.horizontal, .vertical] : .vertical) {
          Text(scrap.text.isEmpty ? "(An intentionally blank scrap.)" : scrap.text)
            .font(
              scrap.kind == .command
                ? .system(size: 13, design: .monospaced) : theme.typography.body
            )
            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .defaultScrollAnchor(.topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
      ViewThatFits(in: .horizontal) {
        actions(scrap, short: false)
        actions(scrap, short: true)
      }.buttonStyle(RetroButtonStyle()).disabled(!model.canChange)
    }.padding(narrow ? 10 : 16)
  }

  private func actions(_ scrap: Scrap, short: Bool) -> some View {
    HStack {
      Button("Edit…", action: model.edit)
      Button("Copy", action: model.copySelected)
      if scrap.kind == .link {
        Button(short ? "Open" : "Open Link", action: model.openLink).accessibilityLabel("Open Link")
      }
      Spacer(minLength: 0)
      Button(scrap.archived ? "Restore" : "Archive", action: model.archiveOrRestore)
    }
  }
}

private struct ScrapImage: View {
  let id: UUID
  let store: ScrapbookStore
  @State private var image: NSImage?
  @State private var error: String?
  var body: some View {
    Group {
      if let image {
        Image(nsImage: image).resizable().scaledToFit().accessibilityLabel("Saved scrapbook image")
      } else {
        Text(error ?? "Opening image…").font(.caption)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .task {
      do {
        let data = try await store.imageData(id)
        guard !Task.isCancelled else { return }
        guard let decoded = NSImage(data: data) else { throw ScrapbookError.invalidImage }
        image = decoded
      } catch { self.error = "The saved image is unavailable. Its caption is still here." }
    }
  }
}

private struct ScrapEditor: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  let model: ScrapbookModel
  @State var scrap: Scrap

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("A little something worth keeping.").font(theme.typography.display(21))
      TextField("Title", text: $scrap.title).accessibilityLabel("Scrap title")
        .textFieldStyle(.plain).padding(8)
        .overlay(Rectangle().strokeBorder(theme.ink, lineWidth: 1))
      if scrap.kind != .image {
        HStack {
          ForEach([ScrapKind.note, .command, .link], id: \.self) { kind in
            Button((scrap.kind == kind ? "✓ " : "") + kind.title) { scrap.kind = kind }
              .accessibilityLabel(kind.title + " scrap")
              .accessibilityAddTraits(scrap.kind == kind ? .isSelected : [])
          }
        }.buttonStyle(RetroButtonStyle())
      }
      Text(scrap.kind == .image ? "Caption" : scrap.kind == .link ? "Web address" : "Contents")
        .font(theme.typography.small)
      TextEditor(text: $scrap.text)
        .font(theme.typography.body).scrollContentBackground(.hidden).padding(6)
        .background(theme.paper).overlay(Rectangle().strokeBorder(theme.ink, lineWidth: 1))
        .accessibilityLabel("Scrap contents")
      if let error = model.error { Text(error).font(theme.typography.small) }
      HStack {
        Text(
          scrap.kind == .command ? "Kept as text. Ready to copy when needed." : "Saved on this Mac."
        )
        .font(theme.typography.small)
        Spacer()
        Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
        Button("Save") { model.saveDraft(scrap) }.keyboardShortcut(.defaultAction)
      }.buttonStyle(RetroButtonStyle())
    }
    .padding(22).frame(width: 570, height: 420)
    .foregroundStyle(theme.ink).background(theme.paper)
    .disabled(model.busy).interactiveDismissDisabled(model.busy)
  }
}
