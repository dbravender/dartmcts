import 'dart:math';

import 'dartmcts.dart';

enum TicTacToePlayer { X, O }

final Set<int> winningTicTacToeScores = {7, 56, 448, 73, 146, 292, 273, 84};

class TicTacToeGame implements GameState<int, TicTacToePlayer> {
  List<TicTacToePlayer> board;
  TicTacToePlayer currentPlayer;
  TicTacToePlayer winner;
  TicTacToeGame({this.board, this.currentPlayer, this.winner});

  String toString() {
    return this.board.toString();
  }

  static GameState<int, TicTacToePlayer> newGame() {
    return TicTacToeGame(
        board: List.from([null, null, null, null, null, null, null, null, null]),
        currentPlayer: TicTacToePlayer.O);
  }

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
    if (getMoves().length == 0 && newWinner == null) {
      throw Exception('boom time');
    }
    return TicTacToeGame(
        board: newBoard, winner: newWinner, currentPlayer: newCurrentPlayer);
  }
}

void main() {
  int gamesPlayed = 0;
  for (var _ = 0; _ < 100; _++) {
    TicTacToeGame gameState = TicTacToeGame.newGame();
    while (gameState.getMoves().length > 0) {
      var result =
          MCTS(gameState: gameState).getSimulationResult(iterations: 100);
      var boardBefore = gameState.board;
      gameState = gameState.cloneAndApplyMove(result.move);
      //print('before: $boardBefore after: ${gameState.board}');
    }
    gamesPlayed += 1;
  }
  print(gamesPlayed);
}
