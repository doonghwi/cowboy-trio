/// Core, UI-independent rules for **Cowboy Trio** — the 3-player spin-off of
/// Cowboy Duel.
///
/// Three cowboys sit in a fixed circle (seats 0, 1, 2). Every turn each living
/// cowboy commits **two action-slots**, chosen from:
///   - 장전 (reload): load one bullet (stackable: 장전+장전 = +2).
///   - 방어 (defend): block an incoming shot from one side (좌/우 each).
///   - 빵야 (shoot):  fire at a *named* neighbour (좌 이웃 / 우 이웃).
///
/// Rules that make the trio different from the duel:
///   * A shot is **directional**. You may not shoot the same neighbour twice in
///     one turn, but you may fire once to the left AND once to the right.
///   * Defence is also per-side, so you can block both directions at once.
///   * Bullets only fire from ammo loaded on a **previous** turn. Ammo reloaded
///     this turn is usable from next turn on, so turn 1 has no live shots.
///   * One clean hit eliminates a cowboy. Last cowboy standing wins; if everyone
///     left dies on the same turn it's a draw.
///
/// Seats are fixed for the whole game: when a cowboy is eliminated their seat
/// stays empty, so the two survivors face each other across exactly one side.
library;

/// The kind of an individual action-slot, used by the UI's picker.
enum ActKind { reload, defend, shoot }

/// Which neighbour a directional action (defend / shoot) points at.
enum Dir { left, right }

extension ActKindLabel on ActKind {
  String get ko {
    switch (this) {
      case ActKind.reload:
        return '장전';
      case ActKind.defend:
        return '방어';
      case ActKind.shoot:
        return '빵야';
    }
  }
}

/// Maximum bullets a cowboy can stockpile.
const int kMaxAmmo = 6;

/// Number of seats at the table.
const int kSeats = 3;

/// The right-hand neighbour of [seat] (clockwise).
int rightOf(int seat) => (seat + 1) % kSeats;

/// The left-hand neighbour of [seat] (counter-clockwise).
int leftOf(int seat) => (seat + 2) % kSeats;

/// One cowboy's full commitment for a turn: exactly two action-slots, captured
/// as a reload count, a defend count, and per-direction shoot flags.
///
/// Defence is by **count**, not direction: each defend slot soaks up one
/// incoming bullet from *either* side. So two defends survive a hit from both
/// neighbours at once, while one defend stops a single hit (whichever side it
/// comes from) but is overwhelmed if both sides fire.
class Move {
  /// Number of reload slots used this turn (0, 1 or 2).
  final int reload;

  /// Number of defend slots used this turn (0, 1 or 2) — incoming hits this can
  /// absorb, regardless of direction.
  final int defend;
  final bool shootLeft;
  final bool shootRight;

  const Move({
    this.reload = 0,
    this.defend = 0,
    this.shootLeft = false,
    this.shootRight = false,
  });

  static const Move empty = Move();

  /// How many of the two slots are filled.
  int get slotsUsed =>
      reload + defend + (shootLeft ? 1 : 0) + (shootRight ? 1 : 0);

  /// A turn is ready to submit once both slots are committed.
  bool get isComplete => slotsUsed == kSlots;

  int get shootsRequested => (shootLeft ? 1 : 0) + (shootRight ? 1 : 0);

  /// Compact integer encoding for Firebase (avoids storing a nested map).
  /// bits 0-1 reload, bits 2-3 defend, bit4 shootL, bit5 shootR.
  int encode() =>
      (reload & 3) |
      ((defend & 3) << 2) |
      (shootLeft ? 16 : 0) |
      (shootRight ? 32 : 0);

  static Move decode(int c) => Move(
        reload: c & 3,
        defend: (c >> 2) & 3,
        shootLeft: c & 16 != 0,
        shootRight: c & 32 != 0,
      );

  Move copyWith({
    int? reload,
    int? defend,
    bool? shootLeft,
    bool? shootRight,
  }) =>
      Move(
        reload: reload ?? this.reload,
        defend: defend ?? this.defend,
        shootLeft: shootLeft ?? this.shootLeft,
        shootRight: shootRight ?? this.shootRight,
      );

  @override
  bool operator ==(Object other) =>
      other is Move && other.encode() == encode();

