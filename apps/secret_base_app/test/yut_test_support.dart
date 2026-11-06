// 윷놀이 위젯 테스트 공용 서버 상태 모형.
const yutMe = 'ME-CODE';
const yutOpp = 'OPP-CODE';

Map<String, dynamic> yutPiece(
  int id,
  int position, {
  int lastPos = 0,
  bool finished = false,
}) => {
  'id': id,
  'position': position,
  'lastPos': lastPos,
  'finished': finished,
};

Map<String, dynamic> yutMove({
  required int moveIndex,
  required int steps,
  required int pieceId,
  required List<int> pieceIds,
  required int from,
  required int to,
  required List<int> path,
  int? backdoDir,
  bool finish = false,
  int captures = 0,
  int stacks = 0,
}) => {
  'moveIndex': moveIndex,
  'steps': steps,
  'pieceId': pieceId,
  'pieceIds': pieceIds,
  'backdoDir': backdoDir,
  'from': from,
  'to': to,
  'path': path,
  'finish': finish,
  'captures': captures,
  'stacks': stacks,
};

/// 기본: 내 차례, 아직 던지지 않음, 말은 모두 대기.
Map<String, dynamic> yutState({
  String currentTurn = yutMe,
  String phase = 'throwing',
  List<int> pending = const [],
  List<Map<String, dynamic>>? legal,
  List<Map<String, dynamic>>? mine,
  List<Map<String, dynamic>>? theirs,
  int pieceCount = 4,
  int seq = 1,
  bool canThrow = true,
  int stake = 0,
  Map<String, dynamic>? lastAction,
  Map<String, dynamic>? equipped,
  Map<String, dynamic>? effects,
}) {
  List<Map<String, dynamic>> pieces(List<Map<String, dynamic>>? given) =>
      given ?? [for (var i = 0; i < pieceCount; i++) yutPiece(i, 0)];
  return {
    'gameId': 'g1',
    'seq': seq,
    'players': [yutMe, yutOpp],
    'pieceCount': pieceCount,
    'starter': yutMe,
    'phase': phase,
    'currentTurn': currentTurn,
    'pieces': {yutMe: pieces(mine), yutOpp: pieces(theirs)},
    'pendingMoves': pending,
    'canThrow': canThrow,
    'hasBonusThrow': false,
    'captureBonusThrows': 0,
    'lastThrow': null,
    'turnThrows': <Map<String, dynamic>>[],
    'lastAction': lastAction ?? {'type': 'start', 'by': yutMe, 'seq': seq},
    'legalMoves': legal ?? <Map<String, dynamic>>[],
    'characters': {yutMe: 'honggilldong', yutOpp: 'miho'},
    'bgm': 'yut1.mp3',
    'stake': stake,
    'coinBonus': <String, dynamic>{},
    'coinBonusCap': stake * 3 ~/ 10,
    'equippedItems': equipped ?? <String, dynamic>{},
    'effects': effects ?? <String, dynamic>{},
    'series': {
      'wins': {yutMe: 1, yutOpp: 0},
      'draws': 0,
      'games': 1,
    },
    'winner': null,
    'turnDeadline': DateTime.now().millisecondsSinceEpoch + 22000,
    'turnMs': 30000,
    'serverNow': DateTime.now().millisecondsSinceEpoch,
  };
}

Map<String, dynamic> yutThrowAction({
  required int seq,
  required String by,
  required int result,
  required String name,
  required List<int> sticks,
  bool nak = false,
}) => {
  'type': 'throw',
  'by': by,
  'seq': seq,
  'auto': false,
  'throw': {
    'result': result,
    'resultName': name,
    'sticks': sticks,
    'nak': nak,
    'bonus': result == 4 || result == 5,
    'auto': false,
  },
  'itemEffects': <Map<String, dynamic>>[],
};

/// 모형 판: 내 말 4개 중 둘은 바깥길·하나는 업힌 쌍·하나 대기, 상대는 셋이 판 위.
Map<String, dynamic> midGame({
  List<int> pending = const [3, -1],
  bool picked = false,
}) {
  final mine = [
    yutPiece(0, 7, lastPos: 6),
    yutPiece(1, 7, lastPos: 6),
    yutPiece(2, 23, lastPos: 22),
    yutPiece(3, 0),
  ];
  final theirs = [
    yutPiece(0, 3, lastPos: 2),
    yutPiece(1, 12, lastPos: 11),
    yutPiece(2, 0),
    yutPiece(3, 20, lastPos: 20, finished: true),
  ];
  final legal = <Map<String, dynamic>>[
    // 걸(3) 먼저
    yutMove(
      moveIndex: 0,
      steps: 3,
      pieceId: 0,
      pieceIds: [0, 1],
      from: 7,
      to: 10,
      path: [7, 8, 9, 10],
    ),
    yutMove(
      moveIndex: 0,
      steps: 3,
      pieceId: 2,
      pieceIds: [2],
      from: 23,
      to: 20,
      path: [23, 26, 27, 20],
      finish: true,
    ),
    yutMove(
      moveIndex: 0,
      steps: 3,
      pieceId: 3,
      pieceIds: [3],
      from: 0,
      to: 3,
      path: [0, 1, 2, 3],
      captures: 1,
    ),
    // 빽도(-1)
    yutMove(
      moveIndex: 1,
      steps: -1,
      pieceId: 0,
      pieceIds: [0, 1],
      from: 7,
      to: 6,
      path: [7, 6],
    ),
    yutMove(
      moveIndex: 1,
      steps: -1,
      pieceId: 2,
      pieceIds: [2],
      from: 23,
      to: 22,
      path: [23, 22],
      backdoDir: 22,
    ),
    yutMove(
      moveIndex: 1,
      steps: -1,
      pieceId: 2,
      pieceIds: [2],
      from: 23,
      to: 25,
      path: [23, 25],
      backdoDir: 25,
    ),
  ];
  return yutState(
    phase: 'moving',
    pending: pending,
    legal: legal,
    mine: mine,
    theirs: theirs,
    canThrow: false,
    seq: 14,
    lastAction: yutThrowAction(
      seq: 14,
      by: yutMe,
      result: -1,
      name: '빽도',
      sticks: [0, 1, 1, 1],
    ),
  );
}
