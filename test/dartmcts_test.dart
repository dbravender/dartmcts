import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:dartmcts/dartmcts.dart';

enum Player { FIRST, SECOND }

enum Move { WIN }

class GameWithOneMove implements GameState<Move, Player> {
  Player? currentPlayer;
  Player? winner;
  Map<Player, int> scores = {};

  GameWithOneMove(
      {this.winner, required this.scores, this.currentPlayer = Player.FIRST});

  @override
  GameWithOneMove cloneAndApplyMove(Move move) {
    var newScores = {
      Player.FIRST: 1,
      Player.SECOND: 0,
    };
    return GameWithOneMove(
        winner: currentPlayer, scores: newScores, currentPlayer: Player.SECOND);
  }

  @override
  List<Move> getMoves() {
    if (winner == null) {
      return [Move.WIN];
    }
    return [];
  }

  @override
  GameState<Move, Player> determine(GameState<Move, Player>? initialState) {
    return this;
  }
}

enum TicTacToePlayer { X, O }

final Set<int> winningTicTacToeScores = {7, 56, 448, 73, 146, 292, 273, 84};

class TicTacToeGame implements GameState<int?, TicTacToePlayer> {
  List<TicTacToePlayer?>? board = [];
  TicTacToePlayer? currentPlayer;
  TicTacToePlayer? winner;
  Map<TicTacToePlayer, int> scores = {
    TicTacToePlayer.O: 0,
    TicTacToePlayer.X: 0,
  };
  TicTacToeGame(
      {this.board, required this.scores, this.currentPlayer, this.winner});

  static GameState<int?, TicTacToePlayer> newGame() {
    return TicTacToeGame(
        board:
            List.from([null, null, null, null, null, null, null, null, null]),
        currentPlayer: TicTacToePlayer.O,
        scores: {
          TicTacToePlayer.O: 0,
          TicTacToePlayer.X: 0,
        });
  }

  @override
  GameState<int?, TicTacToePlayer>? determine(
      GameState<int?, TicTacToePlayer>? initialState) {
    return initialState;
  }

