import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../game/trio_logic.dart';

/// Phase of an online room from one player's point of view.
enum OnlinePhase { waiting, choosing, submitted, over }

/// Render-ready snapshot of one seat at the table.
class SeatView {
  final int seat;
  final bool joined;
  final String name;
  final int ammo;
  final bool alive;

  /// The seat's move on the most recently *resolved* turn (for the reveal).
  final Move? lastMove;
  final bool firedLeft;
  final bool firedRight;
  final bool hitThisTurn;

  /// Whether this seat has locked a move for the current (unresolved) turn.
  final bool submittedThisTurn;
  final int score;

  const SeatView({
    required this.seat,
    required this.joined,
    required this.name,
    required this.ammo,
    required this.alive,
    required this.lastMove,
    required this.firedLeft,
    required this.firedRight,
    required this.hitThisTurn,
    required this.submittedThisTurn,
    required this.score,
  });
}

/// A fully-derived, render-ready view of a room from one player's perspective.
class RoomView3 {
  final int playerCount;
  final OnlinePhase phase;
  final int turn;
  final int mySeat;
  final List<SeatView> seats; // length kSeats, index == seat
  final Move? myPending;
  final bool iSubmitted;
  final int submittedAlive; // how many living seats have locked in
  final int aliveCount;
  final GameStatus status;
  final int? winnerSeat;
  final String banner;
  final bool justResolved; // a fresh resolution to animate
  final bool iRequestedRematch;
  final int rematchCount;

  const RoomView3({
    required this.playerCount,
    required this.phase,
    required this.turn,
    required this.mySeat,
    required this.seats,
    required this.myPending,
    required this.iSubmitted,
    required this.submittedAlive,
    required this.aliveCount,
    required this.status,
    required this.winnerSeat,
    required this.banner,
    required this.justResolved,
    required this.iRequestedRematch,
    required this.rematchCount,
  });

  SeatView get me => seats[mySeat];
  bool get iWon => status == GameStatus.won && winnerSeat == mySeat;
}

class OnlineService {
  OnlineService() : clientId = _genClientId();

  final String clientId;

  /// The RTDB lives in asia-southeast1. We pin the regional URL explicitly:
  /// relying on the default instance can connect to the wrong region (the
  /// server then force-closes the socket and writes hang forever).
  static const String databaseUrl =
      'https://cowboy-trio-doonghwi-default-rtdb.asia-southeast1.firebasedatabase.app';

