import AppKit
import MiniCore
import MiniUI
import SwiftUI

struct SlidingBoard {
  var tiles = Array(1...15) + [0]
  var moves = 0
  var solved: Bool { tiles == Array(1...15) + [0] }
  var legalMoves: [Int] {
    let empty = tiles.firstIndex(of: 0)!
    return tiles.indices.filter { abs($0 / 4 - empty / 4) + abs($0 % 4 - empty % 4) == 1 }
  }
  @discardableResult mutating func move(_ index: Int) -> Bool {
    guard legalMoves.contains(index) else { return false }
    tiles.swapAt(index, tiles.firstIndex(of: 0)!)
    moves += 1
    return true
  }
  @discardableResult mutating func moveGap(dx: Int, dy: Int) -> Bool {
    guard abs(dx) + abs(dy) == 1 else { return false }
    let empty = tiles.firstIndex(of: 0)!
    let x = empty % 4 + dx
    let y = empty / 4 + dy
    guard (0..<4).contains(x), (0..<4).contains(y) else { return false }
    return move(y * 4 + x)
  }
  mutating func shuffle(using generator: inout some RandomNumberGenerator) {
    tiles = Array(1...15) + [0]
    var previous: Int?
    for _ in 0..<200 {
      let choices = legalMoves.filter { $0 != previous }
      let empty = tiles.firstIndex(of: 0)!
      move(choices.randomElement(using: &generator)!)
      previous = empty
    }
    if solved { move(legalMoves[0]) }
    moves = 0
  }
}

@MainActor public final class PuzzleApplication: MiniApplication {
  public let id = "puzzle"
  public let name = "Puzzle"
  public let icon = MiniApplicationIcon.puzzle
  public let defaultSize = CGSize(width: 660, height: 480)
  public let minimumSize = CGSize(width: 500, height: 370)
  public static let effect = MiniPlayfulEffect(
    id: "puzzle.live", name: "Live puzzle tiles",
    description: "Refresh the sliding puzzle from Hello Mini's own desktop once a second.")
  private let picture: DesktopPicture
  private let playfulness: PlayfulnessSettings
  public init(picture: DesktopPicture, playfulness: PlayfulnessSettings) {
    self.picture = picture
    self.playfulness = playfulness
  }
  public func content() -> AnyView {
    AnyView(PuzzleView(picture: picture, playfulness: playfulness))
  }
}

private struct PuzzleView: View {
  @Environment(\.miniWindowVisible) private var visible
  @Environment(\.miniWindowActive) private var windowActive
  @Environment(\.miniTheme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let picture: DesktopPicture
  let playfulness: PlayfulnessSettings
  @State private var board: SlidingBoard = {
    var board = SlidingBoard()
    var generator = SystemRandomNumberGenerator()
    board.shuffle(using: &generator)
    return board
  }()
  @State private var frozen = false
  @State private var active = NSApp.isActive
  @FocusState private var boardFocused: Bool
  private var live: Bool {
    active && visible && !frozen && !reduceMotion && playfulness.allows(PuzzleApplication.effect.id)
  }
  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Button("Shuffle") {
          var generator = SystemRandomNumberGenerator()
          board.shuffle(using: &generator)
        }
        Button(frozen ? "Live tiles" : "Freeze tiles") { frozen.toggle() }
        Button("Refresh picture") { picture.refresh() }
        Spacer()
        Text("\(board.moves) \(board.moves == 1 ? "move" : "moves")").font(theme.typography.small)
      }.buttonStyle(RetroButtonStyle())
      GeometryReader { geometry in
        let width = geometry.size.width / 4
        let height = geometry.size.height / 4
        VStack(spacing: 0) {
          ForEach(0..<4) { row in
            HStack(spacing: 0) {
              ForEach(0..<4) { column in
                let index = row * 4 + column
                let tile = board.tiles[index]
                Button {
                  board.move(index)
                } label: {
                  ZStack(alignment: .bottomTrailing) {
                    Rectangle().fill(theme.paper)
                    if tile != 0 {
                      if let image = crop(tile) {
                        Image(decorative: image, scale: 1).resizable().interpolation(.none)
                      }
                      Text("\(tile)").font(theme.typography.title).padding(4).foregroundStyle(
                        theme.ink
                      ).background(theme.paper)
                    }
                  }.frame(width: width, height: height)
                    .overlay(Rectangle().strokeBorder(theme.ink, lineWidth: 1))
                }.buttonStyle(.plain).disabled(!board.legalMoves.contains(index))
                  .accessibilityLabel(tile == 0 ? "Empty space" : "Move tile \(tile)")
              }
            }
          }
        }
      }
      .focusable().focused($boardFocused)
      .onKeyPress(.leftArrow) { moveGap(dx: -1, dy: 0) }
      .onKeyPress(.rightArrow) { moveGap(dx: 1, dy: 0) }
      .onKeyPress(.upArrow) { moveGap(dx: 0, dy: -1) }
      .onKeyPress(.downArrow) { moveGap(dx: 0, dy: 1) }
      Text(
        board.solved
          ? "Order restored. Temporarily."
          : "Click a neighboring tile, or use arrow keys to move the gap."
      )
      .font(theme.typography.small)
    }.padding(14)
      .onAppear { boardFocused = windowActive }
      .onChange(of: windowActive) { _, active in boardFocused = active }
      .onReceive(
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
      ) { _ in active = true }
      .onReceive(
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
      ) { _ in active = false }
      .task(id: live) {
        if picture.image == nil { picture.refresh() }
        guard live else { return }
        while !Task.isCancelled {
          do { try await Task.sleep(for: .seconds(1)) } catch { return }
          picture.refresh()
        }
      }
  }
  private func moveGap(dx: Int, dy: Int) -> KeyPress.Result {
    guard windowActive else { return .ignored }
    board.moveGap(dx: dx, dy: dy)
    return .handled
  }
  private func crop(_ tile: Int) -> CGImage? {
    guard let image = picture.image else { return nil }
    let w = CGFloat(image.width) / 4
    let h = CGFloat(image.height) / 4
    return image.cropping(
      to: CGRect(
        x: CGFloat((tile - 1) % 4) * w, y: CGFloat((tile - 1) / 4) * h, width: w, height: h))
  }
}
