import 'package:test/test.dart';

import 'package:dartmcts/fourinarow.dart';
import 'package:dartmcts/dartmcts.dart';

void main() {
  test('new board is properly generated', () {
    var board = emptyBoard();
    expect(board.length, equals(6));
    expect(board[0].length, equals(7));
  });

  test('checkTopRow returns all open plays', () {
    var board = emptyBoard();
    expect(checkTopRow(board), equals([0, 1, 2, 3, 4, 5, 6]));
    board[0][3] = Player.FIRST;
    expect(checkTopRow(board), equals([0, 1, 2, 4, 5, 6]));
  });

  test('findRowForColumn works as expected', () {
    var o = Player.FIRST;
    var x = Player.SECOND;
    var _;
    Board board = [
      [o, o, _, _, _, x, x],
      [x, o, _, _, _, o, o],
      [o, x, o, _, _, x, x],
      [x, o, x, _, _, o, o],
      [o, x, o, _, _, x, x],
      [x, o, x, _, x, o, o]
    ];
    expect(findRowForColumn(board, 2), equals(1));
    expect(() => findRowForColumn(board, 0), throwsException);
    expect(findRowForColumn(board, 3), equals(5));
    expect(findRowForColumn(board, 4), equals(4));
    expect(() => findRowForColumn(board, 5), throwsException);
  });

  test('cloneAndApplyMove works as expected', () {
    var o = Player.FIRST;
    var x = Player.SECOND;
    var _;
    Board board = [
      [_, _, _, _, _, _, _],
      [_, _, _, _, _, _, _],
      [_, _, _, _, _, _, _],
      [_, _, _, _, _, _, _],
      [_, _, _, _, _, _, _],
      [_, _, _, _, o, o, o]
    ];

    var game = ConnectFourGame(
        board: board, bitboards: getBitBoards(board), scores: {});
    var game2 = game.cloneAndApplyMove(6, null);
    expect(game2.winner, isNull);
    expect(
        game2.board,
        equals([
          [_, _, _, _, _, _, _],
          [_, _, _, _, _, _, _],
          [_, _, _, _, _, _, _],
          [_, _, _, _, _, _, _],
          [_, _, _, _, _, _, o],
          [_, _, _, _, o, o, o]
        ]));
    game = ConnectFourGame(
        board: board, bitboards: getBitBoards(board), scores: {});
    game = game.cloneAndApplyMove(3, null);
    expect(
        game.board,
        equals([
          [_, _, _, _, _, _, _],
          [_, _, _, _, _, _, _],
          [_, _, _, _, _, _, _],
          [_, _, _, _, _, _, _],
          [_, _, _, _, _, _, _],
          [_, _, _, o, o, o, o]
        ]));
    expect(game.winner, equals(o));
    board = [
      [_, _, _, _, _, _, _],
      [_, _, _, _, _, _, _],
      [_, _, _, _, _, _, _],
      [_, _, _, _, _, x, o],
      [_, _, _, _, x, o, x],
      [_, _, _, x, o, o, o]
    ];
    game = ConnectFourGame(
        board: board,
        bitboards: getBitBoards(board),
        currentPlayer: Player.SECOND,
        scores: {});
    game = game.cloneAndApplyMove(6, null);
    expect(game.winner, equals(Player.SECOND));
  });

  test('plays out a game from start to finish', () {
    int smartWins = 0;
    for (var _ = 0; _ < 100; _++) {
      ConnectFourGame game = ConnectFourGame.newGame();
      while (game.getMoves().length > 0) {
        MCTSResult<Move, Player> result;
        int iterations;
        if (game.currentPlayer == Player.FIRST) {
          iterations = 5;
        } else {
          iterations = 10;
        }
        result =
            MCTS(gameState: game).getSimulationResult(iterations: iterations);
        game = game.cloneAndApplyMove(result.move!, result.root!);
      }
      if (game.winner == Player.SECOND) {
        smartWins++;
      }
    }
    expect(smartWins, greaterThan(70));
  });
}
