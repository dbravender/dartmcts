library dartmcts;

import 'dart:math';

class InvalidMove implements Exception {}

abstract class RewardProvider<PlayerType> {
  Map<PlayerType, double> rewards();
}

abstract class GameState<MoveType, PlayerType> {
  GameState<MoveType, PlayerType> cloneAndApplyMove(
      MoveType move, Node<MoveType, PlayerType>? root);
  List<MoveType> getMoves();
  GameState<MoveType, PlayerType>? determine(
      GameState<MoveType, PlayerType>? initialState);
  PlayerType? winner;
  PlayerType? currentPlayer;
  Map<String, dynamic> toJson();
}

class NNPVResult<MoveType> {
  Map<MoveType, double> probabilities;
  Map<MoveType, double> qs;
  double value;

  NNPVResult(
      {required this.probabilities, required this.qs, required this.value});
}

abstract class NeuralNetworkPolicyAndValue<MoveType, PlayerType> {
  NNPVResult<MoveType> getResult(GameState<MoveType, PlayerType?> game);
}

class Config<MoveType, PlayerType> {
  late double c;
  NeuralNetworkPolicyAndValue<MoveType, PlayerType>? nnpv;
  double? valueThreshold;
  int? useValueAfterDepth;
  late Random random;
  PlayerType Function(PlayerType)? opponentWinsShortCircuit;
  bool useRewards;
  bool backpropNNPVValue;
  bool immediateBackpropNNPVRewards;

  Config({
    double? c,
    this.nnpv,
    this.valueThreshold,
    this.useValueAfterDepth,
    this.opponentWinsShortCircuit,
    Random? random,
    this.useRewards = false,
    this.backpropNNPVValue = false,
    this.immediateBackpropNNPVRewards = false,
  }) {
    this.random = random ?? Random();
    this.c = c ?? 1.41421356237; // square root of 2
  }
}

class Node<MoveType, PlayerType> {
  GameState<MoveType?, PlayerType?>? gameState;
  Node<MoveType, PlayerType>? root;
  Node<MoveType, PlayerType>? parent;
  final MoveType? move;
  int visits;
  final int depth;
  final Map<PlayerType, double> winsByPlayer = {};
  int draws;
  final GameState? initialState;
  bool needStateReset = false;
  Map<MoveType?, Node<MoveType, PlayerType>> _children = {};
  NNPVResult<MoveType>? _nnpvResult;
  Config<MoveType, PlayerType> config;
  double q = 0;

