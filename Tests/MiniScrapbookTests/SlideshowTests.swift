import Foundation
import Testing

@testable import MiniScrapbook

@Test func slideshowShowsShelfPicturesNewestFirst() {
  let older = Scrap(
    kind: .image, title: "Older", text: "", created: .distantPast,
    modified: Date(timeIntervalSince1970: 100))
  let newer = Scrap(
    kind: .image, title: "Newer", text: "", created: .distantPast,
    modified: Date(timeIntervalSince1970: 200))
  var archived = Scrap(kind: .image, title: "Archived", text: "")
  archived.archived = true
  let note = Scrap(kind: .note, title: "Words", text: "Not a picture")
  let slides = ScrapbookSlideshow.slides(from: [older, note, archived, newer])
  #expect(slides.map(\.title) == ["Newer", "Older"])
  #expect(ScrapbookSlideshow.slides(from: [note]).isEmpty)
}
