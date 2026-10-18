import Foundation

struct ScrapFiling: Equatable {
  var collection: String?
  var favourite: Bool
  var archived: Bool
  init(_ scrap: Scrap) {
    collection = scrap.collection
    favourite = scrap.isFavourite
    archived = scrap.archived
  }
  func apply(to scrap: inout Scrap) {
    scrap.collection = collection
    scrap.favourite = favourite
    scrap.archived = archived
  }
}
struct ScrapFilingUndo {
  var before: [UUID: ScrapFiling]
  var after: [UUID: ScrapFiling]
  var namesBefore: [String]
  var namesAfter: [String]
}
extension ScrapbookModel {
  var operationIDs: Set<UUID> {
    selecting
      ? batchSelection.intersection(Set(visible.map(\.id))) : Set(selected.map { [$0.id] } ?? [])
  }
  func toggleSelection(_ id: UUID) {
    if !batchSelection.insert(id).inserted { batchSelection.remove(id) }
    selection = id
  }
  func archiveOrRestore() { changeSelection { $0.archived.toggle() } }
  func favouriteSelection(_ value: Bool) { changeSelection { $0.favourite = value } }
  func fileSelection(in name: String?) {
    guard name == nil || collections.contains(name!) else { return }
    changeSelection { $0.collection = name }
  }
  func changeSelection(_ change: @escaping (inout Scrap) -> Void) {
    let ids = operationIDs
    guard !ids.isEmpty else { return }
    run {
      var next = self.scraps
      for index in next.indices where ids.contains(next[index].id) {
        change(&next[index])
        next[index].modified = .now
      }
      try await self.commitFiling(next, names: self.collections)
      self.batchSelection = ids.intersection(Set(self.visible.map(\.id)))
      self.selection = self.visible.first?.id
      self.notice = "Updated \(ids.count) scraps. Undo Filing can put them back."
    }
  }
  func organiseSelected(collection name: String?, favourite: Bool) {
    guard let selected else { return }
    run {
      guard name == nil || self.collections.contains(name!) else { return }
      var next = self.scraps
      guard let index = next.firstIndex(where: { $0.id == selected.id }) else { return }
      next[index].collection = name
      next[index].favourite = favourite
      try await self.commitFiling(next, names: self.collections)
      self.selection =
        self.visible.contains(where: { $0.id == selected.id })
        ? selected.id : self.visible.first?.id
    }
  }
  func createCollection(_ raw: String) {
    let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    run {
      let names = try ScrapbookStore.validatedCollections(self.collections + [name])
      try await self.commitFiling(self.scraps, names: names)
      self.collection = name
      self.selection = self.visible.first?.id
    }
  }
  func renameCollection(_ old: String, to raw: String) {
    let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    run {
      guard self.collections.contains(old), name != old else { return }
      guard !self.collections.contains(name) else {
        throw CocoaError(
          .validationMultipleErrors,
          userInfo: [
            NSLocalizedDescriptionKey: "That collection already exists. Choose another name."
          ])
      }
      let names = try ScrapbookStore.validatedCollections(
        self.collections.filter { $0 != old } + [name])
      var next = self.scraps
      for index in next.indices where next[index].collection == old {
        next[index].collection = name
      }
      try await self.commitFiling(next, names: names)
      if self.collection == old { self.collection = name }
    }
  }
  func removeCollection(_ name: String) {
    run {
      var next = self.scraps
      for index in next.indices where next[index].collection == name {
        next[index].collection = nil
      }
      try await self.commitFiling(next, names: self.collections.filter { $0 != name })
      self.collection = nil
      self.selection = self.visible.first?.id
    }
  }
  func commitFiling(_ next: [Scrap], names: [String]) async throws {
    let before = Dictionary(uniqueKeysWithValues: scraps.map { ($0.id, ScrapFiling($0)) })
    let after = Dictionary(uniqueKeysWithValues: next.map { ($0.id, ScrapFiling($0)) })
    let receipt = ScrapFilingUndo(
      before: before, after: after, namesBefore: collections, namesAfter: names)
    try await store.save(next, collections: names)
    scraps = next
    collections = names
    recognitionSaveWarning = nil
    filingUndo = receipt
    filingPulse += 1
  }
  func undoFiling() {
    guard let receipt = filingUndo else { return }
    run {
      guard self.collections == receipt.namesAfter,
        Dictionary(uniqueKeysWithValues: self.scraps.map { ($0.id, ScrapFiling($0)) })
          == receipt.after
      else {
        self.filingUndo = nil
        throw CocoaError(
          .fileWriteUnknown,
          userInfo: [
            NSLocalizedDescriptionKey:
              "The library's filing changed. Undo Filing was left unapplied."
          ])
      }
      var next = self.scraps
      for index in next.indices { receipt.before[next[index].id]?.apply(to: &next[index]) }
      try await self.store.save(next, collections: receipt.namesBefore)
      self.scraps = next
      self.collections = receipt.namesBefore
      if let name = self.collection, !self.collections.contains(name) { self.collection = nil }
      self.filingUndo = nil
      self.batchSelection = []
      self.selection = self.visible.first?.id
      self.notice = "Filing restored. All scraps kept."
    }
  }
}
