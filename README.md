# 3인 카우보이 (Cowboy Trio) 🤠🤠🤠

세 명이 원을 그려 앉아 **장전 · 방어 · 빵야**로 최후의 1인을 가리는 서부극 눈치 게임.
[카우보이 듀얼](https://github.com/doonghwi/cowboy-duel)의 3인용 분기 — 완전히 새로 만든 앱입니다.

**▶ 웹에서 바로 플레이: https://doonghwi.github.io/cowboy-trio/**

## 게임 규칙
- **세 명**이 모이면 시작. 각자 왼쪽·오른쪽 이웃이 있는 원형 배치.
- 매 턴 **행동 2개**를 고른다 (장전/방어/빵야, 중복 가능).
- **빵야는 방향 공격**: 좌 이웃 또는 우 이웃을 지정. 같은 사람을 한 턴에 두 번은 못 쏘지만, 좌·우로 한 발씩 양쪽 동시 공격은 가능.
- **방어도 좌/우 방향**: 들어오는 총알은 같은 방향 방어로만 막는다. 양쪽 방어로 두 방향 모두 차단 가능.
- 빵야는 **이전 턴까지 모아둔 총알**로만 가능. 이번 턴 장전은 다음 턴부터 사용 → 첫 턴엔 발사 불가.
- 한 발이라도 맞으면 **탈락**. 마지막 1인이 **승리**. 같은 턴에 모두 쓰러지면 **무승부**.

## 모드
- **컴퓨터와 대결** — 나 + 컴퓨터 2명 (오프라인).
- **온라인 3인전** — 방 코드로 3명이 모여 실시간 대전 (Firebase Realtime Database).

## 스택
- **Flutter** (Android + Web). iOS는 추후 macOS에서.
- **Firebase Realtime Database** — 무브로그 기반 결정적 리플레이로 모든 클라이언트가 동일한 판정을 재현.
- 이모지는 Twemoji 이미지 + 폰트 내장으로 웹 깜빡임 방지.

## 빌드
```bash
flutter pub get
flutter test                              # 순수 게임 로직 단위 테스트
flutter build apk --release               # 안드로이드
flutter build web --pwa-strategy=none     # 웹 (서비스워커 OFF)
```

## 구조
- `lib/game/trio_logic.dart` — UI 독립 순수 규칙 (`resolveTurn`).
- `lib/game/cpu_ai.dart` — 오프라인 컴퓨터 상대.
- `lib/online/online_service.dart` — 3인 방 + 결정적 리플레이.
- `lib/widgets/move_picker.dart` — 2행동 선택 UI (규칙 강제).
- `lib/screens/` — 홈 · 오프라인 · 온라인 로비/게임 · 게임방법.
