import 'dart:math';

import 'package:dartmcts/dartmcts.dart';
import 'dart:developer' as d;

class SA {
  final int s;
  final int a;

  SA(this.s, this.a);

  @override
  int get hashCode => Object.hash(s, a);

  @override
  operator ==(Object other) {
    if (other is SA) {
      return s == other.s && a == other.a;
    }
    return false;
  }
}

// To keep things simple this MCTS implementation will assume that players and
// moves are represented by integers

class MCTSNNTree {
  Map<int, GameState<int, int>> parent = {};
  Map<SA, GameState<int, int>> GamesSa = {};
  Random? random;
  int simulationCount;
  double cpuct;
  GameState<int, int> game;
  double tieTolerance;
  double EPS;
  NeuralNetworkPolicyAndValue<int, int> nnpv;
  Map<SA, double> Qsa = {}; // stores Q values for s,a (as defined in the paper)
  Map<SA, int> Nsa = {}; // stores #times edge s,a was visited
  Map<int, int> Ns = {}; // stores #times board s was visited
  Map<int, List<double>> Ps =
      {}; // stores initial policy (returned by neural net)

  Map<int, double> Es = {}; // stores game.getGameEnded ended for board s
  Map<int, Set<int>> Vs = {}; // stores game.getValidMoves for board s

  MCTSNNTree({
    required this.game,
    required this.nnpv,
    this.simulationCount = 100,
    this.random,
    this.cpuct = 1.0,
    this.tieTolerance = 1e-5,
    this.EPS = 1e-8,
  });

  int getBestMove(GameState<int, int> game) {
    /// Runs all playouts sequentially and returns the most visited action.
    /// Returns:
    ///    bestAction: the action with the highest visit count

    var probabilities = getActionProb(game, temp: 0);

    double maxScore = probabilities.reduce(max);
    List<int> bestAs = probabilities
        .asMap()
        .entries
        .map((entry) {
          if (entry.value >= maxScore - tieTolerance)
            return entry.key;
          else
            return null;
        })
        .whereType<int>()
        .toList();
    return bestAs.first;
  }

  List<double> getActionProb(GameState<int, int> game, {temp = 1}) {
    /// This function performs numMCTSSims simulations of MCTS starting from
    /// canonicalBoard.
    /// Returns:
    ///    probs: a policy vector where the probability of the ith action is
    ///           proportional to Nsa[(s,a)]**(1./temp)
    for (var _ in Iterable<int>.generate(simulationCount)) {
      search(game);
    }

    var s = game.id;
    List<double> counts = [
      for (var a in Iterable<int>.generate(game.actionSize))
        Nsa[SA(s, a)]?.toDouble() ?? 0.0
    ];

    var validMoves = game.getMoves().toSet();

    if (temp == 0) {
      double maxScore = counts.reduce(max).toDouble();
      List<int> bestAs = counts
          .asMap()
          .entries
          .map((entry) {
            if (!validMoves.contains(entry.key)) {
              return null;
            }
            if (entry.value >= maxScore - tieTolerance)
              return entry.key;
            else
              return null;
          })
          .whereType<int>()
          .toList();
      bestAs.shuffle(random);
      int bestA = bestAs.first;
      List<double> probs = List.filled(game.actionSize, 0);
      probs[bestA] = 1;
      return probs;
    }

    counts = counts.map((x) => pow(x, (1.0 / temp)).toDouble()).toList();
    double countsSum = counts.reduce((x, y) => x + y);
    counts = [for (var x in counts) x / countsSum];
    return counts;
  }

