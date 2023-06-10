import 'package:dartmcts/net.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'dart:convert';
import 'package:uuid/uuid.dart';

Function? gameHandler;

void serve(TrainableInterface Function() trainer) async {
  var handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(_handleRequest);
  gameHandler = () => trainer.call();

  var server = await shelf_io.serve(handler, 'localhost', 5000);
  print('Serving at http://${server.address.host}:${server.port}');
}

Map<String, TrainableInterface> gamesInProgress = {};

Future<Response> _handleRequest(Request request) async {
  if (request.url.path == "newgame") {
    TrainableInterface game = gameHandler?.call();
    var uuid = const Uuid();
    String id = uuid.v4().toString();
    gamesInProgress[id] = game;
    return Response.ok(
        json.encode({
          "id": id,
          "player_count": game.playerCount,
          "action_space_size": game.actionSpaceSize,
          "observation_space_size": game.observationSpaceSize,
          "current_player": game.currentPlayer,
          "observation": game.observation(),
          "legal_actions": game.legalActions()
        }),
        headers: {'Content-Type': 'application/json'});
  } else {
    var pieces = request.url.path.split('/');
    assert(pieces[0] == "step");
    var id = pieces[1];
    var action = json.decode(await request.readAsString())['action'];
    TrainableInterface? game = gamesInProgress[id]!;
    var gameResponse = game.step(action);
    var stepResponse = json.encode({
      "observation": game.observation(),
      "legal_actions": game.legalActions(),
      "next_player": game.currentPlayer,
      "reward": gameResponse.reward,
      "done": gameResponse.done
    });
    if (gameResponse.done) {
      // free memory for finished games
      gamesInProgress.remove(id);
      game = null;
    }
    return Response.ok(stepResponse,
        headers: {'Content-Type': 'application/json'});
  }
}
