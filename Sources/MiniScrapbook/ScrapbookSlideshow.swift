import AppKit
import MiniUI
import SwiftUI

/// Scrapbook pictures, one at a time, like a very patient projector.
struct ScrapbookSlideshow: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let model: ScrapbookModel
  @State private var index = 0
  static let interval: Duration = .seconds(7)

  /// Newest shelf pictures first; archived scraps stay private to the archive.
  nonisolated static func slides(from scraps: [Scrap]) -> [Scrap] {
    scraps.filter { $0.kind == .image && !$0.archived }
      .sorted {
        $0.modified == $1.modified ? $0.id.uuidString < $1.id.uuidString : $0.modified > $1.modified
      }
  }

  var body: some View {
    let slides = Self.slides(from: model.scraps)
    ZStack {
      theme.paper
      if slides.isEmpty {
        VStack(spacing: 14) {
          PixelIcon(symbol: .scrapbook, scale: 5)
          Text(model.ready ? "Nothing to show yet." : "Opening the scrapbook…")
            .font(theme.typography.display(24))
          Text("Add a picture to Scrapbook and it will appear here.")
            .font(theme.typography.body)
        }
      } else {
        let position = index % slides.count
        SlideView(
          slide: slides[position], store: model.store, position: position, count: slides.count
        )
        .id(slides[position].id)
        .transition(reduceMotion ? .identity : .opacity)
      }
    }
    .foregroundStyle(theme.ink)
    .task { if !model.ready { await model.load() } }
    .task(id: slides.map(\.id)) {
      guard slides.count > 1 else { return }
      while !Task.isCancelled {
        do { try await Task.sleep(for: Self.interval) } catch { return }
        // Reduce Motion still advances, without the cross-fade.
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.8)) { index += 1 }
      }
    }
  }
}

private struct SlideView: View {
  @Environment(\.miniTheme) private var theme
  let slide: Scrap
  let store: ScrapbookStore
  let position: Int
  let count: Int
  @State private var image: NSImage?
  @State private var unavailable = false

  var body: some View {
    VStack(spacing: 18) {
      Group {
        if let image {
          Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
            .accessibilityLabel(slide.title)
        } else {
          Text(unavailable ? "This picture is unavailable." : "").font(theme.typography.body)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(14)
      .background(theme.paper)
      .overlay(Rectangle().strokeBorder(theme.ink, lineWidth: 2))
      .background(Rectangle().fill(theme.ink).offset(x: 6, y: 6))
      VStack(spacing: 4) {
        Text(slide.title).font(theme.typography.display(22)).lineLimit(1)
        Text(
          slide.modified.formatted(date: .long, time: .omitted) + " · \(position + 1) of \(count)"
        )
        .font(theme.typography.small)
      }
    }
    .padding(48)
    .task {
      do {
        let data = try await store.imageData(slide.id)
        guard !Task.isCancelled else { return }
        image = NSImage(data: data)
        unavailable = image == nil
      } catch { unavailable = true }
    }
  }
}