  double search(GameState<int, int> game) {
    /// This function performs one iteration of MCTS. It is recursively called
    /// till a leaf node is found. The action chosen at each node is one that
    /// has the maximum upper confidence bound as in the paper.

    /// Once a leaf node is found, the neural network is called to return an
    /// initial policy P and a value v for the state. This value is propagated
    /// up the search path. In case the leaf node is a terminal state, the
    /// outcome is propagated up the search path. The values of Ns, Nsa, Qsa are
    /// updated.

    /// NOTE: the return values are the negative of the value of the current
    /// state. This is done since v is in [-1,1] and if v is the value of a
    /// state for the current player, then its value is -v for the other player.

    /// Returns:
    ///     v: the negative of the value of the current canonicalBoard

    int s = game.id;

    if (!Es.containsKey(s)) {
      if (game.winner == null) {
        Es[s] = 0;
      } else {
        // FIXME - hardcoding for Yokai 2p testrun
        Es[s] = (parent[s]!.currentPlayer == 0 ? -1 : 1);
      }
    }
    if (Es[s] != 0) {
      // terminal node
      return -Es[s]!;
    }

    if (!Ps.containsKey(s)) {
      // leaf node
      NNPVResult nnpvResult = nnpv.getResult(game);
      Ps[s] = List.filled(game.actionSize, 0.0);
      var validMoves = game.getMoves().toSet();
      for (var MapEntry(key: moveId, value: probability)
          in nnpvResult.probabilities.entries) {
        // Intentionally not filtering out invalid moves for games with
        // determined states
        Ps[s]![moveId] = probability;
      }
      double sumPss = Ps[s]!.reduce((x, y) => x + y);

      if (sumPss > 0) {
        Ps[s] = Ps[s]!.map((x) => x /= sumPss).toList(); // renormalize
      } else {
        // if all valid moves were masked make all valid moves equally probable
        // NB! All valid moves may be masked if either your NNet architecture
        // is insufficient or you've get overfitting or something else.
        // If you have got dozens or hundreds of these messages you should pay
        // attention to your NNet and/or training process.
        d.log("All valid moves were masked, doing a workaround.");
        for (var moveId in validMoves) {
          Ps[s]![moveId] += 1.0;
        }
        sumPss = Ps[s]!.reduce((x, y) => x + y);
        Ps[s] = Ps[s]!.map((x) => x /= sumPss).toList(); // renormalize
      }
      Vs[s] = validMoves;
      Ns[s] = 0;
      // FIXME - hardcoding for Yokai 2p testrun
      return nnpvResult.value * (game.currentPlayer == 1 ? 1 : -1);
    }

    Set<int> validMoves = Vs[s]!;
    double currentBest = double.negativeInfinity;
    int bestAction = -1;

    // pick the action with the highest upper confidence bound
    for (var a in validMoves) {
      double u = 0;
      if (Qsa.containsKey(SA(s, a))) {
        u = Qsa[SA(s, a)]! +
            cpuct * Ps[s]![a] * sqrt(Ns[s]!) / (1 + Nsa[SA(s, a)]!);
      } else {
        u = cpuct * Ps[s]![a] * sqrt(Ns[s]! + EPS); // Q = 0 ?
      }

      if (u > currentBest) {
        currentBest = u;
        bestAction = a;
      }
    }

    var a = bestAction;

    if (!GamesSa.containsKey(SA(s, a))) {
      var newGame = game.cloneAndApplyMove(a, null);
      GamesSa[SA(s, a)] = newGame;
      parent[newGame.id] = game;
    }

    double v = search(GamesSa[SA(s, a)]!);

    if (Qsa.containsKey(SA(s, a))) {
      Qsa[SA(s, a)] =
          (Nsa[SA(s, a)]! * Qsa[SA(s, a)]! + v) / (Nsa[SA(s, a)]! + 1);
      Nsa[SA(s, a)] = Nsa[SA(s, a)]! + 1;
    } else {
      Qsa[SA(s, a)] = v;
      Nsa[SA(s, a)] = 1;
    }

    Ns[s] = (Ns[s] ?? 0) + 1;
    // FIXME - hardcoding for Yokai 2p testrun
    return v; // * (parent[s]!.currentPlayer == 0 ? 1 : -1);
  }
}
