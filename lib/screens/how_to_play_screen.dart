import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/desert_background.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('게임 방법', style: posterTitle(22))),
      body: DesertBackground(
        bright: true,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              _Rule(
                icon: Icons.groups,
                color: CD.rust,
                title: '세 명이 원으로',
                body: '세 명이 모이면 시작! 각자 왼쪽 이웃과 오른쪽 이웃이 있어요. '
                    '한 명만 살아남으면 승리합니다.',
              ),
              _Rule(
                icon: Icons.touch_app,
                color: CD.gold,
                title: '매 턴 행동 2개',
                body: '장전 · 방어 · 빵야 중에서 매 턴 두 가지를 골라요. '
                    '같은 걸 두 번 골라도 돼요 (장전+장전 등).',
              ),
              _Rule(
                icon: Icons.cached,
                color: CD.gold,
                title: '장전',
                body: '총알을 한 발 채워요. 빵야는 이전 턴까지 모아둔 총알로만 쏠 수 있어요. '
                    '이번 턴에 장전한 총알은 다음 턴부터 사용! 그래서 첫 턴엔 못 쏴요.',
              ),
              _Rule(
                icon: Icons.local_fire_department,
                color: CD.danger,
                title: '빵야 (방향 공격)',
                body: '왼쪽 이웃 또는 오른쪽 이웃을 지정해 쏴요. '
                    '같은 사람을 한 턴에 두 번은 못 쏴요. 대신 좌·우로 한 발씩 양쪽 동시 공격은 가능!',
              ),
              _Rule(
                icon: Icons.shield,
                color: CD.sage,
                title: '방어 (개수)',
                body: '들어오는 총알을 막아요. 방어는 방향이 아니라 개수! '
                    '방어 1개는 한 발만 막아요(어느 쪽이든) — 양쪽에서 동시에 맞으면 한 발은 통과해 탈락. '
                    '방어 2개는 양쪽에서 맞아도 모두 막아 살아남아요.',
              ),
              _Rule(
                icon: Icons.emoji_events,
                color: CD.leather,
                title: '승리',
                body: '한 발이라도 맞으면 탈락! 마지막까지 살아남은 한 명이 승자. '
                    '서로 동시에 쏴 모두 쓰러지면 무승부예요.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Rule({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CD.parchment.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: posterTitle(18, color: color)),
                const SizedBox(height: 4),
                Text(body,
                    style: const TextStyle(
                        color: CD.ink, fontSize: 13.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
