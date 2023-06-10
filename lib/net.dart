/// Initialize and optionally set a value in a one-hot array
List<double> initOneHot(int length, {double filler = 0, int? value}) {
  var l = List<double>.filled(length, filler);
  if (value != null) {
    l[value] = 1;
  }
  return l;
}

/// A tuple for move and score
class MoveScore<Move> {
  Move move;
  double score;

  MoveScore(this.move, this.score);

  @override
  String toString() {
    return 'MoveScore(score: $score, move: $move)';
  }
}

/// A response for a move
class StepResponse {
  bool done = false;
  List<double> reward = [];

  StepResponse({required this.done, required this.reward});
}

abstract class TrainableInterface {
  int get actionSpaceSize {
    return legalActions().length;
  }

  int get observationSpaceSize {
    return observation().length - legalActions().length;
  }

  late int playerCount;
  late int currentPlayer;

  List<double> observation();
  List<double> legalActions();
  StepResponse step(int move);
}
