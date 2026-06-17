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
  String? yutGameId;
  String? yutPhase;
  String? yutCurrentTurn;
  String? yutLastThrow;
  String? yutWinner;
  List<dynamic> yutPendingMoves = [];
  Map<String, dynamic> yutStartRolls = {};
  List<String> yutPlayers = [];
  Map<String, List<int>> yutPieces = {}; // userId -> piece positions (0-20)
  Map<String, List<dynamic>> yutPieceDetails = {};

  // uno
  bool unoActive = false;
  String? unoCurrentPlayer;
  String? unoTopCard;
  Map<String, dynamic>? unoTopCardMap;
  String? unoDeclaredColor;
  int? unoP1Count;
  int? unoP2Count;
  List<String> unoPlayers = [];
  List<dynamic> unoHand = [];
  String? unoWinner;
  bool unoPendingCall = false;  // I played to 1 card, need to press UNO
  bool unoCatchable = false;    // Opponent has 1 card and hasn't called UNO

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
            socket.emitWithAck(
              'session:restore',
              {},
              ack: (r2) {
                final rm = _m(r2);
                if (rm['ok'] == true) {
                  _restoreGames(_m(rm['activeGames'] ?? {}));
                }
              },
            );
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
      _applyYutState(_m(data));
      yutWinner = null;
      _log('윷놀이 시작 - 턴: $yutCurrentTurn');
      notifyListeners();
    });

    socket.on('game:yut:start_roll', (data) {
      _applyYutState(_m(data));
      _log('윷 선공 주사위');
      notifyListeners();
    });

    socket.on('game:yut:throw_result', (data) {
      final map = _m(data);
      final throwResult = _m(map['throwResult'] ?? {});
      _applyYutState(map);
      yutLastThrow = throwResult['resultName'] as String?;
      _log('윷 결과: $yutLastThrow - 다음 턴: $yutCurrentTurn');
      notifyListeners();
    });

    socket.on('game:yut:move_result', (data) {
      final map = _m(data);
      _applyYutState(map);
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
      unoTopCardMap = _cardMap(topCardRaw);
      unoTopCard = unoTopCardMap == null
          ? topCardRaw?.toString()
          : '${unoTopCardMap!['color']} ${unoTopCardMap!['value']}';
      unoDeclaredColor = map['declaredColor'] as String?;
      _applyUnoCounts(map['handCount']);
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
        _applyUnoCounts(null);
        _log('UNO 손패 업데이트: ${unoHand.length}장');
        notifyListeners();
      }
    });

    socket.on('game:uno:played', (data) {
      final map = _m(data);
      unoCurrentPlayer = map['nextPlayer'] as String?;
      final card = _m(map['card'] ?? {});
      unoTopCardMap = card;
      unoTopCard = '${card['color']} ${card['value']}';
      unoDeclaredColor = map['declaredColor'] as String?;
      _applyUnoCounts(map['handCount']);
      _applyUnoCallNeeded(map['unoCallNeeded']);
      notifyListeners();
    });

    socket.on('game:uno:drawn', (data) {
      final map = _m(data);
      unoCurrentPlayer = map['nextPlayer'] as String?;
      unoDeclaredColor = map['declaredColor'] as String? ?? unoDeclaredColor;
      _applyUnoCounts(map['handCount']);
      _applyUnoCallNeeded(map['unoCallNeeded']);
      _log('카드 뽑기 - 다음 턴: $unoCurrentPlayer');
      notifyListeners();
    });

    socket.on('game:uno:called', (data) {
      unoPendingCall = false;
      unoCatchable = false;
      _log('UNO 선언: ${_m(data)['by']}');
      notifyListeners();
    });

    socket.on('game:uno:penalty', (data) {
      final map = _m(data);
      unoPendingCall = false;
      unoCatchable = false;
      _applyUnoCounts(map['handCount']);
      _log('UNO 페널티: ${map['target']} +${map['count']}장');
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
    unoPendingCall = false;
    unoCatchable = false;
    bombActive = false;
    _logs.clear();
    notifyListeners();
  }

  void ping() {
    final t = DateTime.now().millisecondsSinceEpoch;
    _socket?.emitWithAck(
      'sync:ping',
      {'clientTs': t},
      ack: (r) {
        if (_m(r)['ok'] == true) {
          lastPingMs = DateTime.now().millisecondsSinceEpoch - t;
          notifyListeners();
        }
      },
    );
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
    _socket?.emit('game:telepathy:select', {
      'choice': choice,
      'options': options,
    });
  }

  void spinPirate(int slots) {
    pirateSlot = null;
    notifyListeners();
    _socket?.emit('game:pirate:spin', {'slots': slots});
  }

  void newYutGame() => _socket?.emit('game:yut:new');
  void rollYutStartDice() => _socket?.emit('game:yut:roll_start');
  void throwYut() => _socket?.emit('game:yut:throw');
  void moveYut(int pieceId) =>
      _socket?.emit('game:yut:move', {'pieceId': pieceId});

  void newUnoGame() => _socket?.emit('game:uno:new');
  void playUnoCard(String cardId, {String? color}) {
    final payload = {'cardId': cardId};
    if (color != null) {
      payload['declaredColor'] = color;
    }
    _socket?.emit('game:uno:play', payload);
  }

  void drawUnoCard() => _socket?.emit('game:uno:draw');
  void callUno() => _socket?.emit('game:uno:call');
  void catchUno() => _socket?.emit('game:uno:catch');

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
      _applyYutState(yut);
      _log('윷놀이 복원');
    }
    if (games.containsKey('uno')) {
      final uno = _m(games['uno']);
      unoActive = true;
      unoCurrentPlayer = uno['turn'] as String?;
      unoTopCardMap = _cardMap(uno['topCard']);
      unoTopCard = unoTopCardMap?.toString() ?? uno['topCard']?.toString();
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

  void _applyYutState(Map<String, dynamic> map) {
    yutActive = true;
    yutGameId = map['id'] as String? ?? yutGameId ?? 'active';
    yutPhase = map['phase'] as String? ?? yutPhase ?? 'throwing';
    yutCurrentTurn = map['currentTurn'] as String?;
    yutStartRolls = _m(map['startRolls'] ?? yutStartRolls);
    final pending = map['pendingMoves'];
    yutPendingMoves = pending is List ? List<dynamic>.from(pending) : [];
    final lastThrow = _m(map['lastThrow']);
    if (lastThrow.isNotEmpty) {
      yutLastThrow = lastThrow['resultName'] as String?;
    }
    final playersRaw = map['players'];
    if (playersRaw is List) {
      yutPlayers = playersRaw.map((e) => '$e').toList();
    }
    final piecesRaw = _m(map['pieces']);
    if (piecesRaw.isNotEmpty) {
      yutPieceDetails = piecesRaw.map(
        (player, value) => MapEntry(player, value is List ? value : []),
      );
      yutPieces = yutPieceDetails.map(
        (player, pieces) => MapEntry(
          player,
          pieces.map((piece) {
            if (piece is Map) return (piece['position'] as int?) ?? 0;
            if (piece is int) return piece;
            return 0;
          }).toList(),
        ),
      );
    }
  }

  void _applyUnoCounts(dynamic rawHandCount) {
    final handCount = _m(rawHandCount);
    if (handCount.isNotEmpty) {
      unoPlayers = handCount.keys.toList();
      final me = userId;
      if (me != null && handCount[me] is int) {
        unoP1Count = handCount[me] as int;
      }
      final opponent = handCount.entries.where((entry) => entry.key != me);
      if (opponent.isNotEmpty && opponent.first.value is int) {
        unoP2Count = opponent.first.value as int;
      }
      return;
    }

    unoP1Count = unoHand.length;
  }

  void _applyUnoCallNeeded(dynamic raw) {
    final needed = raw as String?;
    unoPendingCall = needed != null && needed == userId;
    unoCatchable = needed != null && needed != userId;
  }

  Map<String, dynamic>? _cardMap(dynamic value) {
    final map = _m(value);
    return map.isEmpty ? null : map;
  }

  static Map<String, dynamic> _m(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry('$k', val));
    return {};
  }
}
