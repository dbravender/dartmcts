import 'package:flutter_test/flutter_test.dart';

import 'package:dartmcts/dartmcts.dart';
import 'package:dartmcts/tictactoe.dart';

enum Player { FIRST, SECOND }

enum Move { WIN }

class GameWithOneMove implements GameState<Move, Player> {
  Player? currentPlayer;
  Player? winner;
  Map<Player, int> scores = {};

  GameWithOneMove(
      {this.winner, required this.scores, this.currentPlayer = Player.FIRST});

  @override
  GameWithOneMove cloneAndApplyMove(Move move, Node<Move, Player>? root) {
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
  GameWithScore cloneAndApplyMove(
      ScoringMove move, Node<ScoringMove, Player?>? root) {
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

class testNNPV implements NeuralNetworkPolicyAndValue<int?, TicTacToePlayer> {
  @override
  double getCurrentValue(GameState<int?, TicTacToePlayer> game) {
    // TODO: implement getCurrentValue
    throw UnimplementedError();
  }

  @override
  Map<int?, double> getMoveProbabilities(
      GameState<int?, TicTacToePlayer?> game) {
    // pretend that the neural net thinks corner moves are good first moves
    if (game.getMoves().length == 9) {
      return <int?, double>{
        0: 0.25,
        1: 0,
        2: 0.25,
        3: 0,
        4: 0,
        5: 0,
        6: 0.25,
        7: 0,
        8: 0.25,
      };
    }
    return {};
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
        gameState = gameState.cloneAndApplyMove(result.move, result.root!);
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
        greaterThan(result.root!.children[ScoringMove.SCORE_5]?.visits ?? 0));
    expect(result.root!.children[ScoringMove.SCORE_100]?.visits ?? 0,
        greaterThan(result.root!.children[ScoringMove.SCORE_10]?.visits ?? 0));
  });
  test('visits neural net prescribed nodes more frequently', () {
    var o = TicTacToePlayer.O;
    var x = TicTacToePlayer.X;
    var e;
    var ttgg = TicTacToeGame(
        board: [e, e, e, e, e, e, e, e, e], currentPlayer: o, scores: {});
    MCTSResult<int?, TicTacToePlayer> result = MCTS(gameState: ttgg)
        .getSimulationResult(iterations: 100, nnpv: testNNPV());
    expect(result.root!.children.length, equals(9));
    expect(result.maxDepth, equals(9));
    Map<int?, int> visits = {};
    result.root!.children.forEach((key, value) {
      visits[value.move] = value.visits;
    });
    print(visits);
    ttgg = TicTacToeGame(
        board: [e, e, e, e, e, e, e, e, e], currentPlayer: o, scores: {});
    result = MCTS(gameState: ttgg).getSimulationResult(iterations: 100);
    result.root!.children.forEach((key, value) {
      visits[value.move] = value.visits;
    });
    print(visits);
  });
}