  Node({
    this.gameState,
    this.parent,
    this.move,
    this.visits = 0,
    this.depth = 0,
    this.draws = 0,
    root,
    required this.config,
    this.q = 0,
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
        config: config,
        move: move,
        parent: this,
        root: root,
        depth: depth + 1,
      );
    }
  }

  Map<MoveType?, Node<MoveType, PlayerType>> get children {
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
      return 0;
    }
    if (priorScore == 1.0) {
      return ((winsByPlayer[player] ?? 0 + (draws * 0.5)) / visits) +
          (config.c * sqrt(log(parent!.visits.toDouble()) / visits));
    } else {
      // Q[s][a] + c_puct*P[s][a]*sqrt(sum(N[s]))/(1+N[s][a])
      return q +
          config.c *
              priorScore *
              sqrt(parent!.visits.toDouble()) /
              (1.0 + visits.toDouble());
    }
  }

  PlayerType? getWinner() {
    return gameState!.winner;
  }

  PlayerType? currentPlayer() {
    return gameState!.currentPlayer;
  }

  NNPVResult<MoveType> get nnpvResult {
    if (_nnpvResult == null && config.nnpv != null) {
      _nnpvResult =
          config.nnpv!.getResult(gameState as GameState<MoveType, PlayerType?>);
    }
    return _nnpvResult!;
  }

  Node<MoveType, PlayerType?> getBestChild() {
    var player = currentPlayer()!;
    var sortedChildren = children.entries.toList();
    sortedChildren.sort((a, b) {
      var aVisits = a.value.visits;
      var bVisits = b.value.visits;
      if (aVisits == 0 && bVisits == 0) {
        return config.random.nextInt(100).compareTo(config.random.nextInt(100));
      }
      if (aVisits == 0) {
        return -1;
      }
      if (bVisits == 0) {
        return 1;
      }
      double bScore = b.value.ucb1(player,
          config.nnpv != null ? (nnpvResult.probabilities[b.key] ?? 1.0) : 1.0);
      double aScore = a.value.ucb1(player,
          config.nnpv != null ? (nnpvResult.probabilities[a.key] ?? 1.0) : 1.0);
      return bScore.compareTo(aScore);
    });
    List<MapEntry<MoveType?, Node<MoveType, PlayerType?>>> tiedChildren = [];
    for (var x in sortedChildren) {
      if (x.value.visits == sortedChildren.first.value.visits) {
        tiedChildren.add(x);
      }
    }
    tiedChildren.shuffle(config.random);
    return tiedChildren.first.value;
  }

  backProp(PlayerType? winner) {
    Node<MoveType, PlayerType?>? currentNode = this;

    while (currentNode != null) {
      double reward = 0.0;
      if (winner == null) {
        currentNode.draws += 1;
        reward = 0.5;
      } else {
        currentNode.winsByPlayer
            .update(winner, (value) => value + 1, ifAbsent: () => 1);
        reward = currentNode.parent?.currentPlayer() == winner ? 1 : 0;
      }
      // Q[s][a] = (N[s][a]*Q[s][a] + v)/(N[s][a]+1)
      currentNode.q = (currentNode.visits * currentNode.q + reward) /
          (currentNode.visits + 1.0);
      currentNode.visits += 1;
      currentNode = currentNode.parent;
    }
  }

  rewardBackProp(Map<PlayerType, double> rewards) {
    Node<MoveType, PlayerType?>? currentNode = this;
    while (currentNode != null) {
      rewards.forEach((player, reward) {
        if (player == currentNode?.parent?.currentPlayer()) {
          currentNode?.winsByPlayer.update(player, (value) => value + reward,
              ifAbsent: () => reward);
        }
      });
      var currentPlayerReward =
          rewards[currentNode.parent?.currentPlayer()] ?? 0;
      // Q[s][a] = (N[s][a]*Q[s][a] + v)/(N[s][a]+1)
      currentNode.q =
          (currentNode.visits * currentNode.q + currentPlayerReward) /
              (currentNode.visits + 1.0);
      currentNode.visits += 1;
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
  final List<Node<MoveType, PlayerType>>? roots;
  final MoveType? move;
  final List<Node<MoveType, PlayerType>>? leafNodes;
  final int? maxDepth;
  final int? plays;
  final int nodesVisited;
  MCTSResult(
      {this.root,
      this.roots = null,
      this.move,
      this.leafNodes,
      this.maxDepth,
      this.plays,
      this.nodesVisited = 0});
}

class MCTS<MoveType, PlayerType> {
  GameState<MoveType, PlayerType>? gameState;

  MCTS({this.gameState});
  MCTSResult<MoveType, PlayerType> getSimulationResult({
    Node<MoveType, PlayerType>? initialRootNode,
    int iterations = 100,
    double? maxSeconds,
    List<MoveType>? actualMoves,
    NeuralNetworkPolicyAndValue<MoveType, PlayerType>? nnpv,
    double? c,
    int? useValueAfterDepth,
    double? valueThreshold,
    Random? random,
    PlayerType Function(PlayerType)? opponentWinsShortCircuit,
    bool useRewards = false,
    bool resetDepth = true,
    bool backpropNNPVValue = false,
    bool immediateBackpropNNPVRewards = false,
    int redetermineStep =
        0, // determine every time by default (previous behavior)
    bool returnRootPerDetermination = false,
  }) {
    var rootNode = initialRootNode;
    Config<MoveType, PlayerType> config = Config(
      c: c,
      nnpv: nnpv,
      useValueAfterDepth: useValueAfterDepth,
      valueThreshold: valueThreshold,
      random: random,
      opponentWinsShortCircuit: opponentWinsShortCircuit,
      useRewards: useRewards,
      backpropNNPVValue: backpropNNPVValue,
      immediateBackpropNNPVRewards: immediateBackpropNNPVRewards,
    );
    if (rootNode == null) {
      rootNode = Node(
        gameState: gameState,
        parent: null,
        move: null,
        config: config,
      );
    } else {
      rootNode.parent = null;
      rootNode.resetState();
    }
    int nodesVisited = 0;
    rootNode.config = config;
    var plays = 0;
    var maxDepth = 0;
    var currentDepth = 0;
    var startTime = DateTime.now();

    var iterationsToRun = iterations;
    if (maxSeconds != null) {
      iterationsToRun = 9223372; // really big integer
    }

    while (plays < iterationsToRun) {
      rootNode.determine();
      Map<PlayerType, double> nnpvRewards = {};
      if (resetDepth) currentDepth = 0;
      if (maxSeconds != null) {
        var elapsedTime = DateTime.now().difference(startTime);
        if (elapsedTime.inSeconds > maxSeconds.toInt()) {
          break;
        }
      }
      plays += 1;
      Node<MoveType, PlayerType?> currentNode = rootNode;

      PlayerType? winner;

      while (currentNode.children.length > 0 &&
          currentNode.gameState?.winner == null) {
        nodesVisited++;
        currentNode = currentNode.getBestChild();
        currentNode.resetState();
        if (config.nnpv != null &&
            currentNode.parent?.currentPlayer() != null) {
          nnpvRewards[currentNode.parent!.currentPlayer()!] =
              currentNode.nnpvResult.value;
        }
        if (currentNode.gameState?.winner != null) {
          winner = currentNode.gameState?.winner;
          break;
        }
        if (config.immediateBackpropNNPVRewards && currentNode.visits == 0) {
          break;
        }
        winner = getShortcutWinner(currentDepth, config, currentNode);
        if (winner != null) {
          break;
        }
        currentDepth += 1;
      }

      if (config.immediateBackpropNNPVRewards && currentNode.visits == 0) {
        currentNode.rewardBackProp(nnpvRewards);
      } else if (gameState is RewardProvider && config.useRewards) {
        currentNode.rewardBackProp(
            (gameState as RewardProvider<PlayerType>).rewards());
      } else if (config.backpropNNPVValue) {
        currentNode.rewardBackProp(nnpvRewards);
      } else {
        currentNode.backProp(winner);
      }
      maxDepth = max(maxDepth, currentNode.depth);
    }

    var selectedMove = rootNode.getMostVisitedChild(actualMoves).move;
    assert(actualMoves?.contains(selectedMove) != false);
    return MCTSResult(
        root: rootNode,
        move: selectedMove,
        maxDepth: maxDepth,
        plays: plays,
        nodesVisited: nodesVisited);
  }

  PlayerType? getShortcutWinner(int currentDepth, Config config,
      Node<MoveType, PlayerType?> currentNode) {
    if (config.nnpv == null &&
        config.useRewards == true &&
        gameState is RewardProvider) {
      if (currentDepth >= config.useValueAfterDepth!) {
        var rewards = (gameState as RewardProvider).rewards();
        var sortedRewards = List.from(rewards.values);
        sortedRewards.sort();
        var highestReward = sortedRewards.last;
        for (var player in rewards.keys) {
          if (highestReward == rewards[player]) {
            return player;
          }
        }
      }
    }
    if (config.nnpv != null &&
        config.useValueAfterDepth != null &&
        config.valueThreshold != null) {
      if (currentDepth >= config.useValueAfterDepth!) {
        //d.log('currentDepth: $currentDepth');
        double currentValue = currentNode.nnpvResult.value;
        //d.log('currentValue: $currentValue');
        if (currentValue >= config.valueThreshold!) {
          return currentNode.gameState!.currentPlayer;
        } else {
          if (config.opponentWinsShortCircuit != null) {
            return config.opponentWinsShortCircuit
                ?.call(currentNode.gameState!.currentPlayer);
          }
        }
      }
    }
    return null;
  }
}
