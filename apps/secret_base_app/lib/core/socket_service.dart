import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'auth_service.dart';

class SocketService extends ChangeNotifier {
  static final SocketService _i = SocketService._internal();
  factory SocketService() => _i;
  SocketService._internal() {
    _loadProfileEmoji();
  }

  static const defaultProfileEmoji = '🙂';
  static const profileEmojiOptions = [
    '🙂',
    '😊',
    '🐻',
    '🐰',
    '🐶',
    '🐱',
    '🍀',
    '⭐',
  ];
  static const _profileEmojiKey = 'secret_base_profile_emoji';
  static const yutCharacterIds = ['honggilldong', 'nolbu', 'miho'];
  static const yutCharacterNames = {
    'honggilldong': '홍길동',
    'nolbu': '놀부',
    'miho': '미호',
  };

  io.Socket? _socket;

  // connection
  bool isConnected = false;
  String status = '대기 중';
  String? userId;
  String? roomCode;
  String? serverUrl;
  List<String> presenceUsers = [];
  Map<String, String> profileEmojis = {};
  Map<String, String> presenceNicknames = {};
  String profileEmoji = defaultProfileEmoji;
  int? lastPingMs;

  // game lobby
  String? lobbyGameType;
  String? lobbyHost;
  List<String> lobbyPlayers = [];
  String? lobbyStartedGameType;
  Map<String, String> lobbyCharacterSelections = {};
  Map<String, String> lobbyStartedYutCharacters = {};
  String? lobbyStartedYutBgm;

  // simple game results
  int? lastDice;
  String? lastRoulette;
  String? rpsResult;
  Map<String, String>? rpsChoices;
  bool? telepathySuccess;
  String? telepathySelected;
  Map<String, String>? telepathyChoices;

  // RPS multi-mode
  String? rpsMode; // 'rps3' | 'mukjippa' | 'hanabagi'
  bool rpsActive = false;
  List<String> rpsPlayers = [];
  Map<String, int> rpsScores = {};
  int rpsRound = 0;
  String? rpsMukjippaPhase; // 'determine' | 'play'
  String? rpsMukjippaAttacker;
  // last round result
  Map<String, String>? rpsLastChoices;
  Map<String, int>? rpsLastFingers;
  Map<String, int>? rpsLastGuesses;
  int? rpsLastTotal;
  String? rpsRoundWinner;
  String? rpsGameWinner;
  List<Map<String, dynamic>> rpsRoundHistory = [];

  // pirate roulette (turn-based)
  bool pirateActive = false;
  int pirateTotalSlots = 8;
  String? pirateCurrentTurn;
  List<int> piratePickedSlots = [];
  String? pirateLoser;
  int? pirateBombSlot;
  List<String> piratePlayers = [];

  // yut
  bool yutActive = false;
  String? yutGameId;
  String? yutPhase;
  String? yutCurrentTurn;
  String? yutLastThrow;
  bool yutLastNak = false;
  String? yutWinner;
  Map<String, String> yutCharacters = {};
  String? yutBgm;
  String? yutLastThrowBy;
  int? yutLastThrowAt;
  String? yutLastMoveBy;
  int? yutLastMoveAt;
  int yutLastCapturedCount = 0;
  int yutLastCarriedCount = 0;
  int yutLastStackedCount = 0;
  int? yutOrderCountdownUntil;
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
  String unoMode = 'go_wild';
  String selectedUnoMode = 'go_wild';
  int? unoP1Count;
  int? unoP2Count;
  List<String> unoPlayers = [];
  List<dynamic> unoHand = [];
  String? unoWinner;
  bool unoPendingCall = false; // I played to 1 card, need to press UNO
  bool unoCatchable = false; // Opponent has 1 card and hasn't called UNO
  // draw stack chaining
  int unoDrawStack = 0;
  String? unoDrawStackType; // 'draw2' | 'wild_draw4' | null
  // special card effect tracking (for opponent's plays)
  String? unoLastSpecialCard;
  String? unoLastSpecialBy;
  int? unoLastSpecialAt;
  String? unoReactionType;
  String? unoReactionBy;
  int? unoReactionAt;

  // heart
  bool heartReceived = false;
  String heartSenderEmoji = '💓';

  // menu / reconnect state
  bool restartPending = false; // received opponent's restart request
  bool restartWaiting = false; // sent my restart request, awaiting response
  bool opponentOnline = false;
  bool opponentJustLeft =
      false; // true once when opponent leaves during active game

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

