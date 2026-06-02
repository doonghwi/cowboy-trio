import 'package:flutter/material.dart';

import '../game/trio_logic.dart';
import '../theme.dart';
import 'emo.dart';

/// A single cowboy at the table: avatar, name, ammo and their last revealed
/// move. Shakes briefly when [hit] flips true.
class SeatCard extends StatelessWidget {
  final String name;
  final int ammo;
  final bool alive;
  final bool isMe;
  final bool joined;
  final bool submitted;
  final bool hit;
  final Move? lastMove;
  final bool firedLeft;
  final bool firedRight;

  /// Tighter layout for the two top (opponent) seats.
  final bool compact;

  const SeatCard({
    super.key,
    required this.name,
    required this.ammo,
    required this.alive,
    this.isMe = false,
    this.joined = true,
    this.submitted = false,
    this.hit = false,
    this.lastMove,
    this.firedLeft = false,
    this.firedRight = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = compact ? 40.0 : 54.0;
    final card = Container(
      width: compact ? 120 : 150,
      padding: EdgeInsets.symmetric(
          horizontal: 10, vertical: compact ? 8 : 12),
      decoration: BoxDecoration(
        color: isMe
            ? CD.gold.withValues(alpha: 0.22)
            : CD.parchment.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: !alive
              ? CD.muted.withValues(alpha: 0.5)
              : (isMe ? CD.rust : CD.leather.withValues(alpha: 0.3)),
          width: isMe ? 2.5 : 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: alive ? 1 : 0.55,
                child: Emo(
                  !joined ? 'person' : (alive ? 'cowboy' : 'skull'),
                  size: avatar,
                ),
              ),
              if (submitted && alive)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: CD.sage,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check,
                        size: 13, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            joined ? name : '빈자리',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: compact ? 13 : 15,
              color: alive ? CD.leather : CD.muted,
            ),
          ),
          const SizedBox(height: 4),
          if (alive)
            _ammoRow()
          else
            const Text('탈락', style: TextStyle(color: CD.danger, fontSize: 12, fontWeight: FontWeight.bold)),
          if (lastMove != null && alive) ...[
            const SizedBox(height: 6),
            _lastMoveRow(),
          ],
        ],
      ),
    );

    if (!hit) return card;
    // Quick shake + red flash on a fresh hit.
    return TweenAnimationBuilder<double>(
      key: ValueKey('hit-$name-$ammo'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, t, child) {
        final dx = (t < 1) ? (8 * (1 - t) * (t * 16 % 2 < 1 ? 1 : -1)) : 0.0;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: card,
    );
  }

  Widget _ammoRow() {
    if (ammo <= 0) {
      return const Text('총알 0',
          style: TextStyle(color: CD.muted, fontSize: 11.5));
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 2,
      children: [
        for (var i = 0; i < ammo; i++)
          Container(
            width: 7,
            height: 11,
            decoration: BoxDecoration(
              color: CD.gold,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: CD.leather.withValues(alpha: 0.5)),
            ),
          ),
      ],
    );
  }

  Widget _lastMoveRow() {
    final m = lastMove!;
    final icons = <Widget>[];
    void add(IconData icon, Color c, {String? tip}) {
      icons.add(Icon(icon, size: 16, color: c));
      if (tip != null) {
        icons.add(Text(tip, style: TextStyle(fontSize: 10, color: c)));
      }
      icons.add(const SizedBox(width: 3));
    }

    for (var i = 0; i < m.reload; i++) {
      add(actionIcon(ActKind.reload), CD.gold);
    }
    for (var i = 0; i < m.defend; i++) {
      add(actionIcon(ActKind.defend), CD.sage);
    }
    if (m.shootLeft) {
      add(actionIcon(ActKind.shoot), firedLeft ? CD.danger : CD.muted, tip: '←');
    }
    if (m.shootRight) {
      add(actionIcon(ActKind.shoot), firedRight ? CD.danger : CD.muted, tip: '→');
    }
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: icons,
    );
  }
}
