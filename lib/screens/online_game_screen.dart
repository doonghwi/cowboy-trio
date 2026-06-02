import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/trio_logic.dart';
import '../online/online_service.dart';
import '../theme.dart';
import '../widgets/desert_background.dart';
import '../widgets/move_picker.dart';
import '../widgets/seat_card.dart';

class OnlineGameScreen extends StatefulWidget {
  final OnlineService service;
  final String code;
  final int mySeat;

  const OnlineGameScreen({
    super.key,
    required this.service,
    required this.code,
    required this.mySeat,
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  bool _resetting = false;

  @override
  void dispose() {
    // Best-effort: free my seat when I back out.
    widget.service.leave(widget.code, widget.mySeat);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('방 ${widget.code}', style: posterTitle(20)),
        actions: [
          IconButton(
            tooltip: '방 코드 복사',
            icon: const Icon(Icons.copy, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('방 코드 ${widget.code} 복사됨')),
              );
            },
          ),
        ],
      ),
      body: DesertBackground(
        child: SafeArea(
          child: StreamBuilder<DatabaseEvent>(
            stream: widget.service.watch(widget.code),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: CD.rust));
              }
              final raw = snap.data!.snapshot.value;
              if (raw is! Map) {
                return _info('방이 사라졌어요.', back: true);
              }
              final view =
                  OnlineService.computeView(Map.from(raw), widget.mySeat);
              _maybeReset(view);
              if (view.phase == OnlinePhase.waiting) {
                return _waiting(view);
              }
              return _table(view);
            },
          ),
        ),
      ),
    );
  }

  void _maybeReset(RoomView3 view) {
    // Host clears the board for a fresh round once everyone wants a rematch.
    if (view.phase == OnlinePhase.over &&
        widget.mySeat == 0 &&
        view.rematchCount >= view.playerCount &&
        view.playerCount >= kSeats &&
        !_resetting) {
      _resetting = true;
      widget.service.recordWinAndReset(widget.code, view.winnerSeat);
    }
    if (view.phase != OnlinePhase.over) _resetting = false;
  }

  // ---- Waiting room ------------------------------------------------------

  Widget _waiting(RoomView3 view) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('방 코드', style: posterTitle(20)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('방 코드 복사됨')),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: CD.parchment,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CD.rust, width: 3),
                ),
                child: Text(widget.code,
                    style: westernLatin(46, color: CD.leather, spacing: 10)),
              ),
            ),
            const SizedBox(height: 10),
            const Text('친구에게 코드를 알려주세요 (탭하면 복사)',
                style: TextStyle(color: CD.muted)),
            const SizedBox(height: 28),
            Text('${view.playerCount} / 3 모이는 중',
                style: posterTitle(24, color: Colors.white)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var s = 0; s < kSeats; s++) ...[
                  if (s > 0) const SizedBox(width: 12),
                  SeatCard(
                    name: view.seats[s].name,
                    ammo: 0,
                    alive: true,
                    joined: view.seats[s].joined,
                    isMe: s == widget.mySeat,
                    compact: true,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: CD.gold),
          ],
        ),
      ),
    );
  }

  // ---- Table -------------------------------------------------------------

  Widget _table(RoomView3 view) {
    final me = widget.mySeat;
    final left = leftOf(me);
    final right = rightOf(me);
    return Column(
      children: [
        const SizedBox(height: 6),
        _scoreStrip(view),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _seat(view, left, compact: true),
              _seat(view, right, compact: true),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _bannerBar(view),
        const Spacer(),
        _seat(view, me, isMe: true),
        const SizedBox(height: 10),
        _bottom(view),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _seat(RoomView3 view, int s, {bool isMe = false, bool compact = false}) {
    final sv = view.seats[s];
    final showMove = view.phase != OnlinePhase.choosing &&
        view.phase != OnlinePhase.submitted;
    return SeatCard(
      name: sv.name,
      ammo: sv.ammo,
      alive: sv.alive,
      isMe: isMe,
      submitted: sv.submittedThisTurn && view.phase != OnlinePhase.over,
      hit: sv.hitThisTurn && view.phase == OnlinePhase.over,
      lastMove: showMove ? sv.lastMove : null,
      firedLeft: sv.firedLeft,
      firedRight: sv.firedRight,
      compact: compact,
    );
  }

  Widget _scoreStrip(RoomView3 view) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: CD.leather.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var s = 0; s < kSeats; s++)
            Text('${view.seats[s].name} ${view.seats[s].score}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _bannerBar(RoomView3 view) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: CD.leather.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        view.banner,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _bottom(RoomView3 view) {
    if (view.phase == OnlinePhase.over) return _result(view);

    // I'm out but the round continues — spectate.
    if (!view.me.alive) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('탈락! 관전 중...',
            style: TextStyle(
                color: CD.danger, fontSize: 16, fontWeight: FontWeight.bold)),
      );
    }

    if (view.phase == OnlinePhase.submitted) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircularProgressIndicator(color: CD.sage),
            const SizedBox(height: 10),
            Text('상대를 기다리는 중 (${view.submittedAlive}/${view.aliveCount})',
                style: const TextStyle(color: CD.leather, fontSize: 14)),
          ],
        ),
      );
    }

    final me = widget.mySeat;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: MovePicker(
        myAmmo: view.me.ammo,
        leftAlive: view.seats[leftOf(me)].alive,
        rightAlive: view.seats[rightOf(me)].alive,
        leftName: view.seats[leftOf(me)].name,
        rightName: view.seats[rightOf(me)].name,
        onSubmit: (m) =>
            widget.service.submitMove(widget.code, view.turn, me, m),
      ),
    );
  }

  Widget _result(RoomView3 view) {
    final iWon = view.iWon;
    final draw = view.status == GameStatus.draw;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CD.parchment,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: draw ? CD.muted : (iWon ? CD.gold : CD.danger), width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(view.banner,
              textAlign: TextAlign.center,
              style: posterTitle(26,
                  color: draw ? CD.leather : (iWon ? CD.rust : CD.danger))),
          const SizedBox(height: 12),
          Text('다시하기 ${view.rematchCount}/${view.playerCount}',
              style: const TextStyle(color: CD.muted)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CD.leather,
                    side: const BorderSide(color: CD.leather),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('나가기'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: view.iRequestedRematch
                      ? null
                      : () => widget.service
                          .requestRematch(widget.code, widget.mySeat),
                  style: FilledButton.styleFrom(
                    backgroundColor: CD.rust,
                    disabledBackgroundColor: CD.muted.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(view.iRequestedRematch ? '대기 중...' : '다시하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _info(String msg, {bool back = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(msg, style: posterTitle(20)),
          if (back) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(backgroundColor: CD.rust),
              child: const Text('나가기'),
            ),
          ],
        ],
      ),
    );
  }
}
