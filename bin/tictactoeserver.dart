import 'package:dartmcts/trainingserver.dart';
import 'package:dartmcts/tictactoe.dart';

void main() {
  serve(() => TicTacToeNNInterface());
}
