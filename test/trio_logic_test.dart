import 'package:cowboy_trio/game/trio_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Move encode/decode', () {
    test('round-trips every valid 2-slot combination', () {
      final moves = <Move>[
        const Move(reload: 2),
        const Move(reload: 1, defend: 1),
        const Move(defend: 2),
        const Move(reload: 1, shootLeft: true),
        const Move(reload: 1, shootRight: true),
        const Move(defend: 1, shootRight: true),
        const Move(shootLeft: true, shootRight: true),
        const Move(defend: 1, shootLeft: true),
      ];
      for (final m in moves) {
        expect(m.slotsUsed, 2, reason: 'each fixture uses two slots');
        expect(Move.decode(m.encode()), m);
      }
    });
  });

  group('neighbours', () {
    test('form a fixed clockwise circle', () {
      expect(rightOf(0), 1);
      expect(rightOf(1), 2);
      expect(rightOf(2), 0);
      expect(leftOf(0), 2);
      expect(leftOf(1), 0);
      expect(leftOf(2), 1);
    });
  });

  group('resolveTurn — ammo & timing', () {
    test('reload this turn is not usable until next turn', () {
      // Everyone reloads twice on turn 1; nobody can have fired.
      final out = resolveTurn(
        [const Move(reload: 2), const Move(reload: 2), const Move(reload: 2)],
        [0, 0, 0],
        [true, true, true],
      );
      expect(out.ammoAfter, [2, 2, 2]);
      expect(out.firedLeft, [false, false, false]);
      expect(out.firedRight, [false, false, false]);
      expect(out.status, GameStatus.ongoing);
    });

    test('a shoot with zero ammo does not fire', () {
      final out = resolveTurn(
        [const Move(shootRight: true, reload: 1), const Move(reload: 2),
            const Move(reload: 2)],
        [0, 0, 0],
        [true, true, true],
      );
      expect(out.firedRight[0], isFalse);
      expect(out.hit, [false, false, false]);
    });
  });

  group('resolveTurn — directional hits', () {
    test('shooting right hits the right neighbour who did not defend', () {
      // Seat 0 has a bullet and shoots right at seat 1; seat 1 reloads.
      final out = resolveTurn(
        [const Move(shootRight: true, reload: 1), const Move(reload: 2),
            const Move(reload: 2)],
        [1, 0, 0],
        [true, true, true],
      );
      expect(out.firedRight[0], isTrue);
      expect(out.hit[1], isTrue);
      expect(out.aliveAfter, [true, false, true]);
      expect(out.status, GameStatus.ongoing);
      // Shooter spent the bullet but still banked the reload.
      expect(out.ammoAfter[0], 1);
    });

    test('one defend blocks a single incoming shot', () {
      // Seat 0 shoots right at seat 1; seat 1 raises one shield.
      final out = resolveTurn(
        [const Move(shootRight: true, reload: 1),
            const Move(defend: 1, reload: 1), const Move(reload: 2)],
        [1, 0, 0],
        [true, true, true],
      );
      expect(out.hit[1], isFalse);
      expect(out.aliveAfter, [true, true, true]);
    });

    test('one defend is overwhelmed by hits from both sides', () {
      // Both neighbours fire at seat 0; a single shield only stops one.
      final out = resolveTurn(
        [const Move(defend: 1), const Move(shootLeft: true),
            const Move(shootRight: true)],
        [0, 1, 1],
        [true, true, true],
      );
      expect(out.hit[0], isTrue);
    });

    test('two defends survive hits from both sides at once', () {
      // Both neighbours fire at seat 0; two shields soak both bullets.
      final out = resolveTurn(
        [const Move(defend: 2), const Move(shootLeft: true),
            const Move(shootRight: true)],
        [0, 1, 1],
        [true, true, true],
      );
      expect(out.hit[0], isFalse);
      expect(out.aliveAfter[0], isTrue);
    });

    test('one cowboy can hit both neighbours in a single turn', () {
      // Seat 0 has two bullets, fires both ways; neither neighbour defends.
      final out = resolveTurn(
        [const Move(shootLeft: true, shootRight: true), const Move(reload: 2),
            const Move(reload: 2)],
        [2, 0, 0],
        [true, true, true],
      );
      expect(out.firedRight[0], isTrue);
      expect(out.firedLeft[0], isTrue);
      expect(out.hit[1], isTrue); // right neighbour
      expect(out.hit[2], isTrue); // left neighbour
      expect(out.aliveAfter, [true, false, false]);
      expect(out.status, GameStatus.won);
      expect(out.winner, 0);
      expect(out.ammoAfter[0], 0);
    });
  });

  group('resolveTurn — endgame', () {
    test('last cowboy standing wins', () {
      final out = resolveTurn(
        [const Move(shootRight: true), const Move(reload: 2),
            const Move(reload: 2)],
        [1, 0, 0],
        [true, true, true],
      );
      expect(out.status, GameStatus.ongoing); // 2 remain
      // Now 1v1: seats 0 & 2 alive (seat 1 dead). Seat 0's living target is its
      // left (seat 2). Seat 0 shoots left, seat 2 is caught reloading.
      final out2 = resolveTurn(
        [const Move(shootLeft: true), Move.empty, const Move(reload: 2)],
        [1, 0, 0],
        [true, false, true],
      );
      expect(out2.hit[2], isTrue);
      expect(out2.status, GameStatus.won);
      expect(out2.winner, 0);
    });

    test('mutual kill on the same turn is a draw', () {
      // 1v1 (seat 1 dead). Seats 0 and 2 shoot each other simultaneously.
      final out = resolveTurn(
        [const Move(shootLeft: true), Move.empty,
            const Move(shootRight: true)],
        [1, 0, 1],
        [true, false, true],
      );
      expect(out.aliveAfter, [false, false, false]);
      expect(out.status, GameStatus.draw);
      expect(out.winner, isNull);
    });

    test('shot at a dead seat fizzles and keeps its bullet', () {
      // Seat 1 is dead; seat 0 wastes a shoot-right at the empty seat.
      final out = resolveTurn(
        [const Move(shootRight: true), Move.empty, const Move(reload: 1)],
        [1, 0, 0],
        [true, false, true],
      );
      expect(out.firedRight[0], isFalse);
      expect(out.ammoAfter[0], 1); // bullet retained
      expect(out.status, GameStatus.ongoing);
    });
  });
}
