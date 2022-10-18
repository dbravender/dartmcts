import 'package:dartmcts/dartmcts.dart';
import 'package:dartmcts/tictactoe.dart';

void main() {
  int gamesPlayed = 0;
  int xWins = 0;
  int oWins = 0;
  int draws = 0;
  for (var _ = 0; _ < 100; _++) {
    TicTacToeGame gameState = TicTacToeGame.newGame() as TicTacToeGame;
    while (gameState.getMoves().length > 0) {
      int iterations = 10;
      if (gameState.currentPlayer == TicTacToePlayer.X) {
        iterations = 100;
      }
      MCTSResult<int?, TicTacToePlayer> result = MCTS(gameState: gameState)
          .getSimulationResult(iterations: iterations);
      //var boardBefore = gameState.board;

      result.root!.children.forEach((move, node) {
        //print("$move: ${node.visits}");
      });

      gameState = gameState.cloneAndApplyMove(result.move, result.root!);
      //print('before: $boardBefore after: ${gameState.board}');
    }
    //print(gameState.formatBoard());
    if (gameState.winner == TicTacToePlayer.X) {
      xWins++;
    }
    if (gameState.winner == TicTacToePlayer.O) {
      oWins++;
      print("O won:");
      print(gameState.formatBoard());
    }
    if (gameState.winner == null) {
      print(gameState.formatBoard());
      draws++;
    }
    gamesPlayed += 1;
  }
  print("games played: $gamesPlayed");
  print("X wins: $xWins");
  print("O wins: $oWins");
  print("Draws: $draws");
}
