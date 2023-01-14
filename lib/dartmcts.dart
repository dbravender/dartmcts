library dartmcts;

import 'dart:math';

var random = Random();

class InvalidMove implements Exception {}

abstract class GameState<MoveType, PlayerType> {
  GameState<MoveType, PlayerType> cloneAndApplyMove(
      MoveType move, Node<MoveType, PlayerType>? root);
  List<MoveType> getMoves();
  GameState<MoveType, PlayerType>? determine(
      GameState<MoveType, PlayerType>? initialState);
  PlayerType? winner;
  PlayerType? currentPlayer;
}

abstract class NeuralNetworkPolicyAndValue<MoveType, PlayerType> {
  Map<MoveType, double> getMoveProbabilities(
      GameState<MoveType?, PlayerType?> game);
  double getCurrentValue(GameState<MoveType, PlayerType> game);
}

class Node<MoveType, PlayerType> {
  GameState<MoveType?, PlayerType?>? gameState;
  Node<MoveType, PlayerType>? root;
  final Node<MoveType, PlayerType>? parent;
  final MoveType? move;
  int visits;
  final int depth;
  final Map<PlayerType, int> winsByPlayer = {};
  int draws;
  final GameState? initialState;
  bool needStateReset = false;
  double c;
  Map<MoveType?, Node<MoveType, PlayerType>> _children = {};
  NeuralNetworkPolicyAndValue? nnpv;
  Map<MoveType?, double> _moveProbabilitiesFromNN = {};
  Function? backpropObserver;
  int? useValueAfterDepth;
  double? valueThreshold;

  Node({
    this.gameState,
    this.parent,
    this.move,
    this.visits = 0,
    this.depth = 0,
    this.draws = 0,
    root,
    this.c = 1.41421356237, // square root of 2
    this.backpropObserver,
    this.nnpv,
    this.useValueAfterDepth,
    this.valueThreshold,
  }) : initialState = gameState {
    this.root ??= this;
  }

  determine() {
    gameState = gameState!
        .determine(initialState as GameState<MoveType?, PlayerType?>?);
  }

  resetState() {
    needStateReset = true;
  }

  addNewChildrenForDetermination(List<MoveType?> moves) {
    for (var move in moves) {
      if (_children.containsKey(move)) {
        continue;
      }
      _children[move] = Node(
          gameState: gameState,
          backpropObserver: backpropObserver,
          move: move,
          parent: this,
          root: root,
          c: c,
          depth: depth + 1,
          nnpv: nnpv,
          useValueAfterDepth: useValueAfterDepth,
          valueThreshold: valueThreshold);
    }
  }

  Map<MoveType?, Node<MoveType, PlayerType?>> get children {
    // This GameState might not be selected during a simulation so we only generate
    // the children when necessary
    if (_children.isEmpty || needStateReset) {
      if (move != null) {
        gameState = initialState!.cloneAndApplyMove(move, root)
            as GameState<MoveType?, PlayerType?>?;
      }
    }
    var moves = gameState!.getMoves();
    addNewChildrenForDetermination(moves);
    return Map.fromEntries(
        _children.entries.where((x) => moves.contains(x.value.move)));
  }

  double ucb1(PlayerType player, double priorScore) {
    if (parent == null || visits == 0) {
      return priorScore;
    }
    var ucb = ((winsByPlayer[player] ?? 0 + (draws * 0)) / visits) +
        (c * priorScore * sqrt(log(parent!.visits.toDouble() / visits)));
    return ucb;
  }

  PlayerType? getWinner() {
    return gameState!.winner;
  }

  PlayerType? currentPlayer() {
    return gameState!.currentPlayer;
  }

  Node<MoveType, PlayerType?> getBestChild() {
    if (nnpv != null && _moveProbabilitiesFromNN.isEmpty) {
      _moveProbabilitiesFromNN = nnpv!.getMoveProbabilities(
              gameState as GameState<MoveType?, PlayerType>)
          as Map<MoveType?, double>;
    }
    var player = currentPlayer();
    var sortedChildren = children.entries.toList();
    sortedChildren.sort((a, b) {
      var aVisits = a.value.visits;
      var bVisits = b.value.visits;
      if (_moveProbabilitiesFromNN.isNotEmpty &&
          (aVisits == 0 || bVisits == 0)) {
        return (_moveProbabilitiesFromNN[b.key]!)
            .compareTo(_moveProbabilitiesFromNN[a.key]!);
      }
      if (aVisits == 0 && bVisits == 0) {
        return random.nextInt(100).compareTo(random.nextInt(100));
      }
      if (aVisits == 0) {
        return -1;
      }
      if (bVisits == 0) {
        return 1;
      }
      double bScore =
          b.value.ucb1(player, _moveProbabilitiesFromNN[b.key] ?? 1.0);
      double aScore =
          a.value.ucb1(player, _moveProbabilitiesFromNN[a.key] ?? 1.0);
      return bScore.compareTo(aScore);
    });
    List<MapEntry<MoveType?, Node<MoveType, PlayerType?>>> tiedChildren = [];
    for (var x in sortedChildren) {
      if (x.value.visits == sortedChildren.first.value.visits) {
        tiedChildren.add(x);
      }
    }
    tiedChildren.shuffle();
    return tiedChildren.first.value;
  }