  final DatabaseReference _root =
      FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: databaseUrl)
          .ref();

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _idChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  static String _genClientId() {
    final r = Random();
    return List.generate(10, (_) => _idChars[r.nextInt(_idChars.length)]).join();
  }

  static String generateRoomCode() {
    final r = Random();
    return List.generate(4, (_) => _codeChars[r.nextInt(_codeChars.length)]).join();
  }

  static const _nickPool = [
    '방랑객', '총잡이', '무법자', '보안관', '건맨', '독수리',
    '선인장', '리볼버', '데드샷', '현상금'
  ];

  static String randomNickname() {
    final r = Random();
    return '${_nickPool[r.nextInt(_nickPool.length)]}${10 + r.nextInt(90)}';
  }

  /// RTDB slot key for a seat. Prefixed so Firebase never coerces the player
  /// map into a List (which happens with purely numeric keys).
  static String slotKey(int seat) => 'p$seat';
  static int seatOf(String slotKey) => int.parse(slotKey.substring(1));

  DatabaseReference room(String code) => _root.child('rooms/$code');
  Stream<DatabaseEvent> watch(String code) => room(code).onValue;

  Future<void> createRoom(String code, String name) async {
    await room(code).set({
      'players': {
        'p0': {'id': clientId, 'name': name},
      },
      'turns': null,
      'rematch': null,
      'score': null,
      'createdAt': ServerValue.timestamp,
    });
  }

  /// Claim a guest seat. Seat 0 always belongs to the host, so joiners only ever
  /// take p1 or p2. Each seat is claimed with its **own** transaction so two
  /// joiners can never land on the same seat and no joiner can clobber another's
  /// entry (a whole-node transaction run against a stale snapshot could). The
  /// seat is read back from the committed snapshot, never a closure variable.
  Future<int?> joinRoom(String code, String name) async {
    final snap = await room(code).child('players').get();
    if (!snap.exists) return null;

    // Re-joining with the same client id? Return my existing seat.
    final existing = _asMap(snap.value);
    if (existing != null) {
      for (final e in existing.entries) {
        final v = _asMap(e.value);
        if (v != null && v['id'] == clientId) return seatOf(e.key.toString());
      }
    }

    for (var s = 1; s < kSeats; s++) {
      final res = await room(code).child('players/${slotKey(s)}').runTransaction(
        (current) {
          if (current == null) {
            return Transaction.success({'id': clientId, 'name': name});
          }
          final v = _asMap(current);
          if (v != null && v['id'] == clientId) {
            return Transaction.success(current); // already mine
          }
          return Transaction.abort(); // taken by someone else
        },
      );
      if (res.committed) {
        final v = _asMap(res.snapshot.value);
        if (v != null && v['id'] == clientId) return s;
      }
    }
    return null; // room full
  }

  Future<void> submitMove(String code, int turn, int seat, Move m) {
    return room(code).child('turns/t$turn/${slotKey(seat)}').set(m.encode());
  }

  Future<void> requestRematch(String code, int seat) {
    return room(code).child('rematch/${slotKey(seat)}').set(true);
  }

  /// Host (seat 0) records the winner and clears the board for a fresh round.
  Future<void> recordWinAndReset(String code, int? winnerSeat) async {
    if (winnerSeat != null) {
      await room(code).child('score/${slotKey(winnerSeat)}').runTransaction((cur) {
        final n = cur is int ? cur : 0;
        return Transaction.success(n + 1);
      });
    }
    await room(code).update({'turns': null, 'rematch': null});
  }

  Future<void> leave(String code, int seat) async {
    await room(code).child('players/${slotKey(seat)}').remove();
  }

  // ---- Pure helpers ------------------------------------------------------

  static int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

  static Map? _asMap(Object? v) {
    if (v is Map) return Map<String, Object?>.from(v);
    if (v is List) {
      final m = <String, Object?>{};
      for (var i = 0; i < v.length; i++) {
        if (v[i] != null) m['t$i'] = v[i];
      }
      return m;
    }
    return null;
  }

  /// Deterministic replay of a room into a view for [mySeat]. Mirrors the
  /// offline engine exactly by funnelling every turn through [resolveTurn].
  static RoomView3 computeView(Map data, int mySeat) {
    final players = _asMap(data['players']) ?? const {};
    final turnsMap = _asMap(data['turns']) ?? const {};
    final scoreMap = _asMap(data['score']) ?? const {};
    final rematchMap = _asMap(data['rematch']) ?? const {};

    final names = <String>['', '', ''];
    final joined = <bool>[false, false, false];
    final scores = <int>[0, 0, 0];
    for (var s = 0; s < kSeats; s++) {
      final p = _asMap(players[slotKey(s)]);
      if (p != null) {
        joined[s] = true;
        names[s] = (p['name'] as String?) ?? '카우보이';
      }
      scores[s] = _asInt(scoreMap[slotKey(s)]) ?? 0;
    }
    final playerCount = joined.where((j) => j).length;

    // Not enough players yet.
    if (playerCount < kSeats) {
      return _waitingView(mySeat, joined, names, scores, playerCount);
    }

    var ammo = <int>[0, 0, 0];
    var alive = <bool>[true, true, true];
    var lastMoves = <Move?>[null, null, null];
    var firedL = <bool>[false, false, false];
    var firedR = <bool>[false, false, false];
    var hit = <bool>[false, false, false];
    var banner = '두 가지 행동을 골라라!';
    var justResolved = false;
    var t = 0;

    while (true) {
      final turn = _asMap(turnsMap['t$t']);
      // Collect submissions for the seats that are alive this turn.
      final submitted = <bool>[false, false, false];
      final moves = <Move>[Move.empty, Move.empty, Move.empty];
      var allAliveSubmitted = true;
      for (var s = 0; s < kSeats; s++) {
        if (!alive[s]) continue;
        final raw = turn == null ? null : _asInt(turn[slotKey(s)]);
        if (raw == null) {
          allAliveSubmitted = false;
        } else {
          submitted[s] = true;
          moves[s] = Move.decode(raw);
        }
      }

      if (!allAliveSubmitted) {
        // Mid-turn: waiting for choices.
        final iSubmitted = !alive[mySeat] || submitted[mySeat];
        final aliveCount = alive.where((a) => a).length;
        final submittedAlive = [
          for (var s = 0; s < kSeats; s++)
            if (alive[s] && submitted[s]) s
        ].length;
        return _liveView(
          mySeat: mySeat,
          joined: joined,
          names: names,
          ammo: ammo,
          alive: alive,
          lastMoves: lastMoves,
          firedL: firedL,
          firedR: firedR,
          hit: hit,
          submitted: submitted,
          scores: scores,
          turn: t,
          myPending: submitted[mySeat] ? moves[mySeat] : null,
          iSubmitted: iSubmitted && alive[mySeat],
          submittedAlive: submittedAlive,
          aliveCount: aliveCount,
          banner: iSubmitted && alive[mySeat]
              ? '다른 총잡이를 기다리는 중... ($submittedAlive/$aliveCount)'
              : banner,
          justResolved: justResolved && t == 0 ? false : false,
          playerCount: playerCount,
        );
      }

      // Resolve this fully-submitted turn.
      final out = resolveTurn(moves, ammo, alive);
      ammo = out.ammoAfter;
      lastMoves = List<Move?>.from(moves);
      firedL = out.firedLeft;
      firedR = out.firedRight;
      hit = out.hit;
      alive = out.aliveAfter;
      justResolved = true;
      banner = _turnBanner(moves, out, names);

      if (out.status != GameStatus.ongoing) {
        return _overView(
          mySeat: mySeat,
          joined: joined,
          names: names,
          ammo: ammo,
          alive: alive,
          lastMoves: lastMoves,
          firedL: firedL,
          firedR: firedR,
          hit: hit,
          scores: scores,
          status: out.status,
          winner: out.winner,
          rematchMap: rematchMap,
          playerCount: playerCount,
        );
      }
      t++;
    }
  }

  static RoomView3 _waitingView(int mySeat, List<bool> joined,
      List<String> names, List<int> scores, int playerCount) {
    final seats = [
      for (var s = 0; s < kSeats; s++)
        SeatView(
          seat: s,
          joined: joined[s],
          name: joined[s] ? names[s] : '빈자리',
          ammo: 0,
          alive: true,
          lastMove: null,
          firedLeft: false,
          firedRight: false,
          hitThisTurn: false,
          submittedThisTurn: false,
          score: scores[s],
        ),
    ];
    return RoomView3(
      playerCount: playerCount,
      phase: OnlinePhase.waiting,
      turn: 0,
      mySeat: mySeat,
      seats: seats,
      myPending: null,
      iSubmitted: false,
      submittedAlive: 0,
      aliveCount: kSeats,
      status: GameStatus.ongoing,
      winnerSeat: null,
      banner: '총잡이 $playerCount/3 모이는 중...',
      justResolved: false,
      iRequestedRematch: false,
      rematchCount: 0,
    );
  }

  static RoomView3 _liveView({
    required int mySeat,
    required List<bool> joined,
    required List<String> names,
    required List<int> ammo,
    required List<bool> alive,
    required List<Move?> lastMoves,
    required List<bool> firedL,
    required List<bool> firedR,
    required List<bool> hit,
    required List<bool> submitted,
    required List<int> scores,
    required int turn,
    required Move? myPending,
    required bool iSubmitted,
    required int submittedAlive,
    required int aliveCount,
    required String banner,
    required bool justResolved,
    required int playerCount,
  }) {
    final seats = [
      for (var s = 0; s < kSeats; s++)
        SeatView(
          seat: s,
          joined: joined[s],
          name: names[s],
          ammo: ammo[s],
          alive: alive[s],
          lastMove: lastMoves[s],
          firedLeft: firedL[s],
          firedRight: firedR[s],
          hitThisTurn: hit[s],
          submittedThisTurn: submitted[s],
          score: scores[s],
        ),
    ];
    return RoomView3(
      playerCount: playerCount,
      phase: iSubmitted ? OnlinePhase.submitted : OnlinePhase.choosing,
      turn: turn,
      mySeat: mySeat,
      seats: seats,
      myPending: myPending,
      iSubmitted: iSubmitted,
      submittedAlive: submittedAlive,
      aliveCount: aliveCount,
      status: GameStatus.ongoing,
      winnerSeat: null,
      banner: banner,
      justResolved: justResolved,
      iRequestedRematch: false,
      rematchCount: 0,
    );
  }

  static RoomView3 _overView({
    required int mySeat,
    required List<bool> joined,
    required List<String> names,
    required List<int> ammo,
    required List<bool> alive,
    required List<Move?> lastMoves,
    required List<bool> firedL,
    required List<bool> firedR,
    required List<bool> hit,
    required List<int> scores,
    required GameStatus status,
    required int? winner,
    required Map rematchMap,
    required int playerCount,
  }) {
    final seats = [
      for (var s = 0; s < kSeats; s++)
        SeatView(
          seat: s,
          joined: joined[s],
          name: names[s],
          ammo: ammo[s],
          alive: alive[s],
          lastMove: lastMoves[s],
          firedLeft: firedL[s],
          firedRight: firedR[s],
          hitThisTurn: hit[s],
          submittedThisTurn: false,
          score: scores[s],
        ),
    ];
    var rematchCount = 0;
    var iRematch = false;
    for (var s = 0; s < kSeats; s++) {
      if (rematchMap[slotKey(s)] == true) {
        rematchCount++;
        if (s == mySeat) iRematch = true;
      }
    }
    final banner = status == GameStatus.won
        ? (winner == mySeat ? '최후의 1인! 승리!' : '${names[winner!]} 승리!')
        : '모두 쓰러졌다... 무승부!';
    return RoomView3(
      playerCount: playerCount,
      phase: OnlinePhase.over,
      turn: -1,
      mySeat: mySeat,
      seats: seats,
      myPending: null,
      iSubmitted: true,
      submittedAlive: 0,
      aliveCount: alive.where((a) => a).length,
      status: status,
      winnerSeat: winner,
      banner: banner,
      justResolved: true,
      iRequestedRematch: iRematch,
      rematchCount: rematchCount,
    );
  }

  static String _turnBanner(List<Move> moves, TurnOutcome out, List<String> names) {
    final downed = <String>[
      for (var s = 0; s < kSeats; s++)
        if (out.hit[s]) names[s]
    ];
    if (downed.isNotEmpty) return '${downed.join(", ")} 명중!';
    final anyShot = out.firedLeft.any((x) => x) || out.firedRight.any((x) => x);
    if (anyShot) return '모두 막거나 빗나갔다!';
    return '장전과 방어... 다음 턴!';
  }
}
