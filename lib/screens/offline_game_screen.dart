import 'package:flutter/material.dart';

import '../game/cpu_ai.dart';
import '../game/trio_logic.dart';
import '../theme.dart';
import '../widgets/desert_background.dart';
import '../widgets/move_picker.dart';
import '../widgets/seat_card.dart';

enum _Phase { choosing, reveal, over }

class OfflineGameScreen extends StatefulWidget {
  const OfflineGameScreen({super.key});

  @override
  State<OfflineGameScreen> createState() => _OfflineGameScreenState();
}

class _OfflineGameScreenState extends State<OfflineGameScreen> {
  // Seat 0 = me, seat 1 = my right neighbour, seat 2 = my left neighbour.
  static const _names = ['나', '총잡이 잭', '건맨 빌'];
  final _cpu = CpuAi();

  List<int> _ammo = [0, 0, 0];
  List<bool> _alive = [true, true, true];
  List<Move?> _last = [null, null, null];
  List<bool> _firedL = [false, false, false];
  List<bool> _firedR = [false, false, false];
  List<bool> _hit = [false, false, false];

  int _turn = 0;
  _Phase _phase = _Phase.choosing;
  String _banner = '첫 턴! 아직 총알이 없어요 — 장전부터.';
  GameStatus _status = GameStatus.ongoing;
  int? _winner;

  void _reset() {
    setState(() {
      _ammo = [0, 0, 0];
      _alive = [true, true, true];
      _last = [null, null, null];
      _firedL = [false, false, false];
      _firedR = [false, false, false];
      _hit = [false, false, false];
      _turn = 0;
      _phase = _Phase.choosing;
      _banner = '첫 턴! 아직 총알이 없어요 — 장전부터.';
      _status = GameStatus.ongoing;
      _winner = null;
    });
  }

  void _submit(Move mine) {
    final moves = <Move>[
      mine,
      _alive[1]
          ? _cpu.chooseMove(seat: 1, ammo: _ammo, alive: _alive)
          : Move.empty,
      _alive[2]
          ? _cpu.chooseMove(seat: 2, ammo: _ammo, alive: _alive)
          : Move.empty,
    ];
    final out = resolveTurn(moves, _ammo, _alive);
    setState(() {
      _last = List<Move?>.from(moves);
      _firedL = out.firedLeft;
      _firedR = out.firedRight;
      _hit = out.hit;
      _ammo = out.ammoAfter;
      _alive = out.aliveAfter;
      _banner = _turnBanner(out);
      _status = out.status;
      _winner = out.winner;
      _phase = out.status == GameStatus.ongoing ? _Phase.reveal : _Phase.over;
    });
  }

  void _next() {
    setState(() {
      _hit = [false, false, false];
      _turn++;
      _phase = _Phase.choosing;
      _banner = '${_turn + 1}번째 턴 · 행동 2개를 골라요';
    });
  }

  String _turnBanner(TurnOutcome out) {
    final downed = <String>[
      for (var s = 0; s < kSeats; s++)
        if (out.hit[s]) _names[s]
    ];
    if (downed.isNotEmpty) return '${downed.join(", ")} 명중!';
    final shot = out.firedLeft.any((x) => x) || out.firedRight.any((x) => x);
    return shot ? '모두 막거나 빗나갔다!' : '장전과 방어... 다음 턴!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('컴퓨터와 대결', style: posterTitle(20)),
      ),
      body: DesertBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 6),
              // Opponents: left neighbour (seat 2) on left, right (seat 1) right.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _seat(2, compact: true),
                    _seat(1, compact: true),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _bannerBar(),
              const Spacer(),
              _seat(0, isMe: true),
              const SizedBox(height: 10),
              Expanded(flex: 0, child: _bottomArea()),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seat(int s, {bool isMe = false, bool compact = false}) {
    return SeatCard(
      name: _names[s],
      ammo: _ammo[s],
      alive: _alive[s],
      isMe: isMe,
      submitted: false,
      hit: _hit[s],
      lastMove: _phase == _Phase.choosing ? null : _last[s],
      firedLeft: _firedL[s],
      firedRight: _firedR[s],
      compact: compact,
    );
  }

  Widget _bannerBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: CD.leather.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        _banner,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _bottomArea() {
    switch (_phase) {
      case _Phase.choosing:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: MovePicker(
            myAmmo: _ammo[0],
            leftAlive: _alive[2],
            rightAlive: _alive[1],
            leftName: _names[2],
            rightName: _names[1],
            onSubmit: _submit,
          ),
        );
      case _Phase.reveal:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _next,
              style: FilledButton.styleFrom(
                backgroundColor: CD.sage,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('계속하기', style: posterTitle(18, color: Colors.white)),
            ),
          ),
        );
      case _Phase.over:
        return _resultCard();
    }
  }

  Widget _resultCard() {
    final iWon = _status == GameStatus.won && _winner == 0;
    final draw = _status == GameStatus.draw;
    final title = draw
        ? '무승부!'
        : (iWon ? '승리! 최후의 1인' : '${_names[_winner!]} 승리');
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
          Text(title,
              textAlign: TextAlign.center,
              style: posterTitle(28,
                  color: draw ? CD.leather : (iWon ? CD.rust : CD.danger))),
          const SizedBox(height: 14),
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
                  child: const Text('홈으로'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _reset,
                  style: FilledButton.styleFrom(
                    backgroundColor: CD.rust,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('다시하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
