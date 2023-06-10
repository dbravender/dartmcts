.PHONY: ready

ready:
	dart analyze .
	dart test

traintictactoe:
	dart bin/tictactoeserver.dart