  // catch mind (그림퀴즈)
  bool catchActive = false;
  String? catchDrawer;
  String? catchWord; // 내가 출제자일 때만 set
  int catchWordLen = 0;
  int catchRound = 0;
  int catchMaxRounds = 6;
  Map<String, int> catchScores = {};
  String? catchPhase; // 'drawing' | 'guessed' | 'timeout' | 'gameover'
  String? catchGameWinner;
  String? catchHint;
  List<Map<String, dynamic>> catchGuessLog = [];
  // 드로잉 데이터는 콜백으로 직접 처리 (ChangeNotifier 우회 → 성능)
  Function(Map<String, dynamic>)? _onCatchDraw;
  VoidCallback? _onCatchClear;

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
        {
          'userId': user,
          'roomCode': room,
          'roomSecret': secret,
          'profileEmoji': profileEmoji,
          'nickname': _currentNickname(),
        },
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
      final map = _m(data);
      final users = map['users'];
      if (users is List) {
        final prevOnline = opponentOnline;
        presenceUsers = users.map((e) => '$e').toList();
        profileEmojis = _stringMap(map['profileEmojis']);
        presenceNicknames = _stringMap(map['displayNames']);
        if (presenceNicknames.isEmpty) {
          presenceNicknames = _stringMap(map['nicknames']);
        }
        opponentOnline = presenceUsers.length == 2;
        if (prevOnline &&
            !opponentOnline &&
            (yutActive || unoActive || bombActive)) {
          opponentJustLeft = true;
        }
        if (!prevOnline && opponentOnline) {
          opponentJustLeft = false;
        }
        _log('접속자: ${presenceUsers.join(', ')}');
        notifyListeners();
      }
    });

    socket.on('game:lobby:updated', (data) {
      final map = _m(data);
      final gameType = map['gameType'] as String?;
      if (lobbyGameType != null && gameType != lobbyGameType) return;
      lobbyGameType = gameType ?? lobbyGameType;
      lobbyHost = map['host'] as String?;
      final players = map['players'];
      lobbyPlayers = players is List ? players.map((e) => '$e').toList() : [];
      lobbyCharacterSelections = _stringMap(map['characterSelections']);
      final emojis = _stringMap(map['profileEmojis']);
      if (emojis.isNotEmpty) profileEmojis = emojis;
      final nicks = _stringMap(map['nicknames']);
      if (nicks.isNotEmpty) {
        presenceNicknames = {...presenceNicknames, ...nicks};
      }
      _log('대기방 업데이트: $lobbyGameType / ${lobbyPlayers.join(', ')}');
      notifyListeners();
    });

    socket.on('game:lobby:started', (data) {
      final map = _m(data);
      lobbyStartedGameType = map['gameType'] as String?;
      final players = map['players'];
      lobbyPlayers = players is List ? players.map((e) => '$e').toList() : [];
      lobbyHost = map['host'] as String? ?? lobbyHost;
      final metadata = _m(map['metadata']);
      lobbyStartedYutBgm = metadata['yutBgm'] as String?;
      lobbyStartedYutCharacters = _stringMap(metadata['yutCharacters']);
      final emojis = _stringMap(map['profileEmojis']);
      if (emojis.isNotEmpty) profileEmojis = emojis;
      final nicks = _stringMap(map['nicknames']);
      if (nicks.isNotEmpty) {
        presenceNicknames = {...presenceNicknames, ...nicks};
      }
      _log('대기방 게임 시작: $lobbyStartedGameType');
      notifyListeners();
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

    socket.on('game:rps:started', (data) {
      final map = _m(data);
      rpsMode = map['mode'] as String?;
      rpsActive = true;
      rpsPlayers = (map['players'] as List?)?.map((e) => '$e').toList() ?? [];
      final sc = map['scores'];
      rpsScores = sc is Map
          ? sc.map((k, v) => MapEntry('$k', (v as num).toInt()))
          : {};
      rpsRound = 1;
      rpsMukjippaPhase = map['phase'] as String? ?? 'play';
      rpsMukjippaAttacker = null;
      rpsLastChoices = null;
      rpsLastFingers = null;
      rpsLastGuesses = null;
      rpsLastTotal = null;
      rpsRoundWinner = null;
      rpsGameWinner = null;
      rpsRoundHistory = [];
      notifyListeners();
    });

    socket.on('game:rps:round_result', (data) {
      final map = _m(data);
      final mode = map['mode'] as String?;
      rpsRoundWinner = map['roundWinner'] as String?;
      rpsGameWinner = map['gameWinner'] as String?;

      if (mode == 'rps3') {
        final choices = map['choices'];
        if (choices is Map) {
          rpsLastChoices = choices.map((k, v) => MapEntry('$k', '$v'));
        }
        final sc = map['scores'];
        if (sc is Map) {
          rpsScores = sc.map((k, v) => MapEntry('$k', (v as num).toInt()));
        }
        rpsRound = (map['round'] as num?)?.toInt() ?? rpsRound;
      } else if (mode == 'mukjippa') {
        final choices = map['choices'];
        if (choices is Map) {
          rpsLastChoices = choices.map((k, v) => MapEntry('$k', '$v'));
        }
        rpsMukjippaPhase = map['phase'] as String?;
        rpsMukjippaAttacker = map['attacker'] as String?;
      } else if (mode == 'hanabagi') {
        final fingers = map['fingers'];
        if (fingers is Map) {
          rpsLastFingers = fingers.map(
            (k, v) => MapEntry('$k', (v as num).toInt()),
          );
        }
        final guesses = map['guesses'];
        if (guesses is Map) {
          rpsLastGuesses = guesses.map(
            (k, v) => MapEntry('$k', (v as num).toInt()),
          );
        }
        rpsLastTotal = (map['total'] as num?)?.toInt();
        final sc = map['scores'];
        if (sc is Map) {
          rpsScores = sc.map((k, v) => MapEntry('$k', (v as num).toInt()));
        }
        final history = map['history'];
        if (history is List) {
          rpsRoundHistory = history
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        rpsRound = (map['round'] as num?)?.toInt() ?? rpsRound;
      }

      if (rpsGameWinner != null) rpsActive = false;
      notifyListeners();
    });

    socket.on('game:rps:reset_done', (_) {
      rpsMode = null;
      rpsActive = false;
      rpsPlayers = [];
      rpsScores = {};
      rpsRound = 0;
      rpsMukjippaPhase = null;
      rpsMukjippaAttacker = null;
      rpsLastChoices = null;
      rpsLastFingers = null;
      rpsLastGuesses = null;
      rpsLastTotal = null;
      rpsRoundWinner = null;
      rpsGameWinner = null;
      rpsRoundHistory = [];
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

    socket.on('game:pirate:started', (data) {
      final map = _m(data);
      pirateActive = true;
      pirateTotalSlots = (map['slots'] as num?)?.toInt() ?? 8;
      pirateCurrentTurn = map['currentTurn'] as String?;
      piratePickedSlots = [];
      pirateLoser = null;
      pirateBombSlot = null;
      final players = map['players'];
      piratePlayers = players is List ? players.map((e) => '$e').toList() : [];
      _log('해적룰렛 시작: $pirateTotalSlots개');
      notifyListeners();
    });

    socket.on('game:pirate:slot_picked', (data) {
      final map = _m(data);
      final slot = (map['slot'] as num?)?.toInt();
      if (slot != null) piratePickedSlots = [...piratePickedSlots, slot];
      pirateCurrentTurn = map['nextTurn'] as String?;
      _log('해적룰렛 선택: $slot → 다음 $pirateCurrentTurn');
      notifyListeners();
    });

    socket.on('game:pirate:exploded', (data) {
      final map = _m(data);
      pirateLoser = map['loser'] as String?;
      pirateBombSlot = (map['bombSlot'] as num?)?.toInt();
      pirateActive = false;
      _log('해적룰렛 폭발! 패배: $pirateLoser');
      notifyListeners();
    });

    socket.on('game:pirate:reset_done', (data) {
      pirateActive = false;
      pirateCurrentTurn = null;
      piratePickedSlots = [];
      pirateLoser = null;
      pirateBombSlot = null;
      piratePlayers = [];
      _log('해적룰렛 리셋');
      notifyListeners();
    });

    // yut events
    socket.on('game:yut:started', (data) {
      _applyYutState(_m(data));
      yutWinner = null;
      restartWaiting = false;
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
      yutLastNak = throwResult['nak'] == true;
      yutLastThrowBy = map['by'] as String?;
      yutLastThrowAt =
          (map['at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
      _log('윷 결과: $yutLastThrow - 다음 턴: $yutCurrentTurn');
      notifyListeners();
    });

    socket.on('game:yut:move_result', (data) {
      final map = _m(data);
      _applyYutState(map);
      yutLastMoveBy = map['by'] as String?;
      yutLastMoveAt =
          (map['at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
      yutLastCapturedCount = (map['capturedCount'] as num?)?.toInt() ?? 0;
      yutLastCarriedCount = (map['carriedCount'] as num?)?.toInt() ?? 0;
      yutLastStackedCount = (map['stackedCount'] as num?)?.toInt() ?? 0;
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
      restartWaiting = false;
      unoCurrentPlayer = map['currentPlayer'] as String?;
      unoMode = map['mode'] as String? ?? 'go_wild';
      selectedUnoMode = unoMode;
      final topCardRaw = map['topCard'];
      unoTopCardMap = _cardMap(topCardRaw);
      unoTopCard = unoTopCardMap == null
          ? topCardRaw?.toString()
          : '${unoTopCardMap!['color']} ${unoTopCardMap!['value']}';
      unoDeclaredColor = map['declaredColor'] as String?;
      unoDrawStack = 0;
      unoDrawStackType = null;
      unoLastSpecialCard = null;
      unoLastSpecialBy = null;
      unoLastSpecialAt = null;
      unoReactionType = null;
      unoReactionBy = null;
      unoReactionAt = null;
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
      unoMode = map['mode'] as String? ?? unoMode;
      final card = _m(map['card'] ?? {});
      unoTopCardMap = card;
      unoTopCard = '${card['color']} ${card['value']}';
      unoDeclaredColor = map['declaredColor'] as String?;
      unoDrawStack = (map['drawStack'] as num?)?.toInt() ?? unoDrawStack;
      unoDrawStackType = map['drawStackType'] as String?;
      _applyUnoCounts(map['handCount']);
      _applyUnoCallNeeded(map['unoCallNeeded']);
      // Track special card effect (both players see the same effect)
      final playedBy = map['by'] as String?;
      final cardValue = card['value'] as String?;
      const specialValues = [
        'skip',
        'reverse',
        'draw2',
        'discard_all',
        'wild_draw4',
      ];
      if (specialValues.contains(cardValue)) {
        unoLastSpecialCard = cardValue;
        unoLastSpecialBy = playedBy;
        unoLastSpecialAt =
            (map['at'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch;
      } else {
        unoLastSpecialCard = null;
        unoLastSpecialBy = null;
        unoLastSpecialAt = null;
      }
      notifyListeners();
    });

    socket.on('game:uno:drawn', (data) {
      final map = _m(data);
      unoCurrentPlayer = map['nextPlayer'] as String?;
      unoMode = map['mode'] as String? ?? unoMode;
      unoDeclaredColor = map['declaredColor'] as String? ?? unoDeclaredColor;
      unoDrawStack = 0;
      unoDrawStackType = null;
      _applyUnoCounts(map['handCount']);
      _applyUnoCallNeeded(map['unoCallNeeded']);
      _log('카드 뽑기 - 다음 턴: $unoCurrentPlayer');
      notifyListeners();
    });

    socket.on('game:uno:challenged', (data) {
      final map = _m(data);
      unoCurrentPlayer = map['nextPlayer'] as String?;
      unoMode = map['mode'] as String? ?? unoMode;
      unoDrawStack = 0;
      unoDrawStackType = null;
      _applyUnoCounts(map['handCount']);
      final success = map['success'] == true;
      final by = map['by'] as String?;
      _log('UNO +4 도전 ${success ? "성공" : "실패"}: $by');
      notifyListeners();
    });

    socket.on('game:uno:discarded_all', (data) {
      final map = _m(data);
      unoCurrentPlayer = map['nextPlayer'] as String?;
      unoTopCardMap = _m(map['lastCard'] ?? {}).isEmpty
          ? unoTopCardMap
          : _m(map['lastCard']);
      unoTopCard = '${unoTopCardMap?['color']} ${unoTopCardMap?['value']}';
      unoDeclaredColor = null;
      unoDrawStack = (map['drawStack'] as num?)?.toInt() ?? 0;
      unoDrawStackType = map['drawStackType'] as String?;
      _applyUnoCounts(map['handCount']);
      _applyUnoCallNeeded(map['unoCallNeeded']);
      final count = map['count'] as int? ?? 0;
      _log('UNO 모두내기: ${map['by']} $count장');
      notifyListeners();
    });

    socket.on('game:uno:called', (data) {
      unoPendingCall = false;
      unoCatchable = false;
      _log('UNO 선언: ${_m(data)['by']}');
      notifyListeners();
    });

    socket.on('game:uno:reaction', (data) {
      final map = _m(data);
      unoReactionType = map['type'] as String?;
      unoReactionBy = map['by'] as String?;
      unoReactionAt =
          (map['at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
      _log('UNO 선물 리액션: $unoReactionBy $unoReactionType');
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
      restartWaiting = false;
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

    socket.on('game:restart:requested', (data) {
      restartPending = true;
      restartWaiting = false;
      _log('다시 시작 요청 받음: ${_m(data)['by']}');
      notifyListeners();
    });

    socket.on('heart:received', (data) {
      heartReceived = true;
      heartSenderEmoji = '💓';
      _log('하트 받음!');
      notifyListeners();
    });

    socket.on('game:restart:declined', (_) {
      restartWaiting = false;
      _log('다시 시작 거절됨');
      notifyListeners();
    });

    // ── catch mind listeners ──────────────────────────────────────────────
    void applyRoundStart(Map map) {
      catchActive = true;
      catchDrawer = map['drawer'] as String?;
      catchWord = null; // word comes separately via game:catch:word
      catchWordLen = (map['wordLen'] as int?) ?? 0;
      catchRound = (map['round'] as int?) ?? 1;
      catchMaxRounds = (map['maxRounds'] as int?) ?? 6;
      catchScores = _intMap(map['scores']);
      catchPhase = 'drawing';
      catchHint = null;
      catchGuessLog = [];
      final nicks = _m(map['nicknames']);
      if (nicks.isNotEmpty) {
        presenceNicknames = {
          ...presenceNicknames,
          ...nicks.map((k, v) => MapEntry(k, '$v')),
        };
      }
    }

    socket.on('game:catch:started', (data) {
      final map = _m(data);
      applyRoundStart(map);
      _log('캐치마인드 시작 round=$catchRound, drawer=$catchDrawer');
      notifyListeners();
    });

    socket.on('game:catch:round_start', (data) {
      final map = _m(data);
      applyRoundStart(map);
      _onCatchClear?.call(); // 새 라운드 = 캔버스 클리어
      _log('캐치마인드 라운드 시작 round=$catchRound, drawer=$catchDrawer');
      notifyListeners();
    });

    socket.on('game:catch:word', (data) {
      catchWord = _m(data)['word'] as String?;
      _log('내 단어: $catchWord');
      notifyListeners();
    });

    socket.on('game:catch:draw', (data) {
      _onCatchDraw?.call(_m(data));
      // notifyListeners 호출 안 함 — 콜백으로 직접 canvas 업데이트
    });

    socket.on('game:catch:clear', (_) {
      _onCatchClear?.call();
      notifyListeners();
    });

    socket.on('game:catch:guess_log', (data) {
      final map = _m(data);
      catchGuessLog = [...catchGuessLog, map];
      notifyListeners();
    });

    socket.on('game:catch:correct', (data) {
      final map = _m(data);
      catchPhase = 'guessed';
      catchWord = map['word'] as String?; // 정답자에게도 공개
      catchScores = _intMap(map['scores']);
      _log('정답! word=$catchWord, guesser=${map['guesser']}');
      notifyListeners();
    });

    socket.on('game:catch:timeout_result', (data) {
      final map = _m(data);
      catchPhase = 'timeout';
      catchWord = map['word'] as String?; // 타임아웃 시 단어 공개
      _log('타임아웃. word=$catchWord');
      notifyListeners();
    });

    socket.on('game:catch:hint', (data) {
      catchHint = _m(data)['hint'] as String?;
      _log('힌트: $catchHint');
      notifyListeners();
    });

    socket.on('partner:disconnected', (_) {
      _log('애인 연결 해제 이벤트 수신');
      unawaited(AuthService().getProfile());
      disconnect();
    });

    socket.on('game:catch:gameover', (data) {
      final map = _m(data);
      catchPhase = 'gameover';
      catchGameWinner = map['winner'] as String?;
      catchScores = _intMap(map['scores']);
      catchActive = false;
      _log('게임 종료. winner=$catchGameWinner');
      notifyListeners();
    });

    socket.on('game:catch:reset_done', (_) {
      catchActive = false;
      catchDrawer = null;
      catchWord = null;
      catchWordLen = 0;
      catchRound = 0;
      catchScores = {};
      catchPhase = null;
      catchGameWinner = null;
      catchHint = null;
      catchGuessLog = [];
      _onCatchClear?.call();
      notifyListeners();
    });

    socket.connect();
    _socket = socket;
  }

  void sendHeart() {
    _socket?.emit('heart:send', {});
  }

  void clearHeart() {
    heartReceived = false;
    notifyListeners();
  }

  void requestRestart(String gameType) {
    restartWaiting = true;
    notifyListeners();
    _socket?.emit('game:restart:request', {'gameType': gameType});
  }

  void respondToRestart(bool accept, String gameType) {
    restartPending = false;
    notifyListeners();
    _socket?.emit('game:restart:respond', {
      'accept': accept,
      'gameType': gameType,
    });
  }

  void clearOpponentLeft() {
    opponentJustLeft = false;
    notifyListeners();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    isConnected = false;
    status = '대기 중';
    userId = null;
    roomCode = null;
    presenceUsers = [];
    profileEmojis = {};
    presenceNicknames = {};
    lobbyGameType = null;
    lobbyHost = null;
    lobbyPlayers = [];
    lobbyStartedGameType = null;
    lobbyCharacterSelections = {};
    lobbyStartedYutCharacters = {};
    lobbyStartedYutBgm = null;
    pirateActive = false;
    pirateCurrentTurn = null;
    piratePickedSlots = [];
    pirateLoser = null;
    pirateBombSlot = null;
    piratePlayers = [];
    yutActive = false;
    yutCharacters = {};
    yutBgm = null;
    yutLastThrowBy = null;
    yutLastNak = false;
    yutLastThrowAt = null;
    yutLastMoveBy = null;
    yutLastMoveAt = null;
    yutLastCapturedCount = 0;
    yutLastCarriedCount = 0;
    yutLastStackedCount = 0;
    unoActive = false;
    unoPendingCall = false;
    unoCatchable = false;
    unoDrawStack = 0;
    unoDrawStackType = null;
    unoLastSpecialCard = null;
    unoLastSpecialBy = null;
    unoLastSpecialAt = null;
    unoReactionType = null;
    unoReactionBy = null;
    unoReactionAt = null;
    bombActive = false;
    restartPending = false;
    restartWaiting = false;
    opponentOnline = false;
    opponentJustLeft = false;
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

  Future<void> setProfileEmoji(String emoji) async {
    profileEmoji = emoji;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileEmojiKey, emoji);
    notifyListeners();
    _socket?.emitWithAck('profile:update', {
      'profileEmoji': emoji,
    }, ack: (_) {});
  }

  void joinGameLobby(String gameType) {
    final me = userId;
    lobbyGameType = gameType;
    lobbyHost = me;
    lobbyPlayers = me == null ? [] : [me];
    lobbyStartedGameType = null;
    lobbyCharacterSelections = {};
    lobbyStartedYutCharacters = {};
    lobbyStartedYutBgm = null;
    if (me != null) {
      profileEmojis = {...profileEmojis, me: profileEmoji};
    }
    if (gameType == 'catch') {
      catchActive = false;
      catchDrawer = null;
      catchWord = null;
      catchWordLen = 0;
      catchRound = 0;
      catchScores = {};
      catchPhase = null;
      catchGameWinner = null;
      catchHint = null;
      catchGuessLog = [];
    }
    // RPS 게임 로비 재진입 시 이전 게임 상태 초기화
    if (gameType == 'rps') {
      rpsMode = null;
      rpsActive = false;
      rpsPlayers = [];
      rpsScores = {};
      rpsRound = 0;
      rpsMukjippaPhase = null;
      rpsMukjippaAttacker = null;
      rpsLastChoices = null;
      rpsLastFingers = null;
      rpsLastGuesses = null;
      rpsLastTotal = null;
      rpsRoundWinner = null;
      rpsGameWinner = null;
      rpsRoundHistory = [];
      rpsResult = null;
      rpsChoices = null;
    }
    notifyListeners();
    _socket?.emitWithAck(
      'game:lobby:join',
      {'gameType': gameType},
      ack: (r) {
        final map = _m(r);
        if (map['ok'] == true) {
          final lobby = _m(map['lobby']);
          lobbyHost = lobby['host'] as String?;
          final players = lobby['players'];
          lobbyPlayers = players is List
              ? players.map((e) => '$e').toList()
              : [];
          lobbyCharacterSelections = _stringMap(lobby['characterSelections']);
          final emojis = _stringMap(lobby['profileEmojis']);
          if (emojis.isNotEmpty) profileEmojis = emojis;
          notifyListeners();
        } else {
          _log('대기방 입장 실패: ${map['reason']}');
        }
      },
    );
  }

  void leaveGameLobby(String gameType) {
    _socket?.emit('game:lobby:leave', {'gameType': gameType});
    if (lobbyGameType == gameType) {
      lobbyGameType = null;
      lobbyHost = null;
      lobbyPlayers = [];
      lobbyStartedGameType = null;
      lobbyCharacterSelections = {};
      lobbyStartedYutCharacters = {};
      lobbyStartedYutBgm = null;
      notifyListeners();
    }
  }

  Future<bool> selectYutLobbyCharacter(String character) async {
    if (!yutCharacterIds.contains(character) || lobbyGameType != 'yut') {
      return false;
    }
    final completer = Completer<bool>();
    _socket?.emitWithAck(
      'game:lobby:select_character',
      {'gameType': 'yut', 'character': character},
      ack: (r) {
        final map = _m(r);
        if (map['ok'] == true) {
          final lobby = _m(map['lobby']);
          lobbyCharacterSelections = _stringMap(lobby['characterSelections']);
          final players = lobby['players'];
          lobbyPlayers = players is List
              ? players.map((e) => '$e').toList()
              : lobbyPlayers;
          lobbyHost = lobby['host'] as String? ?? lobbyHost;
          notifyListeners();
          completer.complete(true);
        } else {
          _log('캐릭터 선택 실패: ${map['reason']}');
          completer.complete(false);
        }
      },
    );
    if (_socket == null) return false;
    return completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () => false,
    );
  }

  void startGameLobby(String gameType) {
    _socket?.emitWithAck(
      'game:lobby:start',
      {'gameType': gameType},
      ack: (r) {
        final map = _m(r);
        if (map['ok'] != true) {
          _log('게임 시작 실패: ${map['reason']}');
        }
      },
    );
  }

  void clearLobbyStart() {
    lobbyStartedGameType = null;
    notifyListeners();
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

  void startRpsGame(String mode) {
    _socket?.emit('game:rps:start', {'mode': mode});
  }

  void pickRps(String choice) {
    _socket?.emit('game:rps:pick', {'choice': choice});
  }

  void pickHanabagi(int fingers, int guess) {
    _socket?.emit('game:rps:pick', {'fingers': fingers, 'guess': guess});
  }

  void clearRpsRound() {
    rpsLastChoices = null;
    rpsLastFingers = null;
    rpsLastGuesses = null;
    rpsRoundWinner = null;
    notifyListeners();
  }

  void resetRpsGame() {
    rpsMode = null;
    rpsActive = false;
    rpsPlayers = [];
    rpsScores = {};
    rpsRound = 0;
    rpsMukjippaPhase = null;
    rpsMukjippaAttacker = null;
    rpsLastChoices = null;
    rpsLastFingers = null;
    rpsLastGuesses = null;
    rpsLastTotal = null;
    rpsRoundWinner = null;
    rpsGameWinner = null;
    rpsRoundHistory = [];
    notifyListeners();
    _socket?.emit('game:rps:reset');
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

  void startPirate(int slots) {
    _socket?.emit('game:pirate:start', {'slots': slots});
  }

  void pickPirateSlot(int slot) {
    _socket?.emit('game:pirate:pick', {'slot': slot});
  }

  void resetPirate() {
    pirateActive = false;
    pirateCurrentTurn = null;
    piratePickedSlots = [];
    pirateLoser = null;
    pirateBombSlot = null;
    piratePlayers = [];
    notifyListeners();
    _socket?.emit('game:pirate:reset', {});
  }

  // ── catch mind ────────────────────────────────────────────────────────────

  void registerCatchCallbacks(
    Function(Map<String, dynamic>) onDraw,
    VoidCallback onClear,
  ) {
    _onCatchDraw = onDraw;
    _onCatchClear = onClear;
  }

  void unregisterCatchCallbacks() {
    _onCatchDraw = null;
    _onCatchClear = null;
  }

  void startCatch({int maxRounds = 6}) {
    _socket?.emit('game:catch:start', {'maxRounds': maxRounds});
  }

  void sendCatchDraw(
    double x,
    double y,
    bool newStroke,
    int colorIdx,
    int sizeIdx,
  ) {
    _socket?.emit('game:catch:draw', {
      'x': x,
      'y': y,
      's': newStroke,
      'c': colorIdx,
      'sz': sizeIdx,
    });
  }

  void sendCatchClear() {
    _socket?.emit('game:catch:clear');
  }

  void guessCatch(String text) {
    _socket?.emit('game:catch:guess', {'text': text});
  }

  void requestCatchHint() {
    _socket?.emit('game:catch:hint_req');
  }

  void timeoutCatch() {
    _socket?.emit('game:catch:timeout');
  }

  void nextCatchRound() {
    _socket?.emit('game:catch:next');
  }

  void resetCatch() {
    catchActive = false;
    catchDrawer = null;
    catchWord = null;
    catchWordLen = 0;
    catchRound = 0;
    catchScores = {};
    catchPhase = null;
    catchGameWinner = null;
    catchHint = null;
    catchGuessLog = [];
    notifyListeners();
    _socket?.emit('game:catch:reset');
  }

  void newYutGame({Map<String, String>? characters, String? bgm}) {
    final payload = <String, dynamic>{};
    if (characters != null && characters.isNotEmpty) {
      payload['characters'] = characters;
    }
    if (bgm != null) {
      payload['bgm'] = bgm;
    }
    _socket?.emit('game:yut:new', payload);
  }

  void rollYutStartDice() => _socket?.emit('game:yut:roll_start');
  void throwYut() => _socket?.emit('game:yut:throw');
  void moveYut(int pieceId, {int moveIndex = 0}) => _socket?.emit(
    'game:yut:move',
    {'pieceId': pieceId, 'moveIndex': moveIndex},
  );

  void setUnoMode(String mode) {
    if (mode != 'classic' && mode != 'go_wild') return;
    selectedUnoMode = mode;
    notifyListeners();
  }

  void newUnoGame({String? mode}) =>
      _socket?.emit('game:uno:new', {'mode': mode ?? selectedUnoMode});
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
  void pressUnoButton() {
    if (unoPendingCall) {
      callUno();
      return;
    }
    if (unoCatchable) {
      catchUno();
    }
  }

  void challengeDraw4() => _socket?.emit('game:uno:challenge');
  void discardAllUno() => _socket?.emit('game:uno:discard_all');
  void sendUnoReaction(String type) =>
      _socket?.emit('game:uno:reaction', {'type': type});

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
      unoMode = uno['mode'] as String? ?? unoMode;
      selectedUnoMode = unoMode;
      unoTopCardMap = _cardMap(uno['topCard']);
      unoTopCard = unoTopCardMap?.toString() ?? uno['topCard']?.toString();
      unoDeclaredColor = uno['declaredColor'] as String?;
      unoDrawStack = (uno['drawStack'] as num?)?.toInt() ?? 0;
      unoDrawStackType = uno['drawStackType'] as String?;
      _applyUnoCounts(uno['handCount']);
      _applyUnoCallNeeded(uno['unoCallNeeded']);
      final hand = uno['hand'];
      unoHand = hand is List ? hand : [];
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

  Future<void> _loadProfileEmoji() async {
    final prefs = await SharedPreferences.getInstance();
    profileEmoji = prefs.getString(_profileEmojiKey) ?? defaultProfileEmoji;
    notifyListeners();
  }

  void _applyYutState(Map<String, dynamic> map) {
    yutActive = true;
    yutGameId = map['id'] as String? ?? yutGameId ?? 'active';
    yutPhase = map['phase'] as String? ?? yutPhase ?? 'throwing';
    yutCurrentTurn = map['currentTurn'] as String?;
    yutCharacters = _stringMap(map['characters']);
    yutBgm = map['bgm'] as String? ?? yutBgm;
    yutOrderCountdownUntil = map['orderCountdownUntil'] as int?;
    yutStartRolls = _m(map['startRolls'] ?? yutStartRolls);
    final pending = map['pendingMoves'];
    yutPendingMoves = pending is List ? List<dynamic>.from(pending) : [];
    final lastThrow = _m(map['lastThrow']);
    if (lastThrow.isNotEmpty) {
      yutLastThrow = lastThrow['resultName'] as String?;
      yutLastNak = lastThrow['nak'] == true;
    } else if (map.containsKey('lastThrow')) {
      yutLastThrow = null;
      yutLastNak = false;
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

  static Map<String, String> _stringMap(dynamic v) {
    final map = _m(v);
    return map.map((key, value) => MapEntry(key, '$value'));
  }

  static Map<String, int> _intMap(dynamic v) {
    final map = _m(v);
    return map.map(
      (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
    );
  }

  String _currentNickname() {
    final user = AuthService().user;
    return '${user?['Nickname'] ?? user?['nickname'] ?? user?['UserName'] ?? user?['userName'] ?? userId ?? ''}';
  }

  /// userId → 닉네임. 없으면 userId 그대로.
  String nameOf(String? uid) {
    if (uid == null) return '';
    if (uid == userId) {
      return _currentNickname().isNotEmpty ? _currentNickname() : uid;
    }
    return presenceNicknames[uid] ?? uid;
  }
}
