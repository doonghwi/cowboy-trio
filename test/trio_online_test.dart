import 'package:cowboy_trio/game/trio_logic.dart';
import 'package:cowboy_trio/online/online_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a room map with three seated players.
Map _room({
  Map<String, Map<String, int>> turns = const {},
  Map<String, int> score = const {},
  Map<String, bool> rematch = const {},
}) =>
    {
      'players': {
        'p0': {'id': 'a', 'name': 'A'},
        'p1': {'id': 'b', 'name': 'B'},
        'p2': {'id': 'c', 'name': 'C'},
      },
      'turns': turns,
      'score': score,
      'rematch': rematch,
    };

void main() {
  test('fewer than three players → waiting', () {
    final data = {
      'players': {
        'p0': {'id': 'a', 'name': 'A'},
        'p1': {'id': 'b', 'name': 'B'},
      },
    };
    final v = OnlineService.computeView(data, 0);
    expect(v.phase, OnlinePhase.waiting);
    expect(v.playerCount, 2);
  });

  test('three players, no moves → choosing on turn 0', () {
    final v = OnlineService.computeView(_room(), 1);
    expect(v.phase, OnlinePhase.choosing);
    expect(v.turn, 0);
    expect(v.aliveCount, 3);
  });

  test('one of three submitted → others still choosing, I am submitted', () {
    final data = _room(turns: {
      't0': {'p0': const Move(reload: 2).encode()},
    });
    final me = OnlineService.computeView(data, 0);
    expect(me.phase, OnlinePhase.submitted);
    expect(me.submittedAlive, 1);
    final other = OnlineService.computeView(data, 1);
    expect(other.phase, OnlinePhase.choosing);
  });

  test('deterministic replay ends with the right winner', () {
    final reload2 = const Move(reload: 2).encode();
    final bothBarrels = const Move(shootLeft: true, shootRight: true).encode();
    final data = _room(turns: {
      // Turn 0: everyone loads up.
      't0': {'p0': reload2, 'p1': reload2, 'p2': reload2},
      // Turn 1: seat 0 fires both ways; the others just reload (no defense).
      't1': {'p0': bothBarrels, 'p1': reload2, 'p2': reload2},
    });
    final v = OnlineService.computeView(data, 0);
    expect(v.phase, OnlinePhase.over);
    expect(v.status, GameStatus.won);
    expect(v.winnerSeat, 0);
    expect(v.iWon, isTrue);
    // Seats 1 and 2 are out.
    expect(v.seats[1].alive, isFalse);
    expect(v.seats[2].alive, isFalse);
  });

  test('rematch tally and scores surface in the view', () {
    final reload2 = const Move(reload: 2).encode();
    final bothBarrels = const Move(shootLeft: true, shootRight: true).encode();
    final data = _room(
      turns: {
        't0': {'p0': reload2, 'p1': reload2, 'p2': reload2},
        't1': {'p0': bothBarrels, 'p1': reload2, 'p2': reload2},
      },
      score: {'p0': 2, 'p1': 1},
      rematch: {'p0': true, 'p2': true},
    );
    final v = OnlineService.computeView(data, 0);
    expect(v.rematchCount, 2);
    expect(v.iRequestedRematch, isTrue);
    expect(v.seats[0].score, 2);
    expect(v.seats[1].score, 1);
  });

  test('slot keys avoid the numeric-key List trap', () {
    expect(OnlineService.slotKey(0), 'p0');
    expect(OnlineService.seatOf('p2'), 2);
  });
}