  backProp() {
    var winner = gameState!.winner;
    Node<MoveType, PlayerType?>? currentNode = this;
    Node<MoveType, PlayerType?>? rootNode = this;

    if (backpropObserver != null) {
      while (rootNode!.parent != null) {
        rootNode = rootNode.parent;
      }
      backpropObserver!(winner, rootNode, currentNode);
    }
    while (currentNode != null) {
      currentNode.visits += 1;
      if (winner == null) {
        currentNode.draws += 1;
      } else {
        currentNode.winsByPlayer
            .update(winner, (value) => value + 1, ifAbsent: () => 0);
      }
      currentNode = currentNode.parent;
    }
  }

  Node<MoveType, PlayerType?> getMostVisitedChild(
      [List<MoveType>? actualMoves]) {
    var currentChildren = children;
    if (actualMoves != null) {
      addNewChildrenForDetermination(actualMoves);
      currentChildren = Map.fromEntries(
          _children.entries.where((x) => actualMoves.contains(x.value.move)));
    }
    var sortedChildren = currentChildren.entries.toList();
    sortedChildren.sort((b, a) => a.value.visits.compareTo(b.value.visits));
    return sortedChildren.first.value;
  }
}

class MCTSResult<MoveType, PlayerType> {
  final Node<MoveType, PlayerType>? root;
  final MoveType? move;
  final List<Node<MoveType, PlayerType>>? leafNodes;
  final int? maxDepth;
  final int? plays;
  MCTSResult({this.root, this.move, this.leafNodes, this.maxDepth, this.plays});
}

class MCTS<MoveType, PlayerType> {
  GameState<MoveType, PlayerType>? gameState;
  Function? backpropObserver;
  double c = 1.41421356237; // square root of 2

  MCTS({this.gameState, this.backpropObserver});
  MCTSResult<MoveType, PlayerType> getSimulationResult({
    Node<MoveType, PlayerType>? initialRootNode,
    int iterations = 100,
    double? maxSeconds,
    List<MoveType>? actualMoves,
    NeuralNetworkPolicyAndValue? nnpv,
    int? useValueAfterDepth,
    double? valueThreshold,
  }) {
    var rootNode = initialRootNode;
    if (rootNode == null) {
      rootNode = Node(
        gameState: gameState,
        parent: null,
        move: null,
        c: c,
        backpropObserver: backpropObserver,
        nnpv: nnpv,
        useValueAfterDepth: useValueAfterDepth,
        valueThreshold: valueThreshold,
      );
    }
    var plays = 0;
    var maxDepth = 0;
    var startTime = DateTime.now();

    var iterationsToRun = iterations;
    if (maxSeconds != null) {
      iterationsToRun = 9223372036854775807; // max integer value
    }

    while (plays < iterationsToRun) {
      rootNode.determine();
      if (maxSeconds != null) {
        var elapsedTime = DateTime.now().difference(startTime);
        if (elapsedTime.inSeconds > maxSeconds.toInt()) {
          break;
        }
      }
      plays += 1;
      Node<MoveType, PlayerType?> currentNode = rootNode;

      t:
      while (currentNode.children.length > 0 &&
          currentNode.gameState?.winner == null) {
        if (currentNode.useValueAfterDepth != null &&
            currentNode.depth >= currentNode.useValueAfterDepth!) {
          if (currentNode.nnpv!.getCurrentValue(currentNode.gameState!) >=
              currentNode.valueThreshold!) {
            currentNode.gameState!.winner =
                currentNode.gameState!.currentPlayer;
          } else {
            currentNode.gameState!.winner = null;
          }
          break t;
        }
        currentNode = currentNode.getBestChild();
        currentNode.resetState();
      }

      currentNode.backProp();
      maxDepth = max(maxDepth, currentNode.depth);
    }

    var selectedMove = rootNode.getMostVisitedChild(actualMoves).move;

    return MCTSResult(
        root: rootNode, move: selectedMove, maxDepth: maxDepth, plays: plays);
  }
}