  @override
  List<int?> getMoves() {
    if (winner == null) {
      return board!
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
  TicTacToeGame cloneAndApplyMove(int? move) {
    if (move == null) {
      return this;
    }
    var newScores = new Map<TicTacToePlayer, int>.from(scores);
    if (board![move] != null) {
      throw InvalidMove();
    }
    TicTacToePlayer newCurrentPlayer = currentPlayer == TicTacToePlayer.O
        ? TicTacToePlayer.X
        : TicTacToePlayer.O;
    TicTacToePlayer? newWinner;
    List<TicTacToePlayer?> newBoard = List.from(board!);
    newBoard[move] = currentPlayer;
    Map<TicTacToePlayer, int> scoreByPlayer = {
      TicTacToePlayer.O: 0,
      TicTacToePlayer.X: 0
    };
    newBoard.asMap().forEach((index, player) {
      if (player != null) {
        int addScore = pow(2.0, index.toDouble()).toInt();
        scoreByPlayer.update(player, (score) => score + addScore,
            ifAbsent: () => addScore);
      }
    });

    for (var player in scoreByPlayer.keys) {
      if (winningTicTacToeScores.contains(scoreByPlayer[player])) {
        newWinner = player;
        newScores[player] = 1;
      }
    }
    return TicTacToeGame(
        board: newBoard,
        winner: newWinner,
        scores: newScores,
        currentPlayer: newCurrentPlayer);
  }
}

enum ScoringMove { SCORE_5, SCORE_10, SCORE_100 }

class GameWithScore implements GameState<ScoringMove, Player?> {
  Player? currentPlayer = Player.FIRST;
  Map<Player?, int> scores = {Player.FIRST: 0, Player.SECOND: 0};
  Player? winner;
  int round = 0;

  GameWithScore(
      {this.winner,
      required this.scores,
      this.round = 0,
      this.currentPlayer = Player.FIRST});

  @override
  GameWithScore cloneAndApplyMove(ScoringMove move) {
    var newPlayer, newScores, newWinner;
    newScores = new Map<Player, int>.from(scores);

    // process move
    switch (move) {
      case ScoringMove.SCORE_5:
        newScores.update(currentPlayer, (int score) => score + 5,
            ifAbsent: () => 5);
        break;
      case ScoringMove.SCORE_10:
        newScores.update(currentPlayer, (int score) => score + 10,
            ifAbsent: () => 10);
        break;
      case ScoringMove.SCORE_100:
        newScores.update(currentPlayer, (int score) => score + 100,
            ifAbsent: () => 100);
        break;
    }

    // change current player for the next play
    if (currentPlayer == Player.FIRST) {
      newPlayer = Player.SECOND;
    } else {
      newPlayer = Player.FIRST;
    }

    // check win conditions
    if (newScores[Player.FIRST] > 100 &&
        newScores[Player.FIRST] > newScores[Player.SECOND]) {
      newWinner = Player.FIRST;
    } else if (newScores[Player.SECOND] > 100) {
      newWinner = Player.SECOND;
    }

    return GameWithScore(
        winner: newWinner,
        round: round + 1,
        scores: newScores,
        currentPlayer: newPlayer);
  }

  @override
  List<ScoringMove> getMoves() {
    if (winner != null) {
      return [];
    }
    return [ScoringMove.SCORE_5, ScoringMove.SCORE_10, ScoringMove.SCORE_100];
  }

  @override
  GameState<ScoringMove, Player?> determine(
      GameState<ScoringMove, Player?>? initialState) {
    return this;
  }
}

void main() {
  test('game with one move works', () {
    var game = GameWithOneMove(scores: {});
    expect(game.getMoves(), equals([Move.WIN]));
    var result = MCTS(gameState: GameWithOneMove(scores: {}))
        .getSimulationResult(iterations: 10);
    expect(result.move, equals(Move.WIN));
    expect(
        result.root!.children.values.first.getWinner(), equals(Player.FIRST));
  });
  test('selects winning tic tac toe move (scenario 1)', () {
    var o = TicTacToePlayer.O;
    var x = TicTacToePlayer.X;
    var e;
    var oneMoveFromWinning = TicTacToeGame(
        board: [o, o, e, x, e, x, e, x, e], currentPlayer: o, scores: {});
    MCTSResult<int?, TicTacToePlayer> result =
        MCTS(gameState: oneMoveFromWinning)
            .getSimulationResult(iterations: 100);
    expect(result.root!.children.length, equals(4));
    expect(result.move, equals(2));
    expect(result.maxDepth, equals(4));
  });
  test('selects winning tic tac toe move (scenario 2)', () {
    var o = TicTacToePlayer.O;
    var x = TicTacToePlayer.X;
    var e;
    var oneMoveFromWinning = TicTacToeGame(
        board: [o, e, e, o, x, x, e, x, e], currentPlayer: o, scores: {});
    MCTSResult<int?, TicTacToePlayer> result =
        MCTS(gameState: oneMoveFromWinning)
            .getSimulationResult(iterations: 100);
    expect(result.root!.children.length, equals(4));
    expect(result.maxDepth, equals(4));
    expect(result.move, equals(6));
  });
  test('plays out a game from start to finish', () {
    for (var _ = 0; _ < 100; _++) {
      TicTacToeGame gameState = TicTacToeGame.newGame() as TicTacToeGame;
      while (gameState.getMoves().length > 0) {
        MCTSResult<int?, TicTacToePlayer> result =
            MCTS(gameState: gameState).getSimulationResult(iterations: 100);
        gameState = gameState.cloneAndApplyMove(result.move);
      }
    }
  });
  test(
      'game with a score selects high scoring moves more frequently than low scoring moves',
      () {
    var gameState = GameWithScore(scores: {Player.FIRST: 0, Player.SECOND: 0});
    MCTSResult<ScoringMove, Player?> result =
        MCTS(gameState: gameState).getSimulationResult(iterations: 100);
    expect(result.root!.children.length, equals(3));
    expect(result.move, equals(ScoringMove.SCORE_100));
    expect(result.root!.children[ScoringMove.SCORE_100]?.visits ?? 0,
        greaterThan(50));
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