  @override
  int get hashCode => encode();
}

/// Slots committed per turn.
const int kSlots = 2;

/// The high-level state of the game after a turn resolves.
enum GameStatus { ongoing, won, draw }

/// Immutable result of resolving one simultaneous turn for all three seats.
class TurnOutcome {
  final List<int> ammoAfter; // length kSeats
  final List<bool> aliveAfter; // length kSeats
  final List<bool> firedLeft; // seat fired a live shot to its left
  final List<bool> firedRight; // seat fired a live shot to its right
  final List<bool> hit; // seat took a clean hit this turn (newly eliminated)
  final GameStatus status;

  /// Winning seat when [status] == [GameStatus.won], else null.
  final int? winner;

  const TurnOutcome({
    required this.ammoAfter,
    required this.aliveAfter,
    required this.firedLeft,
    required this.firedRight,
    required this.hit,
    required this.status,
    required this.winner,
  });
}

/// Pure resolution of a single simultaneous turn.
///
/// [moves], [ammoBefore] and [aliveBefore] are all length [kSeats]. Moves for
/// dead seats are ignored. A shot only leaves the barrel if the shooter had
/// ammo *before* this turn and the targeted neighbour is alive; reloads chosen
/// this turn are added afterwards (so they arm the next turn, never this one).
TurnOutcome resolveTurn(
  List<Move> moves,
  List<int> ammoBefore,
  List<bool> aliveBefore,
) {
  assert(moves.length == kSeats);
  final firedRight = List<bool>.filled(kSeats, false);
  final firedLeft = List<bool>.filled(kSeats, false);
  final spent = List<int>.filled(kSeats, 0);

  // Decide which shots actually fire. Right takes priority when ammo is scarce,
  // so resolution is fully deterministic for replay across all clients.
  for (var i = 0; i < kSeats; i++) {
    if (!aliveBefore[i]) continue;
    final m = moves[i];
    var ammo = ammoBefore[i];
    if (m.shootRight && ammo > 0 && aliveBefore[rightOf(i)]) {
      firedRight[i] = true;
      ammo--;
      spent[i]++;
    }
    if (m.shootLeft && ammo > 0 && aliveBefore[leftOf(i)]) {
      firedLeft[i] = true;
      spent[i]++;
    }
  }

  // Work out who takes a clean hit. A shot at seat T arrives from T's left
  // neighbour (who fired right) and/or T's right neighbour (who fired left).
  // Defence is by count: each defend slot soaks one incoming bullet from any
  // side, so a seat falls only when the incoming hits outnumber its defends.
  final hit = List<bool>.filled(kSeats, false);
  for (var t = 0; t < kSeats; t++) {
    if (!aliveBefore[t]) continue;
    final m = moves[t];
    final L = leftOf(t);
    final R = rightOf(t);
    final incoming = (aliveBefore[L] && firedRight[L] ? 1 : 0) +
        (aliveBefore[R] && firedLeft[R] ? 1 : 0);
    if (incoming > m.defend) hit[t] = true;
  }

  final ammoAfter = List<int>.filled(kSeats, 0);
  final aliveAfter = List<bool>.from(aliveBefore);
  for (var i = 0; i < kSeats; i++) {
    if (!aliveBefore[i]) {
      ammoAfter[i] = ammoBefore[i];
      continue;
    }
    var a = ammoBefore[i] - spent[i] + moves[i].reload;
    if (a > kMaxAmmo) a = kMaxAmmo;
    if (a < 0) a = 0;
    ammoAfter[i] = a;
    if (hit[i]) aliveAfter[i] = false;
  }

  final survivors = <int>[
    for (var i = 0; i < kSeats; i++)
      if (aliveAfter[i]) i
  ];
  final GameStatus status;
  int? winner;
  if (survivors.length >= 2) {
    status = GameStatus.ongoing;
  } else if (survivors.length == 1) {
    status = GameStatus.won;
    winner = survivors.first;
  } else {
    status = GameStatus.draw;
  }

  return TurnOutcome(
    ammoAfter: ammoAfter,
    aliveAfter: aliveAfter,
    firedLeft: firedLeft,
    firedRight: firedRight,
    hit: hit,
    status: status,
    winner: winner,
  );
}
