import 'dart:math';

import 'trio_logic.dart';

/// A light, slightly randomised opponent for the offline "vs 2 컴퓨터" mode.
///
/// The bot can see everyone's ammo (it's a casual single-player aid, not a
/// ranked AI) and mixes building up, picking off armed rivals, and turtling so
/// it never feels fully predictable.
class CpuAi {
  final Random _r;
  CpuAi([int? seed]) : _r = seed == null ? Random() : Random(seed);

  /// Choose a complete two-slot [Move] for [seat] given the table state.
  Move chooseMove({
    required int seat,
    required List<int> ammo,
    required List<bool> alive,
  }) {
    final myAmmo = ammo[seat];
    final l = leftOf(seat);
    final r = rightOf(seat);
    final leftAlive = alive[l];
    final rightAlive = alive[r];
    final leftThreat = leftAlive && ammo[l] > 0;
    final rightThreat = rightAlive && ammo[r] > 0;

    // No ammo → cannot shoot. Build up, but raise a shield when menaced.
    if (myAmmo == 0) {
      final threatened = leftThreat || rightThreat;
      if (threatened && _r.nextDouble() < 0.7) {
        final defLeft = leftThreat && (!rightThreat || _r.nextBool());
        return Move(reload: 1, defendLeft: defLeft, defendRight: !defLeft);
      }
      return const Move(reload: 2);
    }

    final livingDirs = <Dir>[
      if (rightAlive) Dir.right,
      if (leftAlive) Dir.left,
    ];
    final roll = _r.nextDouble();

    // Two bullets and two live rivals → sometimes blast both barrels.
    if (myAmmo >= 2 && livingDirs.length == 2 && roll < 0.30) {
      return const Move(shootLeft: true, shootRight: true);
    }

    // Usual play: take one shot, then guard the other side or reload.
    if (roll < 0.80 && livingDirs.isNotEmpty) {
      final Dir tgt;
      if (rightThreat && (!leftThreat || _r.nextBool())) {
        tgt = Dir.right;
      } else if (leftThreat) {
        tgt = Dir.left;
      } else {
        tgt = livingDirs[_r.nextInt(livingDirs.length)];
      }
      final shootR = tgt == Dir.right;
      final otherThreat = shootR ? leftThreat : rightThreat;
      if (otherThreat && _r.nextDouble() < 0.6) {
        return Move(
          shootRight: shootR,
          shootLeft: !shootR,
          defendLeft: shootR, // guard the side we're not shooting
          defendRight: !shootR,
        );
      }
      return Move(reload: 1, shootRight: shootR, shootLeft: !shootR);
    }

    // Turtle up.
    if (leftThreat && rightThreat) {
      return const Move(defendLeft: true, defendRight: true);
    }
    if (leftThreat) return const Move(defendLeft: true, reload: 1);
    if (rightThreat) return const Move(defendRight: true, reload: 1);
    return const Move(reload: 2);
  }
}
