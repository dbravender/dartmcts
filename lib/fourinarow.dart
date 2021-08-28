import 'package:dartmcts/dartmcts.dart';

const List<List<int>> bitboardLookup = [
  [5, 12, 19, 26, 33, 40, 47],
  [4, 11, 18, 25, 32, 39, 46],
  [3, 10, 17, 24, 31, 38, 45],
  [2, 9, 16, 23, 30, 37, 44],
  [1, 8, 15, 22, 29, 36, 43],
  [0, 7, 14, 21, 28, 35, 42],
];

typedef Move = int;
typedef Board = List<List<Player?>>;

enum Player {
  FIRST,
  SECOND,
}

Board emptyBoard() {
  return [
    for (var i = 0; i < 6; i++) [for (var _ = 0; _ < 7; _++) null]
  ];
}

bool checkWin(int bitboard) {
  var height = 6;
  var h1 = height + 1;
  var h2 = height + 2;
  var diag1 = bitboard & (bitboard >> height);
  var hori = bitboard & (bitboard >> h1);
  var diag2 = bitboard & (bitboard >> h2);
  var vert = bitboard & (bitboard >> 1);
  return ((diag1 & (diag1 >> 2 * height)) |
          (hori & (hori >> 2 * h1)) |
          (diag2 & (diag2 >> 2 * h2)) |
          (vert & (vert >> 2))) >
      0;
}

List<int> checkTopRow(Board board) {
  return [
    for (var c = 0; c < 7; c++)
      if (board[0][c] == null) c
  ];
}

Map<Player, int> getBitBoards(Board board) {
  Map<Player, int> bitboards = {Player.FIRST: 0, Player.SECOND: 0};
  for (var player in bitboards.keys) {
    for (var row = 5; row >= 0; row--) {
      for (var col = 0; col < 7; col++) {
        if (board[row][col] == player) {
          bitboards[player] =
              bitboards[player]! ^ (1 << bitboardLookup[row][col]);
        }
      }
    }
  }
  return bitboards;
}

int findRowForColumn(Board board, int column) {
  for (var row = 5; row >= 0; row--) {
    if (board[row][column] == null) {
      return row;
    }
  }
  throw Exception('No empty spot in that column');
}

class ConnectFourGame implements GameState<Move, Player> {
  Player? currentPlayer;
  Map<Player, int> bitboards;
  Board board;
  Player? winner;
  Map<Player, int> scores;

  ConnectFourGame(
      {this.winner,
      required this.board,
      required this.bitboards,
      required this.scores,
      this.currentPlayer = Player.FIRST});

  static ConnectFourGame newGame() {
    return ConnectFourGame(
        board: emptyBoard(),
        bitboards: {Player.FIRST: 0, Player.SECOND: 0},
        scores: {Player.FIRST: 0, Player.SECOND: 0});
  }

  @override
  ConnectFourGame cloneAndApplyMove(Move column) {
    var newBitboards = Map<Player, int>.from(bitboards);
    Board newBoard =
        Board.from([for (var row in board) List<Player?>.from(row)]);
    Player? newWinner;
    Player newPlayer;
    Map<Player, int> newScores = {
      Player.FIRST: 0,
      Player.SECOND: 0,
    };
    int row = findRowForColumn(board, column);
    newBoard[row][column] = currentPlayer;
    newBitboards[currentPlayer!] =
        newBitboards[currentPlayer]! ^ 1 << bitboardLookup[row][column];

    newBitboards.forEach((player, bitboard) {
      if (checkWin(bitboard)) {
        newWinner = player;
        newScores[player] = 1;
      }
    });

    if (currentPlayer == Player.FIRST) {
      newPlayer = Player.SECOND;
    } else {
      newPlayer = Player.FIRST;
    }

    return ConnectFourGame(
        board: newBoard,
        bitboards: newBitboards,
        winner: newWinner,
        scores: newScores,
        currentPlayer: newPlayer);
  }

  @override
  List<Move> getMoves() {
    if (winner != null) {
      return [];
    }
    return checkTopRow(board);
  }

  @override
  GameState<Move, Player> determine(GameState<Move, Player>? initialState) {
    return this;
  }
}
