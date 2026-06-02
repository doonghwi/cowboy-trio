import 'package:flutter/material.dart';

import '../game/trio_logic.dart';
import '../theme.dart';

/// Lets a cowboy assemble this turn's two action-slots and lock them in.
///
/// Enforces every rule at the UI level so [Move] always arrives valid:
///   * exactly two slots,
///   * no more shoots than current ammo,
///   * no shooting (or defending) a seat that's already out.
class MovePicker extends StatefulWidget {
  final int myAmmo;
  final bool leftAlive;
  final bool rightAlive;
  final String leftName;
  final String rightName;
  final ValueChanged<Move> onSubmit;

  const MovePicker({
    super.key,
    required this.myAmmo,
    required this.leftAlive,
    required this.rightAlive,
    required this.leftName,
    required this.rightName,
    required this.onSubmit,
  });

  @override
  State<MovePicker> createState() => _MovePickerState();
}

class _MovePickerState extends State<MovePicker> {
  Move _m = Move.empty;

  int get _slots => _m.slotsUsed;
  bool get _free => _slots < kSlots;
  int get _shoots => _m.shootsRequested;

  void _addReload() {
    if (_free) setState(() => _m = _m.copyWith(reload: _m.reload + 1));
  }

  void _toggleDefendLeft() {
    if (_m.defendLeft) {
      setState(() => _m = _m.copyWith(defendLeft: false));
    } else if (_free) {
      setState(() => _m = _m.copyWith(defendLeft: true));
    }
  }

  void _toggleDefendRight() {
    if (_m.defendRight) {
      setState(() => _m = _m.copyWith(defendRight: false));
    } else if (_free) {
      setState(() => _m = _m.copyWith(defendRight: true));
    }
  }

  void _toggleShootLeft() {
    if (_m.shootLeft) {
      setState(() => _m = _m.copyWith(shootLeft: false));
    } else if (_free && _shoots < widget.myAmmo && widget.leftAlive) {
      setState(() => _m = _m.copyWith(shootLeft: true));
    }
  }

  void _toggleShootRight() {
    if (_m.shootRight) {
      setState(() => _m = _m.copyWith(shootRight: false));
    } else if (_free && _shoots < widget.myAmmo && widget.rightAlive) {
      setState(() => _m = _m.copyWith(shootRight: true));
    }
  }

  /// Remove one slot, identified by a tag, when its chip is tapped.
  void _remove(String tag) {
    setState(() {
      switch (tag) {
        case 'reload':
          _m = _m.copyWith(reload: _m.reload - 1);
        case 'dl':
          _m = _m.copyWith(defendLeft: false);
        case 'dr':
          _m = _m.copyWith(defendRight: false);
        case 'sl':
          _m = _m.copyWith(shootLeft: false);
        case 'sr':
          _m = _m.copyWith(shootRight: false);
      }
    });
  }

  List<_Chip> get _chips => [
        for (var i = 0; i < _m.reload; i++)
          const _Chip('reload', ActKind.reload, '장전'),
        if (_m.defendLeft) _Chip('dl', ActKind.defend, '방어 ←${widget.leftName}'),
        if (_m.defendRight)
          _Chip('dr', ActKind.defend, '방어 ${widget.rightName}→'),
        if (_m.shootLeft) _Chip('sl', ActKind.shoot, '빵야 ←${widget.leftName}'),
        if (_m.shootRight) _Chip('sr', ActKind.shoot, '빵야 ${widget.rightName}→'),
      ];

  @override
  Widget build(BuildContext context) {
    final noAmmo = widget.myAmmo <= 0;
    final shootCapped = _shoots >= widget.myAmmo;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Slot tray.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: CD.parchment.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CD.leather.withValues(alpha: 0.25), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < kSlots; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _slotBox(i < _chips.length ? _chips[i] : null),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Option grid.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            _option(
              kind: ActKind.reload,
              label: '장전',
              sub: '+1 총알',
              selected: _m.reload > 0,
              badge: _m.reload > 0 ? '×${_m.reload}' : null,
              enabled: _free,
              onTap: _addReload,
            ),
            _option(
              kind: ActKind.defend,
              label: '방어 ←',
              sub: widget.leftName,
              selected: _m.defendLeft,
              enabled: widget.leftAlive && (_m.defendLeft || _free),
              onTap: _toggleDefendLeft,
            ),
            _option(
              kind: ActKind.defend,
              label: '방어 →',
              sub: widget.rightName,
              selected: _m.defendRight,
              enabled: widget.rightAlive && (_m.defendRight || _free),
              onTap: _toggleDefendRight,
            ),
            _option(
              kind: ActKind.shoot,
              label: '빵야 ←',
              sub: widget.leftName,
              selected: _m.shootLeft,
              enabled: widget.leftAlive &&
                  !noAmmo &&
                  (_m.shootLeft || (_free && !shootCapped)),
              onTap: _toggleShootLeft,
            ),
            _option(
              kind: ActKind.shoot,
              label: '빵야 →',
              sub: widget.rightName,
              selected: _m.shootRight,
              enabled: widget.rightAlive &&
                  !noAmmo &&
                  (_m.shootRight || (_free && !shootCapped)),
              onTap: _toggleShootRight,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          noAmmo
              ? '총알이 없어요 — 먼저 장전!'
              : '내 총알 ${widget.myAmmo}발 · 행동 2개를 골라요',
          style: const TextStyle(color: CD.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _m.isComplete
                ? () {
                    widget.onSubmit(_m);
                    setState(() => _m = Move.empty);
                  }
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: CD.rust,
              disabledBackgroundColor: CD.muted.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.gavel, size: 20),
            label: Text(
              _m.isComplete ? '결정!' : '행동 $_slots/2 선택',
              style: posterTitle(18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _slotBox(_Chip? chip) {
    return GestureDetector(
      onTap: chip == null ? null : () => _remove(chip.tag),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 132,
        height: 46,
        decoration: BoxDecoration(
          color: chip == null
              ? CD.sand.withValues(alpha: 0.5)
              : CD.actionColor(chip.kind).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: chip == null
                ? CD.muted.withValues(alpha: 0.4)
                : CD.actionColor(chip.kind),
            width: chip == null ? 1 : 2,
          ),
        ),
        alignment: Alignment.center,
        child: chip == null
            ? const Icon(Icons.add, color: CD.muted, size: 20)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(actionIcon(chip.kind),
                      size: 18, color: CD.actionColor(chip.kind)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      chip.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: CD.actionColor(chip.kind),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.close, size: 13, color: CD.muted),
                ],
              ),
      ),
    );
  }

  Widget _option({
    required ActKind kind,
    required String label,
    required String sub,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
    String? badge,
  }) {
    final c = CD.actionColor(kind);
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 104,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? c : CD.parchment,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c, width: 2),
            boxShadow: selected
                ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 8)]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(actionIcon(kind),
                      size: 28, color: selected ? Colors.white : c),
                  if (badge != null)
                    Positioned(
                      right: -10,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: CD.leather,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(badge,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: selected ? Colors.white : CD.leather)),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.9)
                          : CD.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip {
  final String tag;
  final ActKind kind;
  final String label;
  const _Chip(this.tag, this.kind, this.label);
}
