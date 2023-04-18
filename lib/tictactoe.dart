import 'package:dartmcts/dartmcts.dart';

enum TicTacToePlayer { X, O }

final List<List<int>> checks = [
  [0, 3, 6],
  [1, 4, 7],
  [2, 5, 8],
  [0, 1, 2],
  [3, 4, 5],
  [6, 7, 8],
  [0, 4, 8],
  [6, 4, 2]
];

class TicTacToeGame implements GameState<int?, TicTacToePlayer> {
  List<TicTacToePlayer?> board = [];
  TicTacToePlayer? currentPlayer;
  TicTacToePlayer? winner;
  Map<TicTacToePlayer, int> scores = {
    TicTacToePlayer.O: 0,
    TicTacToePlayer.X: 0,
  };
  TicTacToeGame(
      {required this.board,
      required this.scores,
      this.currentPlayer,
      this.winner});

  static GameState<int?, TicTacToePlayer> newGame() {
    return TicTacToeGame(
        board:
            List.from([null, null, null, null, null, null, null, null, null]),
        currentPlayer: TicTacToePlayer.X,
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
  TicTacToeGame cloneAndApplyMove(
      int? move, Node<int?, TicTacToePlayer>? root) {
    if (move == null) {
      return this;
    }
    var newScores = new Map<TicTacToePlayer, int>.from(scores);
    if (board[move] != null) {
      throw InvalidMove();
    }
    TicTacToePlayer newCurrentPlayer = currentPlayer == TicTacToePlayer.O
        ? TicTacToePlayer.X
        : TicTacToePlayer.O;
    TicTacToePlayer? newWinner;
    List<TicTacToePlayer?> newBoard = List.from(board);
    newBoard[move] = currentPlayer;
    for (var check in checks) {
      if (newBoard[check[0]] != null &&
          newBoard[check[0]] == newBoard[check[1]] &&
          newBoard[check[1]] == newBoard[check[2]]) {
        newWinner = newBoard[check[0]];
        newScores[newBoard[check[0]]!] = 10;
      }
    }
    if (getMoves().length == 0 && newWinner == null) {
      newScores[TicTacToePlayer.X] = 5;
      newScores[TicTacToePlayer.O] = 5;
    }
    return TicTacToeGame(
        board: newBoard,
        winner: newWinner,
        scores: newScores,
        currentPlayer: newCurrentPlayer);
  }

  String formatBoard() {
    String formattedBoard = "";
    int count = 0;
    for (var cell in board) {
      if (count % 3 == 0) {
        formattedBoard += "\n";
      }
      switch (cell) {
        case TicTacToePlayer.O:
          formattedBoard += "O";
          break;
        case TicTacToePlayer.X:
          formattedBoard += "X";
          break;
        default:
          formattedBoard += " ";
      }
      count++;
    }
    return formattedBoard;
  }

  @override
  Map<String, dynamic> toJson() {
    // TODO: implement toJson
    throw UnimplementedError();
  }
}
