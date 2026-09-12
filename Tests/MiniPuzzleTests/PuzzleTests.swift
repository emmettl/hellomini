import Testing

@testable import MiniPuzzle

@Test func keyboardMovesTheGapWithoutWrappingRows() {
  var board = SlidingBoard()
  let rejected = board.moveGap(dx: 1, dy: 0)
  #expect(!rejected && board.moves == 0)
  let left = board.moveGap(dx: -1, dy: 0)
  #expect(left && board.tiles[14] == 0 && board.moves == 1)
  let up = board.moveGap(dx: 0, dy: -1)
  #expect(up && board.tiles[10] == 0)
  let diagonal = board.moveGap(dx: 1, dy: 1)
  #expect(!diagonal && board.moves == 2)
}

@Test func shufflesRemainSolvableAndOnlyAdjacentMovesWork() {
  var generator = SystemRandomNumberGenerator()
  for _ in 0..<40 {
    var board = SlidingBoard()
    board.shuffle(using: &generator)
    #expect(Set(board.tiles) == Set(0...15) && !board.solved && board.moves == 0)
    let values = board.tiles.filter { $0 != 0 }
    let inversions = values.enumerated().reduce(0) { total, pair in
      total + values.dropFirst(pair.offset + 1).filter { $0 < pair.element }.count
    }
    let rowFromBottom = 4 - board.tiles.firstIndex(of: 0)! / 4
    #expect((inversions + rowFromBottom) % 2 == 1)
    let illegal = board.tiles.indices.first { !board.legalMoves.contains($0) }!
    let rejected = board.move(illegal)
    #expect(!rejected)
    let accepted = board.move(board.legalMoves[0])
    #expect(accepted && board.moves == 1)
  }
}
