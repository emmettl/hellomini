import AppKit
import UniformTypeIdentifiers

extension ScrapbookModel {
  func chooseFile() {
    guard canChange else { return }
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.plainText, .sourceCode, .json, .png, .jpeg, .tiff, .heic, .gif]
    panel.prompt = "Add to Scrapbook"
    panel.message =
      "Text up to 1 MB. Images up to 25 MB are kept as PNG snapshots, up to 4096 pixels on the longest edge."
    guard panel.runModal() == .OK, let url = panel.url else { return }
    run { try await self.add(self.store.importFile(url)) }
  }

  func pasteAsNew() {
    guard canChange else { return }
    if let urls = pasteboard.readObjects(
      forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
      let url = urls.first
    {
      run { try await self.add(self.store.importFile(url)) }
    } else if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
      run { try await self.add(self.store.importImage(data)) }
    } else if let text = pasteboard.string(forType: .string) {
      guard text.utf8.count <= ScrapbookStore.textLimit else {
        error = ScrapbookError.tooLarge.localizedDescription
        return
      }
      let title = String(
        text.split(whereSeparator: \.isNewline).first?.prefix(80) ?? "Pasted scrap")
      let scrap = Scrap(
        kind: Scrap.webURL(text) == nil ? .note : .link,
        title: title.trimmingCharacters(in: .whitespaces).isEmpty ? "Pasted scrap" : title,
        text: text)
      run { try await self.add(ScrapImport(scrap: scrap)) }
    } else {
      error = "Copy some text, a web address, or an image, then choose Paste as New."
    }
  }

  func add(_ item: ScrapImport) async throws {
    let next = scraps + [item.scrap]
    try await persist(next, image: item)
    scraps = next
    showArchive = false
    query = ""
    collection = nil
    favouritesOnly = false
    selection = item.scrap.id
    notice = "Added to the scrapbook. No extra glue required."
    if item.scrap.kind == .image { recognizePending() }
  }

  func persist(_ entries: [Scrap], image: ScrapImport? = nil) async throws {
    try await store.save(entries, image: image)
    recognitionSaveWarning = nil
  }
  func copySelected() {
    guard let selected else { return }
    run {
      if selected.kind == .image {
        let data = try await self.store.imageData(selected.id)
        self.pasteboard.clearContents()
        self.pasteboard.setData(data, forType: .png)
      } else {
        self.pasteboard.clearContents()
        self.pasteboard.setString(selected.text, forType: .string)
      }
      self.notice = "Copied."
    }
  }

  func exportSelected() {
    guard canChange, let selected else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = selected.kind == .image ? [.png] : [.plainText]
    panel.nameFieldStringValue = "Scrap." + (selected.kind == .image ? "png" : "txt")
    guard panel.runModal() == .OK, let url = panel.url else { return }
    run {
      try await self.store.exportScrap(selected, to: url)
      self.notice = "Exported this page. No scissors required."
    }
  }

  func exportArchive(all: Bool) {
    guard canChange else { return }
    let scraps = all ? self.scraps : visible
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue = all ? "HelloMini-Scrapbook-Backup.json" : "HelloMini-Scraps.json"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    run {
      try await self.store.writeArchive(scraps, to: url, includeEmptyCollections: all)
      self.notice = "Exported \(scraps.count) scraps, including their pictures."
    }
  }

  func chooseArchive() {
    guard canChange else { return }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    run {
      self.archivePreview = try await self.store.previewArchive(at: url, existing: self.scraps)
    }
  }

  func confirmArchiveImport(_ preview: ScrapbookImportPreview) {
    run {
      self.scraps = try await self.store.importArchive(preview, existing: self.scraps)
      self.collections = await self.store.collections
      self.collection = nil
      self.favouritesOnly = false
      self.recognitionSaveWarning = nil
      self.archivePreview = nil
      self.query = ""
      self.showArchive = false
      self.selection = self.visible.first?.id
      self.notice =
        "Imported \(preview.entries.count) scraps; skipped \(preview.skipped) duplicates."
      self.recognizePending()
    }
  }

}
