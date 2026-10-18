import Foundation

extension ScrapbookModel {
  func resumeRecognition() {
    recognitionPaused = false
    recognizePending()
  }
  func stopRecognition() {
    recognitionPaused = true
    recognitionGeneration = UUID()
    recognitionTask?.cancel()
    recognitionTask = nil
    reading = nil
  }
  /// Completed results wait in memory until the current edit finishes; no polling or busy waiting.
  func recognizePending() {
    guard ready, !busy, !recognitionPaused, recognitionTask == nil,
      scraps.contains(where: { $0.awaitingRecognition })
    else { return }
    let generation = UUID()
    recognitionGeneration = generation
    recognitionTask = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled, self.recognitionGeneration == generation, !self.busy,
        let scrap = self.scraps.first(where: { $0.awaitingRecognition })
      {
        self.reading = scrap.id
        let text: String
        if let pending = self.recognizedPending.removeValue(forKey: scrap.id) {
          text = pending
        } else {
          do {
            let data = try await self.store.imageData(scrap.id)
            text = String(
              try await self.recognizer(data).trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(ScrapbookStore.recognitionLimit))
          } catch {
            guard !Task.isCancelled, self.recognitionGeneration == generation else { return }
            text = ""
          }
        }
        guard !Task.isCancelled, self.recognitionGeneration == generation else { return }
        self.reading = nil
        if self.busy {
          self.recognizedPending[scrap.id] = text
          break
        }
        guard
          let index = self.scraps.firstIndex(where: { $0.id == scrap.id && $0.awaitingRecognition })
        else { continue }
        var next = self.scraps
        next[index].recognizedText = text
        self.busy = true
        do { try await self.persist(next) } catch {
          self.recognitionSaveWarning =
            "Picture text is searchable in this session but could not be saved. The next successful library edit will save it."
        }
        self.scraps = next
        self.busy = false
      }
      guard self.recognitionGeneration == generation else { return }
      self.reading = nil
      self.recognitionTask = nil
      // An edit may have finished while the recognizer was returning.
      self.recognizePending()
    }
  }

}
