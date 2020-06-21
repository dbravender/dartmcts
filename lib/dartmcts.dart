library dartmcts;

import 'dart:math';

var random = Random();

class InvalidMove implements Exception {}

abstract class GameState<MoveType, PlayerType> {
  GameState<MoveType, PlayerType> cloneAndApplyMove(MoveType move);
  List<MoveType> getMoves();
  GameState<MoveType, PlayerType> determine(
      GameState<MoveType, PlayerType> initialState);
  PlayerType winner;
  PlayerType currentPlayer;
}

class Node<MoveType, PlayerType> {
  GameState<MoveType, PlayerType> gameState;
  final Node<MoveType, PlayerType> parent;
  final MoveType move;
  int visits;
  final int depth;
  final Map<PlayerType, int> winsByPlayer = {};
  int draws;
  final GameState initialState;
  bool needStateReset = false;
  double c = 1.41421356237;
  Map<MoveType, Node<MoveType, PlayerType>> _children = {};

  Node(
      {this.gameState,
      this.parent,
      this.move,
      this.visits = 0,
      this.depth = 0,
      this.draws = 0,
      this.c})
      : initialState = gameState;

  determine() {
    gameState = gameState.determine(initialState);
  }

  resetState() {
    needStateReset = true;
  }

  addNewChildrenForDetermination(List<MoveType> moves) {
    for (var move in moves) {
      if (_children.containsKey(move)) {
        continue;
      }
      _children[move] = Node(
          gameState: gameState,
          move: move,
          parent: this,
          c: c,
          depth: depth + 1);
    }
  }

  Map<MoveType, Node<MoveType, PlayerType>> get children {
    // This GameState might not be selected during a simulation so we only generate
    // the children when necessary
    if (_children.isEmpty || needStateReset) {
      if (move != null) {
        gameState = initialState.cloneAndApplyMove(move);
      }
    }
    var moves = gameState.getMoves();
    addNewChildrenForDetermination(moves);
    return Map.fromEntries(
        _children.entries.where((x) => moves.contains(x.value.move)));
  }

  double ucb1(PlayerType player) {
    if (parent == null || visits == 0) {
      return 0.0;
    }
    return (((winsByPlayer[player] ?? 0) + (draws * 0.5)) / visits) +
        (c * sqrt(log(parent.visits.toDouble() / visits)));
  }

  PlayerType getWinner() {
    return gameState.winner;
  }

  PlayerType currentPlayer() {
    return gameState.currentPlayer;
  }

  Node<MoveType, PlayerType> getBestChild() {
    var sortedChildren = children.entries.toList();
    sortedChildren.sort((a, b) {
      var aVisits = a.value.visits;
      var bVisits = b.value.visits;
      if (aVisits == 0 && bVisits == 0) {
        return random.nextInt(100).compareTo(random.nextInt(100));
      }
      if (aVisits == 0) {
        return -1;
      }
      if (bVisits == 0) {
        return 1;
      }
      return b.value
          .ucb1(currentPlayer())
          .compareTo(a.value.ucb1(currentPlayer()));
    });
    return sortedChildren.first.value;
  }

  backProp() {
    var winner = gameState.winner;
    Node<MoveType, PlayerType> currentNode = this;
    while (currentNode != null) {
      currentNode.visits += 1;
      if (winner == null) {
        currentNode.draws += 1;
      } else {
        if (!currentNode.winsByPlayer.containsKey(winner)) {
          currentNode.winsByPlayer[winner] = 0;
        }
        currentNode.winsByPlayer[winner] += 1;
      }
      currentNode = currentNode.parent;
    }
  }

  Node<MoveType, PlayerType> getMostVisitedChild([List<MoveType> actualMoves]) {
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
  final Node<MoveType, PlayerType> root;
  final MoveType move;
  final List<Node<MoveType, PlayerType>> leafNodes;
  final int maxDepth;
  final int plays;
  MCTSResult({this.root, this.move, this.leafNodes, this.maxDepth, this.plays});
}

class MCTS<MoveType, PlayerType> {
  GameState<MoveType, PlayerType> gameState;
  double c = 1.41421356237;

  MCTS({this.gameState});
  MCTSResult<MoveType, PlayerType> getSimulationResult(
      {Node<MoveType, PlayerType> initialRootNode,
      int iterations = 100,
      double maxSeconds,
      List<MoveType> actualMoves}) {
    var rootNode = initialRootNode;
    if (rootNode == null) {
      rootNode = Node(gameState: gameState, parent: null, move: null, c: c);
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
        if (elapsedTime.inSeconds > maxSeconds) {
          break;
        }
      }
      plays += 1;
      var currentNode = rootNode;
      while (currentNode.children.length > 0) {
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
