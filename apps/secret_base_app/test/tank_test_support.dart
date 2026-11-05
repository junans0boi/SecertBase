import 'dart:math' as math;

import 'package:secret_base_app/core/socket_service.dart';

/// 탱크 대작전 테스트용 상태(서버 viewFor 결과와 같은 모양).
List<int> tankTestTerrain() => [
  for (int x = 0; x < 100; x++)
    (18 + 5 * math.sin(x / 9) + 3 * math.sin(x / 4.3)).round(),
];

int tankTestRow(List<int> terrain, int col) => 40 - terrain[col] - 1;

Map<String, dynamic> tankTestPlayer(
  String id,
  List<int> terrain, {
  required int col,
  String? tankClass,
  int hp = 100,
  int maxHp = 120,
  bool facingRight = true,
  bool shield = false,
  Map<String, dynamic>? ammo,
}) => {
  'id': id,
  'tankClass': tankClass,
  'col': col,
  'row': tankTestRow(terrain, col),
  'hp': hp,
  'maxHp': maxHp,
  'fuel': 20,
  'maxFuel': 30,
  'angle': facingRight ? 45 : 135,
  'power': 60,
  'weapon': 'basic',
  'ammo':
      ammo ??
      {
        'basic': 999,
        'heavy': 2,
        'triple': 2,
        'cluster': 1,
        'teleport': 1,
        if (tankClass == 'rhino') 'quake': 1,
      },
  'facingRight': facingRight,
  'buffs': {'power': false, 'shield': shield},
  'stats': {
    'shots': 4,
    'hits': 3,
    'directHits': 1,
    'damageDealt': 88,
    'maxHit': 41,
    'crates': 1,
  },
};

Map<String, dynamic> tankTestState({
  String phase = 'aiming',
  String theme = 'meadow',
  int turn = 0,
  int myHp = 90,
  int oppHp = 70,
  bool suddenDeath = false,
}) {
  final terrain = tankTestTerrain();
  final select = phase == 'select';
  return {
    'gameId': 'tank-test',
    'phase': phase,
    'turn': turn,
    'turnNumber': 4,
    'theme': theme,
    'gravityMul': theme == 'moon' ? 0.55 : 1.0,
    'windMul': 1.0,
    'terrain': terrain,
    'wind': theme == 'moon' ? 0.0 : 1.2,
    'turnDeadline': DateTime.now().millisecondsSinceEpoch + 20000,
    'timeouts': [0, 1],
    'crates': [
      {'id': 3, 'col': 50, 'row': tankTestRow(terrain, 50), 'item': 'repair'},
    ],
    'suddenDeath': suddenDeath,
    'players': [
      tankTestPlayer(
        'me',
        terrain,
        col: 12,
        tankClass: select ? null : 'rhino',
        hp: myHp,
        maxHp: 130,
        shield: true,
      ),
      tankTestPlayer(
        'opp',
        terrain,
        col: 86,
        tankClass: select ? null : 'falcon',
        hp: oppHp,
        maxHp: 90,
        facingRight: false,
      ),
    ],
    'series': {'me': 1, 'opp': 0},
  };
}

/// 직격 + 낙하가 들어간 발사 결과.
Map<String, dynamic> tankTestShot(
  Map<String, dynamic> state, {
  int damage = 40,
}) {
  final players = state['players'] as List;
  final target = players[1] as Map;
  final path = [
    for (int i = 0; i <= 40; i++)
      {
        'x': 12 + i * ((target['col'] as int) - 12) / 40,
        'y': 20 - 18 * math.sin(math.pi * i / 40),
      },
  ];
  return {
    'shooter': 0,
    'weapon': 'heavy',
    'angle': 50,
    'power': 70,
    'paths': [path],
    'impact': {'col': target['col'], 'row': target['row']},
    'blastR': 6,
    'damage': [0, damage],
    'events': [
      {'type': 'shell', 'path': path, 'stage': 0, 'weapon': 'heavy'},
      {
        'type': 'blast',
        'col': target['col'],
        'row': target['row'],
        'r': 6,
        'changed': [],
        'stage': 0,
      },
      {
        'type': 'damage',
        'target': 1,
        'amount': damage,
        'direct': true,
        'stage': 0,
        'cause': 'blast',
      },
      {'type': 'fall', 'target': 1, 'rows': 2, 'damage': 0},
      {'type': 'heal', 'target': 1, 'amount': 3, 'cause': 'regen'},
    ],
    'turnNumber': 5,
  };
}

void resetTankSocket() {
  final s = SocketService();
  s.tankState = null;
  s.tankLastShot = null;
  s.tankWinner = null;
  s.tankEndReason = null;
  s.tankSummary = null;
  s.tankSeries = {};
  s.restartWaiting = false;
}
