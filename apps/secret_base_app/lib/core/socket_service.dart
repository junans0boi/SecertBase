import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService extends ChangeNotifier {
  static final SocketService _i = SocketService._internal();
  factory SocketService() => _i;
  SocketService._internal();

  io.Socket? _socket;

  // connection
  bool isConnected = false;
  String status = '대기 중';
  String? userId;
  String? roomCode;
  String? serverUrl;
  List<String> presenceUsers = [];
  int? lastPingMs;

  // simple game results
  int? lastDice;
  String? lastRoulette;
  String? rpsResult;
  Map<String, String>? rpsChoices;
  bool? telepathySuccess;
  String? telepathySelected;
  Map<String, String>? telepathyChoices;
  int? pirateSlot;
  int? pirateSlots;

  // yut
  bool yutActive = false;
  String? yutCurrentTurn;
  String? yutLastThrow;
  String? yutWinner;
  List<Map<String, dynamic>> yutPendingMoves = [];
  Map<String, List<int>> yutPieces = {}; // userId -> piece positions (0-20)

  // uno
  bool unoActive = false;
  String? unoCurrentPlayer;
  String? unoTopCard;
  int? unoP1Count;
  int? unoP2Count;
  List<dynamic> unoHand = [];
  String? unoWinner;

  // bomb
  bool bombActive = false;
  String? bombCurrentPlayer;
  String? bombQuestion;
  String? bombCategory;
  int? bombDuration;
  int? bombStartTime;
  String? bombLoser;
  bool? bombLastAnswerCorrect;
  int bombPassCount = 0;

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  void connect(String url, String room, String secret, String user) {
    _socket?.dispose();
    _socket = null;
    isConnected = false;
    status = '연결 중...';
    serverUrl = url;
    roomCode = room;
    userId = user;
    _log('연결 시도: $url');
    notifyListeners();

    final socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      _log('소켓 연결됨');
      socket.emitWithAck(
        'session:join',
        {'userId': user, 'roomCode': room, 'roomSecret': secret},
        ack: (r) {
          final map = _m(r);
          if (map['ok'] == true) {
            isConnected = true;
            status = '입장 완료';
            _log('방 입장 완료');
            notifyListeners();
            socket.emitWithAck('session:restore', {}, ack: (r2) {
              final rm = _m(r2);
              if (rm['ok'] == true) {
                _restoreGames(_m(rm['activeGames'] ?? {}));
              }
            });
          } else {
            status = '입장 실패: ${map['reason'] ?? 'unknown'}';
            isConnected = false;
            _log('입장 실패: ${map['reason']}');
            notifyListeners();
          }
        },
      );
    });

    socket.onConnectError((e) {
      status = '연결 실패';
      isConnected = false;
      _log('연결 오류: $e');
      notifyListeners();
    });

    socket.onDisconnect((_) {
      isConnected = false;
      status = '연결 끊김';
      _log('연결 해제');
      notifyListeners();
    });

    socket.on('room:presence', (data) {
      final users = _m(data)['users'];
      if (users is List) {
        presenceUsers = users.map((e) => '$e').toList();
        _log('접속자: ${presenceUsers.join(', ')}');
        notifyListeners();
      }
    });

    socket.on('game:dice:result', (data) {
      lastDice = _m(data)['value'] as int?;
      _log('주사위: $lastDice');
      notifyListeners();
    });

    socket.on('game:roulette:result', (data) {
      lastRoulette = _m(data)['selected'] as String?;
      _log('룰렛: $lastRoulette');
      notifyListeners();
    });

    socket.on('game:rps:result', (data) {
      final map = _m(data);
      final winner = map['winner'] as String?;
      final choices = map['choices'];
      if (choices is Map) {
        rpsChoices = choices.map((k, v) => MapEntry('$k', '$v'));
      }
      if (winner == 'draw') {
        rpsResult = 'draw';
      } else {
        rpsResult = winner == userId ? 'win' : 'lose';
      }
      _log('가위바위보: $rpsResult');
      notifyListeners();
    });

    socket.on('game:telepathy:result', (data) {
      final map = _m(data);
      telepathySuccess = map['success'] == true;
      telepathySelected = map['selected'] as String?;
      final choices = map['choices'];
      if (choices is Map) {
        telepathyChoices = choices.map((k, v) => MapEntry('$k', '$v'));
      }
      _log('텔레파시: ${telepathySuccess! ? "성공" : "실패"}');
      notifyListeners();
    });

    socket.on('game:pirate:result', (data) {
      final map = _m(data);
      pirateSlot = map['bombSlot'] as int?;
      pirateSlots = map['slots'] as int?;
      _log('해적룰렛 폭탄: $pirateSlot/$pirateSlots');
      notifyListeners();
    });

    // yut events
    socket.on('game:yut:started', (data) {
      final map = _m(data);
      yutActive = true;
      yutCurrentTurn = map['currentTurn'] as String?;
      yutLastThrow = null;
      yutWinner = null;
      yutPendingMoves = [];
      // initialize pieces for all players (4 pieces each at position 0)
      final players = map['players'];
      if (players is List) {
        yutPieces = { for (final p in players) '$p': [0, 0, 0, 0] };
      }
      _log('윷놀이 시작 - 턴: $yutCurrentTurn');
      notifyListeners();
    });

    socket.on('game:yut:throw_result', (data) {
      final map = _m(data);
      final throwResult = _m(map['throwResult'] ?? {});
      yutLastThrow = throwResult['resultName'] as String?;
      yutCurrentTurn = map['currentTurn'] as String?;
      final pending = map['pendingMoves'];
      if (pending is List) {
        yutPendingMoves = pending.map((e) => {'steps': e}).toList();
      }
      _log('윷 결과: $yutLastThrow - 다음 턴: $yutCurrentTurn');
      notifyListeners();
    });

    socket.on('game:yut:move_result', (data) {
      final map = _m(data);
      final by = map['by'] as String?;
      final pieceId = map['pieceId'];
      final newPos = map['newPosition'];
      if (by != null && pieceId is int && newPos is int) {
        final pieces = yutPieces[by] ?? [0, 0, 0, 0];
        pieces[pieceId] = newPos;
        yutPieces = Map.from(yutPieces)..[by] = pieces;
      }
      if (yutPendingMoves.isNotEmpty) {
        yutPendingMoves = yutPendingMoves.sublist(1);
      }
      if (map['winner'] != null) {
        yutWinner = map['winner'] as String?;
        yutActive = false;
      }
      notifyListeners();
    });

    socket.on('game:yut:ended', (data) {
      yutWinner = _m(data)['winner'] as String?;
      yutActive = false;
      _log('윷놀이 종료 - 승리: $yutWinner');
      notifyListeners();
    });

    // uno events
    socket.on('game:uno:started', (data) {
      final map = _m(data);
      unoActive = true;
      unoCurrentPlayer = map['currentPlayer'] as String?;
      final topCardRaw = map['topCard'];
      unoTopCard = topCardRaw is Map ? '${topCardRaw['color']} ${topCardRaw['value']}' : topCardRaw?.toString();
      final handCount = _m(map['handCount'] ?? {});
      unoP1Count = (handCount[userId] ?? handCount.values.firstOrNull) as int?;
      final opponentCounts = handCount.entries.where((e) => e.key != userId);
      unoP2Count = opponentCounts.isNotEmpty ? opponentCounts.first.value as int? : null;
      unoHand = [];
      unoWinner = null;
      _log('UNO 시작 - 첫 턴: $unoCurrentPlayer');
      notifyListeners();
    });

    socket.on('game:uno:hand_update', (data) {
      final map = _m(data);
      final hand = map['hand'];
      if (hand is List) {
        unoHand = hand;
        unoP1Count = unoHand.length;
        _log('UNO 손패 업데이트: ${unoHand.length}장');
        notifyListeners();
      }
    });

    socket.on('game:uno:played', (data) {
      final map = _m(data);
      unoCurrentPlayer = map['nextPlayer'] as String?;
      final card = _m(map['card'] ?? {});
      unoTopCard = '${card['color']} ${card['value']}';
      notifyListeners();
    });

    socket.on('game:uno:drawn', (data) {
      final map = _m(data);
      unoCurrentPlayer = map['nextPlayer'] as String?;
      _log('카드 뽑기 - 다음 턴: $unoCurrentPlayer');
      notifyListeners();
    });

    socket.on('game:uno:ended', (data) {
      unoWinner = _m(data)['winner'] as String?;
      unoActive = false;
      _log('UNO 종료 - 승리: $unoWinner');
      notifyListeners();
    });

    // bomb events
    socket.on('game:bomb:started', (data) {
      final map = _m(data);
      bombActive = true;
      bombCurrentPlayer = map['currentPlayer'] as String?;
      bombDuration = map['duration'] as int?;
      bombStartTime = map['startTime'] as int?;
      bombPassCount = 0;
      bombLoser = null;
      final quiz = _m(map['quiz'] ?? {});
      bombQuestion = quiz['question'] as String?;
      bombCategory = quiz['category'] as String?;
      _log('폭탄 시작 - 첫 홀더: $bombCurrentPlayer');
      notifyListeners();
    });

    socket.on('game:bomb:passed', (data) {
      final map = _m(data);
      bombCurrentPlayer = map['to'] as String?;
      bombPassCount = (map['passCount'] as int?) ?? bombPassCount + 1;
      final quiz = _m(map['quiz'] ?? {});
      bombQuestion = quiz['question'] as String?;
      bombCategory = quiz['category'] as String?;
      bombLastAnswerCorrect = true;
      _log('폭탄 패스 → $bombCurrentPlayer');
      notifyListeners();
    });

    socket.on('game:bomb:wrong_answer', (data) {
      bombLastAnswerCorrect = false;
      _log('오답!');
      notifyListeners();
    });

    socket.on('game:bomb:exploded', (data) {
      bombLoser = _m(data)['loser'] as String?;
      bombActive = false;
      _log('폭발! 패배: $bombLoser');
      notifyListeners();
    });

    socket.connect();
    _socket = socket;
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    isConnected = false;
    status = '대기 중';
    userId = null;
    roomCode = null;
    presenceUsers = [];
    yutActive = false;
    unoActive = false;
    bombActive = false;
    _logs.clear();
    notifyListeners();
  }

  void ping() {
    final t = DateTime.now().millisecondsSinceEpoch;
    _socket?.emitWithAck('sync:ping', {'clientTs': t}, ack: (r) {
      if (_m(r)['ok'] == true) {
        lastPingMs = DateTime.now().millisecondsSinceEpoch - t;
        notifyListeners();
      }
    });
  }

  void rollDice() => _socket?.emit('game:dice:roll');

  void spinRoulette(List<String> options) =>
      _socket?.emit('game:roulette:spin', {'options': options});

  void playRps(String choice) {
    rpsResult = null;
    rpsChoices = null;
    notifyListeners();
    _socket?.emit('game:rps:select', {'choice': choice});
  }

  void playTelepathy(String choice, List<String> options) {
    telepathySuccess = null;
    telepathySelected = null;
    telepathyChoices = null;
    notifyListeners();
    _socket?.emit('game:telepathy:select', {'choice': choice, 'options': options});
  }

  void spinPirate(int slots) {
    pirateSlot = null;
    notifyListeners();
    _socket?.emit('game:pirate:spin', {'slots': slots});
  }

  void newYutGame() => _socket?.emit('game:yut:new');
  void throwYut() => _socket?.emit('game:yut:throw');
  void moveYut(int pieceId) => _socket?.emit('game:yut:move', {'pieceId': pieceId});

  void newUnoGame() => _socket?.emit('game:uno:new');
  void playUnoCard(String cardId, {String? color}) => _socket?.emit('game:uno:play', {
        'cardId': cardId,
        if (color != null) 'declaredColor': color,
      });
  void drawUnoCard() => _socket?.emit('game:uno:draw');

  void newBombGame({int duration = 30}) =>
      _socket?.emit('game:bomb:new', {'duration': duration});
  void answerBomb(String answer) {
    bombLastAnswerCorrect = null;
    notifyListeners();
    _socket?.emit('game:bomb:answer', {'answer': answer});
  }

  void _restoreGames(Map<String, dynamic> games) {
    if (games.containsKey('yut')) {
      final yut = _m(games['yut']);
      yutActive = true;
      yutCurrentTurn = yut['turn'] as String?;
      yutPieces = {};
      yutPendingMoves = [];
      _log('윷놀이 복원');
    }
    if (games.containsKey('uno')) {
      final uno = _m(games['uno']);
      unoActive = true;
      unoCurrentPlayer = uno['turn'] as String?;
      unoTopCard = uno['topCard']?.toString();
      unoHand = [];
      _log('UNO 복원');
    }
    if (games.containsKey('bomb')) {
      final bomb = _m(games['bomb']);
      bombActive = true;
      bombCurrentPlayer = bomb['holder'] as String?;
      bombDuration = bomb['timer'] as int?;
      _log('폭탄 복원');
    }
    notifyListeners();
  }

  void _log(String msg) {
    _logs.insert(0, msg);
    if (_logs.length > 100) _logs.removeLast();
    log('[SocketService] $msg');
  }

  static Map<String, dynamic> _m(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry('$k', val));
    return {};
  }
}
