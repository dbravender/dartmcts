import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:dartmcts/dartmcts.dart';

enum Player { FIRST, SECOND }

enum Move { WIN }

class GameWithOneMove implements GameState<Move, Player> {
  Player currentPlayer;
  Player winner;

  GameWithOneMove({this.winner, this.currentPlayer = Player.FIRST});

  @override
  GameWithOneMove cloneAndApplyMove(Move move) {
    if (move == null) {
      return this;
    }
    return GameWithOneMove(winner: currentPlayer, currentPlayer: Player.SECOND);
  }

  @override
  List<Move> getMoves() {
    if (winner == null) {
      return [Move.WIN];
    }
    return [];
  }

  @override
  GameState<Move, Player> determine(GameState<Move, Player> initialState) {
    return this;
  }
}

enum TicTacToePlayer { X, O }

final Set<int> winningTicTacToeScores = {7, 56, 448, 73, 146, 292, 273, 84};

class TicTacToeGame implements GameState<int, TicTacToePlayer> {
  List<TicTacToePlayer> board = [];
  TicTacToePlayer currentPlayer;
  TicTacToePlayer winner;
  TicTacToeGame({this.board, this.currentPlayer, this.winner});

  @override
  GameState<int, TicTacToePlayer> determine(
      GameState<int, TicTacToePlayer> initialState) {
    return this;
  }

  @override
  List<int> getMoves() {
    if (winner == null) {
      return board
          .asMap()
          .map((index, player) =>
              player == null ? MapEntry(index, null) : MapEntry(null, null))
          .keys
          .where((index) => index != null)
          .toList();
    }
    return [];
  }

  @override
  TicTacToeGame cloneAndApplyMove(int move) {
    if (move == null) {
      return this;
    }
    if (board[move] != null) {
      throw InvalidMove();
    }
    TicTacToePlayer newCurrentPlayer = currentPlayer == TicTacToePlayer.O
        ? TicTacToePlayer.X
        : TicTacToePlayer.O;
    TicTacToePlayer newWinner;
    List<TicTacToePlayer> newBoard = List.from(board);
    newBoard[move] = currentPlayer;
    Map<TicTacToePlayer, int> scoreByPlayer = {
      TicTacToePlayer.O: 0,
      TicTacToePlayer.X: 0
    };
    board.asMap().forEach((index, player) => {
          if (player != null)
            {scoreByPlayer[player] += pow(2.0, index.toDouble()).toInt()}
        });

    for (var player in scoreByPlayer.keys) {
      if (winningTicTacToeScores.contains(scoreByPlayer[player])) {
        newWinner = player;
      }
    }
    return TicTacToeGame(
        board: newBoard, winner: newWinner, currentPlayer: newCurrentPlayer);
  }
}

void main() {
  test('game with one move works', () {
    var game = GameWithOneMove();
    expect(game.getMoves(), equals([Move.WIN]));
    var result =
        MCTS(gameState: GameWithOneMove()).getSimulationResult(iterations: 10);
    expect(result.move, equals(Move.WIN));
    expect(result.root.children.values.first.getWinner(), equals(Player.FIRST));
  });
  test('selects winning tic tac toe move (scenario 1)', () {
    var o = TicTacToePlayer.O;
    var x = TicTacToePlayer.X;
    var e;
    var oneMoveFromWinning =
        TicTacToeGame(board: [o, o, e, x, e, x, e, x, e], currentPlayer: o);
    var result = MCTS(gameState: oneMoveFromWinning)
        .getSimulationResult(iterations: 100);
    expect(result.root.children.length, equals(4));
    expect(result.move, equals(2));
    expect(result.maxDepth, equals(4));
  });
  test('selects winning tic tac toe move (scenario 2)', () {
    var o = TicTacToePlayer.O;
    var x = TicTacToePlayer.X;
    var e;
    var oneMoveFromWinning =
        TicTacToeGame(board: [o, e, e, o, x, x, e, x, e], currentPlayer: o);
    var result = MCTS(gameState: oneMoveFromWinning)
        .getSimulationResult(iterations: 100);
    expect(result.root.children.length, equals(4));
    expect(result.maxDepth, equals(4));
    expect(result.move, equals(6));
  });
}

/*  @Test

    @Test
    fun testWinningBoard() {
        val e = null
        val r = FourInARowPlayer.RED
        val b = FourInARowPlayer.BLUE
        val board: FourInARowBoard = arrayOf(
                arrayOfNulls(7),
                arrayOfNulls(7),
                arrayOfNulls(7),
                arrayOfNulls(7),
                arrayOf(e, e, r, r, r, e, e),
                arrayOf(e, b, b, b, b, e, e))
        assertEquals(BigInteger("270549120"),
            getBitBoard(
                FourInARowPlayer.BLUE,
                board
            )
        )
        assertEquals(true,
            winningBoard(
                FourInARowPlayer.BLUE,
                board
            )
        )
    }

    @Test
    fun testOnlyDeterminedMovesAreFollowed() {
        result = (MCTS(GameWithManyMovesOnlyOneDetermined)
            .get_simulation_result(100))
        self.assertEqual(result.root.children[0].move, 1)
        self.assertEqual(result.root.children[0].visits, 100)
    }

    @Test
    fun testFourInARowWithMCTS() {
        val e = null
        val r = FourInARowPlayer.RED
        val b = FourInARowPlayer.BLUE
        val oneMoveFromWinning = FourInARowGame(
            board = arrayOf(
                arrayOfNulls(7),
                arrayOfNulls(7),
                arrayOfNulls(7),
                arrayOfNulls(7),
                arrayOf(e, e, r, r, r, e, e),
                arrayOf(e, e, b, b, b, e, e)
            ),
            currentPlayer = FourInARowPlayer.BLUE
        )
        val result = MCTS(oneMoveFromWinning).getSimulationResult(maxSeconds = 10)
        assertTrue(result.move in listOf(1, 5))
        val board = arrayOf(
                arrayOfNulls(7),
                arrayOfNulls(7),
                arrayOfNulls(7),
                arrayOfNulls(7),
                arrayOf(e, e, r, r, r, e, e),
                arrayOf(e, e, b, b, b, b, e))
        assertEquals(BigInteger("34630287360"),
            getBitBoard(b, board)
        )
        assertTrue(
            checkWin(
                getBitBoard(
                    b,
                    board
                )
            )
        )
    }
}
*/
