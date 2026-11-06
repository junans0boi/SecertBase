import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'auth_service.dart';
import 'marble_characters.dart';

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
  static const marbleCharacterIds = kMarbleCharacterIds;
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
  int lobbyStake = 0;
  int lobbyStartedStake = 0;
  String? lobbyResumedGameType;
  // 판돈이 걸린 판에서 비방장이 누른 준비 완료 여부(서버 기준)
  Map<String, bool> lobbyReady = {};
  // 방장이 고른 게임별 설정(로비 옵션). 서버가 보내 준 값만 믿는다.
  Map<String, Object> lobbyOptions = {};
  Map<String, Object> lobbyStartedOptions = {};
  // 서버가 로비 시작과 함께 판을 만든 게임(게임 2.0)이면 true. 방장은 시작 이벤트를 보내지 않는다.
  bool lobbyStartedServerStart = false;

  // 서버가 게임 동작을 거부했을 때 사용자에게 보여줄 안내 (GameMenuListener가 표시)
  String? gameNotice;
  // 안내가 특정 게임에 대한 것이면 그 게임 종류(잠수 안내 등). 다른 게임 화면에서는 띄우지 않는다.
  String? gameNoticeGameType;
  // 공용 리액션(게임 2.0): 마지막으로 받은 이모지
  GameReaction? lastReaction;
  int gameNoticeSeq = 0;

  // wallet
  int? walletBalance;

  // simple game results
  int? lastDice;
  String? lastRoulette;
  List<String>? lastRouletteOptions;
  int? lastRouletteIndex;
  int rouletteSeq = 0; // 새 결과가 올 때마다 증가(휠 회전 트리거)
  String? rpsResult;
  Map<String, String>? rpsChoices;
  bool? telepathySuccess;
  String? telepathySelected;
  Map<String, String>? telepathyChoices;

  // RPS multi-mode
  String? rpsMode; // 'single' | 'rps3' | 'mukjippa' | 'hanabagi'
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
  int yutLastCaptureBlockedCount = 0;
  int yutLastCarriedCount = 0;
  int yutLastStackedCount = 0;
  int? yutOrderCountdownUntil;
  // 플레이어별 장착 아이템 정보 {userCode: {slot: {name,icon,grade,stats}}}
  Map<String, Map<String, dynamic>> yutEquippedItems = {};
  List<dynamic> yutPendingMoves = [];
  bool yutHasBonusThrow = false;
  List<Map<String, dynamic>> yutTurnThrows = [];
  Map<String, dynamic> yutStartRolls = {};
  List<String> yutPlayers = [];
  Map<String, List<int>> yutPieces = {}; // userId -> piece positions (0-20)
  Map<String, List<dynamic>> yutPieceDetails = {};
  List<Map<String, dynamic>> yutChatMessages = [];
  List<Map<String, dynamic>> marbleChatMessages = [];

  // marble
  bool marbleActive = false;
  String? marbleGameId;
  String? marblePhase;
  String? marbleCurrentTurn;
  String? marbleWinner;
  String? marbleWinReason;
  bool marbleHasDoubleRoll = false;
  List<dynamic> marblePendingMoves = [];
  Map<String, dynamic> marbleStartRolls = {};
  int? marbleOrderCountdownUntil;
  Function(Map<String, dynamic>)? onMarbleTollPaid;
  Function(Map<String, dynamic>)? onMarbleSpecialTile;
  VoidCallback? onMarblePassedStart;
  List<String> marblePlayers = [];
  Map<String, List<dynamic>> marblePieceDetails = {};
  Map<String, dynamic> marbleLands = {}; // {pos: {owner, level}}
  Map<String, int> marbleCoins = {}; // {uid: coins}
  Map<String, int> marbleAssets = {}; // {uid: server-computed total assets}
  int marbleRound = 1;
  Map<String, dynamic>? marbleLandPrompt; // {type, pos, cost, level?}
  Map<String, String> marbleCharacters = {};
  Map<String, dynamic>? marbleLastRoll; // {dice1, dice2, total, isDouble}
  int? marbleLastRollAt;
  Map<String, Map<String, dynamic>> marbleEquippedItems = {};

  // uno
  Map<String, Map<String, dynamic>> unoEquippedItems = {};
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
  Map<String, dynamic>? unoDrawChoiceCard;
  bool unoCanPlayDrawn = false;
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
  // 서버 기준 라운드 남은 시간(재접속·이어하기 시 타이머 보정용)
  int? catchRemainingMs;
  int catchRoundSeq = 0;
  String? catchGameWinner;
  String? catchHint;
  List<Map<String, dynamic>> catchGuessLog = [];

  // blackjack
  bool blackjackActive = false;
  Map<String, dynamic>? blackjackState;

  // oldmaid (도둑잡기)
  bool oldmaidActive = false;
  Map<String, dynamic>? oldmaidState;

  // penalty (패널티킥)
  bool penaltyActive = false;
  Map<String, dynamic>? penaltyState;

  // bowling (볼링)
  bool bowlingActive = false;
  Map<String, dynamic>? bowlingState;

  // tank 대작전
  bool tankActive = false;
  Map<String, dynamic>? tankState;
  Map<String, dynamic>? tankLastShot;
  String? tankWinner;
  String? tankEndReason;
  Map<String, dynamic>? tankSummary;
  Map<String, int> tankSeries = {};
  Map<String, dynamic>? tankTimeoutEvent;
  int tankTimeoutSeq = 0;
  List<dynamic> tankMoveEvents = [];
  int tankMoveSeq = 0;

  // 고스톱 (2인 맞고)
  bool gostopActive = false;
  Map<String, dynamic>? gostopState; // 내 시점 직렬화 (상대 손패 숨김)
  Map<String, dynamic>? gostopSettlement; // 정산 결과 (finished 시)
  int? gostopNageoriMultiplier; // 나가리 발생 시 이월 배수 알림
  String? gostopError;
  bool gostopSettlementPending = false;

  // 드로잉 데이터는 콜백으로 직접 처리 (ChangeNotifier 우회 → 성능)
  Function(Map<String, dynamic>)? _onCatchDraw;
  VoidCallback? _onCatchClear;
  Function(Map<String, dynamic>)? _onItemEffect;

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  // ── 게임 2.0: 게임별 컨트롤러가 쓰는 통로 ────────────────────────────────
  // 게임 화면은 각자의 컨트롤러(ChangeNotifier)에서 이벤트를 받고 보낸다.
  // SocketService에는 연결·방·공용 상태만 두어 게임끼리 서로 건드리지 않게 한다.
  final Map<String, List<void Function(Map<String, dynamic>)>> _gameHandlers =
      {};
  final Set<String> _attachedGameEvents = {};
  final List<VoidCallback> _resetHooks = [];

  /// [event]를 받으면 [handler]를 부른다. 연결 전에 등록해도 연결되면 붙는다.
  void addGameHandler(
    String event,
    void Function(Map<String, dynamic> data) handler,
  ) {
    _gameHandlers.putIfAbsent(event, () => []).add(handler);
    _attachGameEvent(event);
  }

  void removeGameHandler(
    String event,
    void Function(Map<String, dynamic> data) handler,
  ) {
    _gameHandlers[event]?.remove(handler);
  }

  void _attachGameEvent(String event) {
    final socket = _socket;
    if (socket == null || _attachedGameEvents.contains(event)) return;
    _attachedGameEvents.add(event);
    socket.on(event, (data) {
      final map = _m(data);
      for (final handler in List.of(_gameHandlers[event] ?? const [])) {
        handler(map);
      }
    });
  }

  /// 방을 나가거나 로그아웃할 때 게임 컨트롤러가 자기 상태를 지우도록 알린다.
  void addResetHook(VoidCallback hook) => _resetHooks.add(hook);

  void removeResetHook(VoidCallback hook) => _resetHooks.remove(hook);

  /// 거부 사유를 안내하는 게임 이벤트 전송(컨트롤러용).
  void emitGameEvent(
    String event, [
    Map<String, dynamic>? payload,
    void Function(Map<String, dynamic> ack)? onAck,
  ]) => _emitGame(event, payload, onAck);

  /// 공용 리액션 보내기. 서버가 허용 목록·간격을 검사한다.
  void sendReaction(String emoji, {String? gameType}) {
    _socket?.emitWithAck('game:reaction', {
      'emoji': emoji,
      'gameType': ?gameType,
    }, ack: (_) {});
  }

  /// 내가 아닌 참가자(2인 게임의 상대).
  String? get partnerId {
    final me = userId;
    for (final p in presenceUsers) {
      if (p != me) return p;
    }
    for (final p in presenceNicknames.keys) {
      if (p != me) return p;
    }
    return null;
  }

  void _resetGameState() {
    lastReaction = null;
    gameNoticeGameType = null;
    for (final hook in List.of(_resetHooks)) {
      hook();
    }
    lastDice = null;
    lastRoulette = null;
    lastRouletteOptions = null;
    rpsResult = null;
    rpsChoices = null;
    telepathySuccess = null;
    telepathySelected = null;
    telepathyChoices = null;
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
    pirateActive = false;
    pirateCurrentTurn = null;
    piratePickedSlots = [];
    pirateLoser = null;
    pirateBombSlot = null;
    piratePlayers = [];
    yutActive = false;
    yutGameId = null;
    yutPhase = null;
    yutCurrentTurn = null;
    yutLastThrow = null;
    yutLastNak = false;
    yutWinner = null;
    yutCharacters = {};
    yutBgm = null;
    yutLastThrowBy = null;
    yutLastThrowAt = null;
    yutLastMoveBy = null;
    yutLastMoveAt = null;
    yutLastCapturedCount = 0;
    yutLastCarriedCount = 0;
    yutLastStackedCount = 0;
    yutOrderCountdownUntil = null;
    yutEquippedItems = {};
    yutPendingMoves = [];
    yutHasBonusThrow = false;
    yutTurnThrows = [];
    yutStartRolls = {};
    yutPlayers = [];
    yutPieces = {};
    yutPieceDetails = {};
    yutChatMessages = [];
    marbleActive = false;
    marbleGameId = null;
    marblePhase = null;
    marbleCurrentTurn = null;
    marbleWinner = null;
    marbleWinReason = null;
    marbleHasDoubleRoll = false;
    marblePendingMoves = [];
    marbleStartRolls = {};
    marbleOrderCountdownUntil = null;
    marblePlayers = [];
    marblePieceDetails = {};
    marbleLands = {};
    marbleCoins = {};
    marbleAssets = {};
    marbleRound = 1;
    marbleLandPrompt = null;
    marbleCharacters = {};
    marbleLastRoll = null;
    marbleLastRollAt = null;
    marbleEquippedItems = {};
    unoActive = false;
    unoCurrentPlayer = null;
    unoTopCard = null;
    unoTopCardMap = null;
    unoDeclaredColor = null;
    unoP1Count = null;
    unoP2Count = null;
    unoPlayers = [];
    unoHand = [];
    unoWinner = null;
    unoEquippedItems = {};
    unoPendingCall = false;
    unoCatchable = false;
    unoDrawChoiceCard = null;
    unoCanPlayDrawn = false;
    unoDrawStack = 0;
    unoDrawStackType = null;
    unoLastSpecialCard = null;
    unoLastSpecialBy = null;
    unoLastSpecialAt = null;
    unoReactionType = null;
    unoReactionBy = null;
    unoReactionAt = null;
    bombActive = false;
    bombCurrentPlayer = null;
    bombQuestion = null;
    bombCategory = null;
    bombDuration = null;
    bombStartTime = null;
    bombLoser = null;
    bombLastAnswerCorrect = null;
    bombPassCount = 0;
    catchActive = false;
    catchDrawer = null;
    catchWord = null;
    catchWordLen = 0;
    catchRound = 0;
    catchMaxRounds = 6;
    catchScores = {};
    catchPhase = null;
    catchGameWinner = null;
    catchHint = null;
    catchGuessLog = [];
    blackjackActive = false;
    blackjackState = null;
    oldmaidActive = false;
    oldmaidState = null;
    penaltyActive = false;
    penaltyState = null;
    bowlingActive = false;
    bowlingState = null;
    tankActive = false;
    tankState = null;
    tankLastShot = null;
    tankWinner = null;
    tankEndReason = null;
    tankSummary = null;
    tankSeries = {};
    tankTimeoutEvent = null;
    tankMoveEvents = [];
    gostopActive = false;
    gostopState = null;
    gostopSettlement = null;
    gostopNageoriMultiplier = null;
    gostopError = null;
    gostopSettlementPending = false;
  }

  void connect(String url, String token) {
    _resetGameState();
    _socket?.dispose();
    _socket = null;
    isConnected = false;
    status = '연결 중...';
    serverUrl = url;
    _log('연결 시도: $url');
    notifyListeners();

    final socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      _log('소켓 연결됨');
      socket.emitWithAck(
        'session:join',
        {'profileEmoji': profileEmoji},
        ack: (r) {
          final map = _m(r);
          if (map['ok'] == true) {
            roomCode = '${map['roomCode'] ?? ''}';
            userId = '${map['userId'] ?? ''}';
            socket.emitWithAck(
              'session:restore',
              {},
              ack: (r2) {
                final rm = _m(r2);
                if (rm['ok'] == true) {
                  _restoreGames(_m(rm['activeGames'] ?? {}));
                }
                isConnected = true;
                status = '입장 완료';
                _log('방 입장 및 복원 완료');
                notifyListeners();
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
      lobbyStake = (map['stake'] as num?)?.toInt() ?? 0;
      lobbyOptions = _optionMap(map['options']);
      final readyRaw = map['ready'];
      lobbyReady = readyRaw is Map
          ? readyRaw.map((k, v) => MapEntry('$k', v == true))
          : <String, bool>{};
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
      lobbyStartedStake = (metadata['stake'] as num?)?.toInt() ?? 0;
      lobbyStartedOptions = _optionMap(metadata['options']);
      lobbyStartedServerStart = metadata['serverStart'] == true;
      final startedMode = lobbyStartedOptions['mode'];
      if (lobbyStartedGameType == 'uno' && startedMode is String) {
        selectedUnoMode = startedMode;
      }
      final emojis = _stringMap(map['profileEmojis']);
      if (emojis.isNotEmpty) profileEmojis = emojis;
      final nicks = _stringMap(map['nicknames']);
      if (nicks.isNotEmpty) {
        presenceNicknames = {...presenceNicknames, ...nicks};
      }
      _log('대기방 게임 시작: $lobbyStartedGameType');
      notifyListeners();
    });

    socket.on('wallet:updated', (data) {
      final map = _m(data);
      final me = userId;
      if (me != null && map.containsKey(me)) {
        walletBalance = (map[me] as num?)?.toInt();
        notifyListeners();
      }
    });

    socket.on('game:dice:result', (data) {
      lastDice = _m(data)['value'] as int?;
      _log('주사위: $lastDice');
      notifyListeners();
    });

    socket.on('game:roulette:result', (data) {
      final map = _m(data);
      lastRoulette = map['selected'] as String?;
      lastRouletteIndex = (map['index'] as num?)?.toInt();
      rouletteSeq++;
      final rawOptions = map['options'];
      if (rawOptions is List) {
        lastRouletteOptions = rawOptions.whereType<String>().toList();
      }
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

      if (mode == 'single' || mode == 'rps3') {
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

    // 상대 연결이 끊겨 서버가 판을 취소하면 대기 화면에서 빠져나온다.
    socket.on('game:rps:cancelled', (data) {
      final cancelReason = _m(data)['reason'];
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
      if (cancelReason == 'afk') {
        notifyListeners(); // 잠수 안내는 game:afk:forfeit에서 이미 표시했다.
      } else {
        _setGameNotice('상대 연결이 끊겨 가위바위보 판이 취소되었어요.');
      }
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
      // 재접속 시 서버가 이미 꽂힌 칼 목록을 보내준다.
      final rawSlots = map['pickedSlots'];
      piratePickedSlots = rawSlots is List
          ? rawSlots.map((e) => (e as num).toInt()).toList()
          : <int>[];
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
      final serverSlots = map['pickedSlots'];
      if (serverSlots is List) {
        // 서버 배열을 그대로 쓴다(중복 수신 시에도 어긋나지 않음).
        piratePickedSlots = serverSlots.map((e) => (e as num).toInt()).toList();
      } else if (slot != null && !piratePickedSlots.contains(slot)) {
        piratePickedSlots = [...piratePickedSlots, slot];
      }
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
      yutLastCapturedCount = 0;
      yutLastCaptureBlockedCount = 0;
      yutLastCarriedCount = 0;
      yutLastStackedCount = 0;
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
      yutLastCapturedCount = 0;
      yutLastCaptureBlockedCount = 0;
      _log('윷 결과: $yutLastThrow - 다음 턴: $yutCurrentTurn');
      notifyListeners();
    });

    socket.on('game:yut:move_result', (data) {
      _applyYutMoveResult(_m(data));
      notifyListeners();
    });

    socket.on('game:yut:ended', (data) {
      yutWinner = _m(data)['winner'] as String?;
      yutActive = false;
      _log('윷놀이 종료 - 승리: $yutWinner');
      notifyListeners();
    });

    socket.on('game:yut:chat', (data) {
      final map = _m(data);
      final message = map['message'] as String?;
      final by = map['by'] as String?;
      if (message == null || by == null) return;
      yutChatMessages = [
        ...yutChatMessages,
        {
          'by': by,
          'message': message,
          'at':
              (map['at'] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch,
        },
      ];
      if (yutChatMessages.length > 50) {
        yutChatMessages = yutChatMessages.sublist(yutChatMessages.length - 50);
      }
      notifyListeners();
    });

    socket.on('game:item_effect', (data) {
      _onItemEffect?.call(_m(data));
    });

    socket.on('game:marble:chat', (data) {
      final map = _m(data);
      final message = map['message'] as String?;
      final by = map['by'] as String?;
      if (message == null || by == null) return;
      marbleChatMessages = [
        ...marbleChatMessages,
        {
          'by': by,
          'message': message,
          'at':
              (map['at'] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch,
        },
      ];
      if (marbleChatMessages.length > 50) {
        marbleChatMessages = marbleChatMessages.sublist(
          marbleChatMessages.length - 50,
        );
      }
      notifyListeners();
    });

    // marble events
    socket.on('game:marble:state', (data) {
      _applyMarbleState(_m(data));
      notifyListeners();
    });

    socket.on('game:marble:roll_result', (data) {
      final map = _m(data);
      _applyMarbleState(map);
      final roll = map['rollResult'];
      if (roll is Map) {
        marbleLastRoll = Map<String, dynamic>.from(roll);
      }
      marbleLastRollAt = DateTime.now().millisecondsSinceEpoch;
      final byMe = map['by'] == userId;
      if (map['jailed'] == true) {
        _setGameNotice(
          byMe ? '블랙사이트에 갇혀 이번 턴은 쉬어요. 더블이 나오면 탈출해요.' : '상대가 블랙사이트에 갇혀 턴을 쉬어요.',
        );
      } else if (map['jailEscape'] == true) {
        _setGameNotice(byMe ? '더블! 블랙사이트를 탈출했어요.' : '상대가 더블로 블랙사이트를 탈출했어요.');
      }
      notifyListeners();
    });

    socket.on('game:marble:move_result', (data) {
      final map = _m(data);
      _applyMarbleState(map);
      if (map['winner'] != null) {
        marbleWinner = map['winner'] as String?;
        marbleWinReason = map['winReason'] as String?;
        marbleActive = false;
      }
      if (map['passedStart'] == true) onMarblePassedStart?.call();
      notifyListeners();
    });

    socket.on('game:marble:ended', (data) {
      final map = _m(data);
      // C3: winner가 null인 timeout_draw도 처리
      marbleWinner = map['winner'] as String?;
      marbleWinReason = map['winReason'] as String?;
      marbleActive = false;
      // H6: finalScores가 있으면 coins에 반영 (서든데스 점수 표시용)
      final finalScores = map['finalScores'];
      if (finalScores is Map) {
        marbleCoins = finalScores.map(
          (k, v) => MapEntry('$k', (v as num?)?.toInt() ?? 0),
        );
      }
      notifyListeners();
    });

    socket.on('game:marble:land_prompt', (data) {
      marbleLandPrompt = _m(data);
      notifyListeners();
    });

    socket.on('game:marble:special_tile', (data) {
      final map = _m(data);
      final coinsRaw = map['coins'];
      if (coinsRaw is Map) {
        coinsRaw.forEach((k, v) {
          marbleCoins['$k'] = (v as num?)?.toInt() ?? 0;
        });
      }
      onMarbleSpecialTile?.call(map);
      notifyListeners();
    });

    socket.on('game:marble:toll_paid', (data) {
      final map = _m(data);
      final coinsRaw = map['coins'];
      if (coinsRaw is Map) {
        marbleCoins = coinsRaw.map(
          (k, v) => MapEntry('$k', (v as num?)?.toInt() ?? 0),
        );
      }
      onMarbleTollPaid?.call(map);
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
      unoPendingCall = false;
      unoCatchable = false;
      unoDrawChoiceCard = null;
      unoCanPlayDrawn = false;
      unoLastSpecialCard = null;
      unoLastSpecialBy = null;
      unoLastSpecialAt = null;
      unoReactionType = null;
      unoReactionBy = null;
      unoReactionAt = null;
      _applyUnoCounts(map['handCount']);
      unoHand = [];
      unoWinner = null;
      final equippedRaw = map['equippedItems'];
      if (equippedRaw is Map) {
        unoEquippedItems = equippedRaw.map(
          (k, v) =>
              MapEntry('$k', v is Map ? Map<String, dynamic>.from(v) : {}),
        );
      }
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
      unoDrawChoiceCard = null;
      unoCanPlayDrawn = false;
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
      unoDrawStack = (map['drawStack'] as num?)?.toInt() ?? 0;
      unoDrawStackType = map['drawStackType'] as String?;
      _applyUnoCounts(map['handCount']);
      _applyUnoCallNeeded(map['unoCallNeeded']);
      _log('카드 뽑기 - 다음 턴: $unoCurrentPlayer');
      notifyListeners();
    });

    socket.on('game:uno:draw_choice', (data) {
      final map = _m(data);
      final card = _cardMap(map['card']);
      if (card == null) return;
      unoDrawChoiceCard = card;
      unoCanPlayDrawn = true;
      notifyListeners();
    });

    socket.on('game:uno:draw_decided', (data) {
      final map = _m(data);
      unoCurrentPlayer = map['nextPlayer'] as String?;
      unoDeclaredColor = map['declaredColor'] as String? ?? unoDeclaredColor;
      unoDrawStack = 0;
      unoDrawStackType = null;
      unoDrawChoiceCard = null;
      unoCanPlayDrawn = false;
      _applyUnoCounts(map['handCount']);
      _applyUnoCallNeeded(map['unoCallNeeded']);
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
      unoPendingCall = false;
      unoCatchable = false;
      unoDrawChoiceCard = null;
      unoCanPlayDrawn = false;
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

    socket.on('game:blackjack:updated', (data) {
      blackjackState = _m(data);
      blackjackActive = blackjackState?['status'] == 'playing';
      restartWaiting = false;
      _log('블랙잭 업데이트');
      notifyListeners();
    });

    socket.on('game:oldmaid:updated', (data) {
      oldmaidState = _m(data);
      oldmaidActive = oldmaidState?['status'] == 'playing';
      restartWaiting = false;
      _log('도둑잡기 업데이트');
      notifyListeners();
    });

    socket.on('game:penalty:updated', (data) {
      penaltyState = _m(data);
      penaltyActive = penaltyState?['status'] == 'playing';
      restartWaiting = false;
      _log('패널티킥 업데이트');
      notifyListeners();
    });

    socket.on('game:bowling:updated', (data) {
      bowlingState = _m(data);
      bowlingActive = bowlingState?['status'] == 'playing';
      restartWaiting = false;
      _log('볼링 업데이트');
      notifyListeners();
    });

    socket.on('game:tank:started', (data) {
      tankState = _m(data);
      tankLastShot = null;
      tankWinner = null;
      tankEndReason = null;
      tankSummary = null;
      tankActive = true;
      final series = _m(tankState?['series']);
      tankSeries = series.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
      _log('탱크 대작전 시작');
      notifyListeners();
    });

    socket.on('game:tank:updated', (data) {
      tankState = _m(data);
      _log('탱크 상태 업데이트');
      notifyListeners();
    });

    socket.on('game:tank:shot', (data) {
      tankLastShot = _m(data);
      _log('탱크 발사');
      notifyListeners();
    });

    socket.on('game:tank:ended', (data) {
      final map = _m(data);
      tankWinner = map['winner'] as String?;
      tankEndReason = map['reason'] as String?;
      tankSummary = map['summary'] is Map ? _m(map['summary']) : null;
      final series = _m(map['series']);
      tankSeries = series.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
      if (map['state'] is Map) tankState = _m(map['state']);
      tankActive = false;
      _log('탱크 게임 종료: 승자 $tankWinner ($tankEndReason)');
      notifyListeners();
    });

    socket.on('game:tank:timeout', (data) {
      tankTimeoutEvent = _m(data);
      tankTimeoutSeq++;
      notifyListeners();
    });

    socket.on('game:tank:moved', (data) {
      final events = _m(data)['events'];
      tankMoveEvents = events is List ? events : [];
      tankMoveSeq++;
      notifyListeners();
    });

    // 턴제 게임 공통 잠수 감시: 60초 경고, 90초 기권패
    socket.on('game:afk:warning', (data) {
      final map = _m(data);
      final secondsLeft = (map['secondsLeft'] as num?)?.toInt() ?? 30;
      _setGameNotice(
        map['player'] == userId
            ? '$secondsLeft초 안에 진행하지 않으면 기권패로 처리돼요!'
            : '상대가 $secondsLeft초 안에 진행하지 않으면 기권승이에요.',
        gameType: map['gameType'] as String?,
      );
    });

    socket.on('game:afk:forfeit', (data) {
      final map = _m(data);
      _setGameNotice(
        map['loser'] == userId
            ? '제한 시간 동안 진행하지 않아 기권패 처리됐어요.'
            : '상대가 제한 시간 동안 진행하지 않아 기권승했어요!',
        gameType: map['gameType'] as String?,
      );
    });

    socket.on('wallet:settle_failed', (_) {
      _setGameNotice('코인 정산이 지연되고 있어요. 잠시 후 잔액을 확인해 주세요.');
    });

    socket.on('game:gostop:started', (data) {
      gostopState = _m(data);
      gostopSettlement = null;
      gostopNageoriMultiplier = null;
      gostopError = null;
      gostopSettlementPending = false;
      gostopActive = true;
      _log('고스톱 시작');
      notifyListeners();
    });

    socket.on('game:gostop:updated', (data) {
      gostopState = _m(data);
      gostopSettlementPending = gostopState?['settlementStatus'] == 'pending';
      _log('고스톱 상태 업데이트');
      notifyListeners();
    });

    socket.on('game:gostop:settlement_pending', (data) {
      gostopState = _m(data);
      gostopSettlement = _m(gostopState?['settlement']);
      gostopSettlementPending = true;
      gostopActive = true;
      gostopError = '코인 정산이 완료되지 않았습니다. 다시 시도해 주세요.';
      _log('고스톱 지갑 정산 대기');
      notifyListeners();
    });

    socket.on('game:gostop:ended', (data) {
      gostopState = _m(data);
      gostopSettlement = _m(gostopState?['settlement']);
      gostopActive = false;
      gostopSettlementPending = false;
      gostopError = null;
      _log('고스톱 종료: 승자 ${gostopState?['winner']}');
      notifyListeners();
    });

    socket.on('game:gostop:nageori', (data) {
      gostopNageoriMultiplier = (_m(data)['baseMultiplier'] as num?)?.toInt();
      _log('고스톱 나가리! 배수 이월 ×$gostopNageoriMultiplier');
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

    // 새 판이 시작됐다(동의된 재대결·동시 요청 포함): 열려 있는 재대결 창과 대기 표시를 모두 닫는다.
    socket.on('game:restart:started', (data) {
      restartPending = false;
      restartWaiting = false;
      notifyListeners();
    });

    socket.on('game:restart:declined', (data) {
      restartWaiting = false;
      restartPending = false;
      _log('다시 시작 거절됨');
      if (_m(data)['reason'] == 'game_in_progress') {
        _setGameNotice('판돈이 걸린 판은 끝까지 마친 뒤에 다시 할 수 있어요.');
      } else {
        notifyListeners();
      }
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
      catchRemainingMs = (map['remainingMs'] as num?)?.toInt();
      catchRoundSeq++;
      _log('캐치마인드 시작 round=$catchRound, drawer=$catchDrawer');
      notifyListeners();
    });

    socket.on('game:catch:round_start', (data) {
      final map = _m(data);
      applyRoundStart(map);
      catchRemainingMs = null;
      catchRoundSeq++;
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

    socket.on('game:reaction', (data) {
      final map = _m(data);
      final emoji = map['emoji'];
      final by = map['by'];
      if (emoji is! String || by is! String) return;
      lastReaction = GameReaction(
        by: by,
        emoji: emoji,
        gameType: map['gameType'] as String?,
        at:
            (map['at'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );
      notifyListeners();
    });

    socket.connect();
    _socket = socket;
    _attachedGameEvents.clear();
    for (final event in _gameHandlers.keys) {
      _attachGameEvent(event);
    }
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
    _emitGame('game:restart:request', {'gameType': gameType});
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
    _resetGameState();
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
    lobbyOptions = {};
    lobbyStartedOptions = {};
    lobbyStartedYutCharacters = {};
    lobbyStartedYutBgm = null;
    lobbyStake = 0;
    lobbyStartedStake = 0;
    lobbyResumedGameType = null;
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
    yutLastCaptureBlockedCount = 0;
    yutLastCarriedCount = 0;
    yutLastStackedCount = 0;
    yutTurnThrows = [];
    unoActive = false;
    unoEquippedItems = {};
    unoPendingCall = false;
    unoCatchable = false;
    unoDrawChoiceCard = null;
    unoCanPlayDrawn = false;
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
    lobbyHost = null;
    lobbyPlayers = me == null ? [] : [me];
    lobbyStartedGameType = null;
    lobbyResumedGameType = null;
    lobbyCharacterSelections = {};
    lobbyOptions = {};
    lobbyStartedOptions = {};
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
    if (gameType == 'rps' || gameType == 'zero') {
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
          // Resume path: server detected an active game with a viewer — go straight to game screen.
          if (map['status'] == 'resumed') {
            lobbyResumedGameType = map['gameType'] as String?;
            notifyListeners();
            return;
          }
          // Normal waiting lobby path.
          final lobby = _m(map['lobby']);
          lobbyHost = lobby['host'] as String?;
          final players = lobby['players'];
          lobbyPlayers = players is List
              ? players.map((e) => '$e').toList()
              : [];
          lobbyCharacterSelections = _stringMap(lobby['characterSelections']);
          lobbyOptions = _optionMap(lobby['options']);
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
      lobbyOptions = {};
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

  Future<bool> selectMarbleLobbyCharacter(String charId) async {
    if (!marbleCharacterIds.contains(charId) || lobbyGameType != 'marble') {
      return false;
    }
    final completer = Completer<bool>();
    _socket?.emitWithAck(
      'game:lobby:select_character',
      {'gameType': 'marble', 'character': charId},
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
          _log('마블 캐릭터 선택 실패: ${map['reason']}');
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

  Future<void> fetchAndSelectMarbleCharacter() async {
    // 캐릭터 우선순위: 장착 아이템 → 반대 성별 기본값 → 나머지 목록 순
    Future<bool> trySelect(String charId) => selectMarbleLobbyCharacter(charId);

    String preferredChar = 'k';
    String fallbackChar = 'ria';

    try {
      final base = serverUrl ?? '';
      final token = AuthService().token;
      if (token != null) {
        final res = await http.get(
          Uri.parse('$base/api/shop/equipped?game=marble'),
          headers: {'Authorization': 'Bearer $token'},
        );
        final body = jsonDecode(res.body) as Map;
        if (body['ok'] == true) {
          final slots = body['slots'] as Map? ?? {};
          // 남성 슬롯 우선, 없으면 여성 슬롯
          final mSlot = slots['marble_character_m'];
          final fSlot = slots['marble_character_f'];
          final rawId = (mSlot ?? fSlot)?['character_id'] as String?;
          if (rawId != null && marbleCharacterIds.contains(rawId)) {
            preferredChar = rawId;
            // 반대 성별 기본값을 폴백으로 설정
            fallbackChar = mSlot != null ? 'ria' : 'k';
          }
        }
      }
    } catch (_) {}

    // 선호 캐릭터 시도 → 충돌 시 폴백 → 그래도 실패하면 목록 순차 탐색
    if (await trySelect(preferredChar)) return;
    if (await trySelect(fallbackChar)) return;
    for (final id in marbleCharacterIds) {
      if (id == preferredChar || id == fallbackChar) continue;
      if (await trySelect(id)) return;
    }
  }

  void startGameLobby(String gameType) {
    _emitGame('game:lobby:start', {'gameType': gameType});
  }

  /// 방장이 로비 옵션을 바꾼다. 화면은 바로 반영하고 서버 갱신으로 확정한다.
  void setLobbyOption(String gameType, String key, Object value) {
    lobbyOptions = {...lobbyOptions, key: value};
    lobbyReady = {};
    notifyListeners();
    _emitGame('game:lobby:set_option', {
      'gameType': gameType,
      'key': key,
      'value': value,
    });
  }

  void setLobbyStake(String gameType, int stake) {
    lobbyStake = stake;
    lobbyReady = {};
    notifyListeners();
    _emitGame('game:lobby:set_stake', {'gameType': gameType, 'stake': stake});
  }

  /// 판돈이 걸린 판에서 비방장이 금액에 동의(준비 완료)한다.
  void setLobbyReady(String gameType, bool ready) {
    final me = userId;
    if (me != null) {
      lobbyReady = {...lobbyReady, me: ready};
      notifyListeners();
    }
    _emitGame('game:lobby:ready', {'gameType': gameType, 'ready': ready});
  }

  // ── 서버 거부 사유 안내 ────────────────────────────────────────────────────

  static const Set<String> _silentGameReasons = {
    // 게임 2.0: 두 기기가 동시에 보낸 중복 요청이나 지난 판 요청은 조용히 넘긴다.
    'stale_game',
    'stale_round',
    'wrong_answer',
    'time_up',
    'already_selected',
    'waiting',
  };

  static const Map<String, String> _gameReasonMessages = {
    'not_joined': '방에 연결되어 있지 않아요.',
    'not_connected': '서버에 연결되어 있지 않아요. 잠시 후 다시 시도해 주세요.',
    'need_two_players': '두 사람이 모두 접속해야 해요.',
    'not_your_turn': '아직 내 차례가 아니에요.',
    'not your turn': '아직 내 차례가 아니에요.',
    'game_in_progress': '이미 진행 중인 게임이 있어요.',
    'no_game': '진행 중인 게임이 없어요. 다시 시작해 주세요.',
    'invalid_payload': '요청 형식이 올바르지 않아요.',
    'internal_error': '서버에서 오류가 발생했어요. 잠시 후 다시 시도해 주세요.',
    'partner_not_ready': '상대가 아직 준비 완료를 누르지 않았어요.',
    'not_host': '방장만 할 수 있어요.',
    'host_cannot_ready': '방장은 준비 완료를 누를 필요가 없어요.',
    'stake_not_supported': '이 게임은 판돈을 걸 수 없어요.',
    'invalid_stake': '선택할 수 없는 판돈이에요.',
    'must_choose_drawn_card': '뽑은 카드를 낼지 먼저 정해 주세요.',
    'must_draw_or_defend': '공격 카드를 막거나 카드를 받아야 해요.',
    'round_not_over': '아직 라운드 시간이 남아 있어요.',
    'hint_used': '힌트는 라운드당 한 번만 쓸 수 있어요.',
    'blocked': '경사가 너무 가팔라서 올라갈 수 없어요.',
    'not enough fuel': '연료가 부족해요.',
    'out of ammo': '탄약이 없어요.',
    'weapon not owned': '사용할 수 없는 무기예요.',
    'wrong phase': '지금은 할 수 없는 동작이에요.',
    'no_restart_request': '재시작 요청이 만료되었어요.',
    'unsupported_game': '이 게임은 재시작을 지원하지 않아요.',
    'options_mismatch': '상대가 다른 문제를 풀고 있어요. 같은 문제로 맞춰 주세요.',
    'already_submitted': '이미 선택했어요.',
    'land_action_pending': '영지 선택을 먼저 마쳐 주세요.',
    'must_move_first': '먼저 말을 움직여 주세요.',
    'not_a_player': '이 게임의 참가자가 아니에요.',
    // 게임 2.0
    'finished': '이미 끝난 판이에요.',
    'game_over': '이미 끝난 판이에요.',
    'not_playing': '지금은 진행 중인 판이 없어요.',
    'invalid_choice': '고를 수 없는 칸이에요.',
    'invalid_slot': '고를 수 없는 구멍이에요.',
    'slot_taken': '이미 칼이 꽂힌 구멍이에요.',
    'not_exploded': '아직 통이 터지지 않았어요.',
    'not_winner': '벌칙은 이긴 사람이 정해요.',
    'not_loser': '벌칙을 받은 사람만 완료할 수 있어요.',
    'no_penalty': '아직 벌칙이 정해지지 않았어요.',
    'penalty_already_set': '벌칙은 이미 정해졌어요.',
    'penalty_already_done': '벌칙은 이미 완료했어요.',
    'penalty_empty': '벌칙 내용을 적어 주세요.',
    'penalty_too_long': '벌칙은 30자 이내로 적어 주세요.',
    'invalid_guess': '고를 수 없는 숫자예요.',
    'invalid_fingers': '손가락 수를 다시 골라 주세요.',
    'already_picked': '이번 라운드는 이미 골랐어요.',
    'cannot_play_card': '지금은 그 카드를 낼 수 없어요.',
    'card_not_found': '손에 없는 카드예요.',
    'must_declare_color': '바꿀 색을 골라 주세요.',
    'no_target': '잡을 상대가 없어요.',
    'not_needed': '지금은 원카드를 외칠 때가 아니에요.',
    'cannot_challenge_during_stack': '공격이 쌓여 있을 때는 도전할 수 없어요.',
    'no_draw_choice': '낼 수 있는 뽑은 카드가 없어요.',
    'no_challenge': '도전할 +4가 없어요.',
  };

  void _setGameNotice(String message, {String? gameType}) {
    gameNotice = message;
    gameNoticeGameType = gameType;
    gameNoticeSeq++;
    notifyListeners();
  }

  void clearGameNotice() {
    gameNotice = null;
  }

  /// ack를 받아 거부 사유를 안내하는 게임 이벤트 전송.
  void _emitGame(
    String event, [
    Map<String, dynamic>? payload,
    void Function(Map<String, dynamic> ack)? onAck,
  ]) {
    final socket = _socket;
    if (socket == null) {
      _setGameNotice(_gameReasonMessages['not_connected']!);
      return;
    }
    socket.emitWithAck(
      event,
      payload ?? <String, dynamic>{},
      ack: (r) {
        final map = _m(r);
        final failed = map['ok'] == false || map['error'] != null;
        final rawReason = map['reason'] ?? map['error'];
        // 사유 없는 거부는 대개 이미 처리된 중복 요청(예: 두 기기가 동시에 보낸 타임아웃)이라 조용히 넘긴다.
        if (failed && rawReason != null) {
          final reason = '$rawReason';
          _log('$event 거부: $reason');
          if (!_silentGameReasons.contains(reason)) {
            _setGameNotice(
              _gameReasonMessages[reason] ?? '요청을 처리하지 못했어요. ($reason)',
            );
          }
        }
        onAck?.call(map);
      },
    );
  }

  void clearLobbyStart() {
    lobbyStartedGameType = null;
    notifyListeners();
  }

  void clearLobbyResume() {
    lobbyResumedGameType = null;
    notifyListeners();
  }

  void enterGameSession(String gameType) =>
      _socket?.emit('game:session:enter', {'gameType': gameType});

  void leaveGameSession(String gameType) =>
      _socket?.emit('game:session:leave', {'gameType': gameType});

  void rollDice() => _socket?.emit('game:dice:roll');

  void spinRoulette(List<String> options) =>
      _emitGame('game:roulette:spin', {'options': options});

  /// 내 항목을 서버에 올려 두면, 누가 돌리든 두 사람의 항목을 합쳐서 돌린다.
  void proposeRoulette(List<String> options) {
    if (options.length < 2 || options.length > 12) return;
    _socket?.emit('game:roulette:propose', {'options': options});
  }

  void playRps(String choice) {
    rpsResult = null;
    rpsChoices = null;
    notifyListeners();
    _socket?.emit('game:rps:select', {'choice': choice});
  }

  void startRpsGame(String mode) {
    _emitGame('game:rps:start', {'mode': mode});
  }

  void pickRps(String choice) {
    _emitGame('game:rps:pick', {'choice': choice});
  }

  void pickHanabagi(int fingers, int guess) {
    _emitGame('game:rps:pick', {'fingers': fingers, 'guess': guess});
  }

  void clearRpsRound() {
    rpsLastChoices = null;
    rpsLastFingers = null;
    rpsLastGuesses = null;
    rpsRoundWinner = null;
    notifyListeners();
  }

  /// 서버가 reset_done을 방 전체에 보내면 그때 상태를 비운다(낙관적 초기화 금지:
  /// 서버가 거부하면 화면과 서버 상태가 어긋난다).
  void resetRpsGame() {
    _emitGame('game:rps:reset');
  }

  /// [onMismatch]: 상대가 이미 다른 문제에 답해 둔 경우 서버가 그 문제의 보기를 알려준다.
  /// 화면은 같은 문제로 이동해 다시 고르게 한다(상대의 답을 버리지 않기 위해).
  void playTelepathy(
    String choice,
    List<String> options, {
    void Function(List<String> partnerOptions)? onMismatch,
  }) {
    telepathySuccess = null;
    telepathySelected = null;
    telepathyChoices = null;
    notifyListeners();
    _emitGame('game:telepathy:select', {'choice': choice, 'options': options}, (
      ack,
    ) {
      if (ack['reason'] == 'options_mismatch') {
        final raw = ack['options'];
        onMismatch?.call(
          raw is List ? raw.map((e) => '$e').toList() : const <String>[],
        );
      }
    });
  }

  void startPirate(int slots) {
    _emitGame('game:pirate:start', {'slots': slots});
  }

  void pickPirateSlot(int slot) {
    _emitGame('game:pirate:pick', {'slot': slot});
  }

  void resetPirate() {
    pirateActive = false;
    pirateCurrentTurn = null;
    piratePickedSlots = [];
    pirateLoser = null;
    pirateBombSlot = null;
    piratePlayers = [];
    notifyListeners();
    _emitGame('game:pirate:reset', {});
  }

  // ── blackjack ─────────────────────────────────────────────────────────────

  void startBlackjack() {
    _emitGame('game:blackjack:start', {});
  }

  void hitBlackjack() {
    _emitGame('game:blackjack:hit', {});
  }

  void standBlackjack() {
    _emitGame('game:blackjack:stand', {});
  }

  void nextBlackjackRound() {
    _emitGame('game:blackjack:next_round', {});
  }

  // ── oldmaid (도둑잡기) ──────────────────────────────────────────────────

  void startOldMaid({void Function(String reason)? onError}) {
    final socket = _socket;
    if (socket == null) {
      onError?.call('not_connected');
      return;
    }
    socket.emitWithAck(
      'game:oldmaid:start',
      {},
      ack: (r) {
        final map = _m(r);
        if (map['ok'] != true) {
          final reason = map['reason']?.toString() ?? 'unknown';
          _log('도둑잡기 시작 실패: $reason');
          onError?.call(reason);
        }
      },
    );
  }

  void drawOldMaidCard(String cardId) {
    _emitGame('game:oldmaid:draw', {'cardId': cardId});
  }

  // ── penalty (패널티킥) ──────────────────────────────────────────────────

  void startPenalty() {
    _emitGame('game:penalty:start', {});
  }

  void submitPenaltyChoice(int choice) {
    _emitGame('game:penalty:submit', {'choice': choice});
  }

  // ── bowling (볼링) ───────────────────────────────────────────────────────

  void startBowling() {
    _emitGame('game:bowling:start', {});
  }

  /// 투구: 서버가 같은 결정론적 시뮬레이션으로 핀 수를 정하고, 손 떨림이 반영된
  /// 실제 조준값(aim/curve)을 돌려준다. 화면은 그 값으로 연출해 점수와 일치시킨다.
  void throwBowling(
    double aim,
    double curve,
    void Function(double aim, double curve, int pins) onResult, {
    void Function()? onRejected,
  }) {
    _emitGame('game:bowling:roll', {'aim': aim, 'curve': curve}, (ack) {
      if (ack['ok'] == true) {
        onResult(
          (ack['aim'] as num?)?.toDouble() ?? aim,
          (ack['curve'] as num?)?.toDouble() ?? curve,
          (ack['pins'] as num?)?.toInt() ?? 0,
        );
      } else {
        onRejected?.call();
      }
    });
  }

  // ── tank 대작전 ───────────────────────────────────────────────────────────

  /// 판돈은 로비에서 합의된 값을 서버가 적용한다(클라이언트가 보내지 않는다).
  void startTank() {
    _emitGame('game:tank:new');
  }

  void selectTankClass(String tankClass) {
    _emitGame('game:tank:select', {'tankClass': tankClass});
  }

  void moveTank(int delta) {
    _emitGame('game:tank:move', {'delta': delta});
  }

  void aimTank(int angle, int power) {
    _socket?.emit('game:tank:aim', {'angle': angle, 'power': power});
  }

  void selectTankWeapon(String weapon) {
    _emitGame('game:tank:weapon', {'weapon': weapon});
  }

  /// 조준은 화면에서만 하고, 발사할 때 각도·파워·무기를 함께 보낸다
  /// (발사 전까지 상대에게 조준값이 공개되지 않는다).
  void fireTank({
    required int angle,
    required int power,
    required String weapon,
  }) {
    _emitGame('game:tank:fire', {
      'angle': angle,
      'power': power,
      'weapon': weapon,
    });
  }

  // ── 고스톱 (2인 맞고) ─────────────────────────────────────────────────────

  void _gostopEmit(String event, Map<String, dynamic>? payload) {
    _socket?.emitWithAck(
      event,
      payload,
      ack: (r) {
        final map = _m(r);
        if (map['ok'] != true) {
          gostopError =
              map['reason']?.toString() ??
              map['error']?.toString() ??
              '요청 처리에 실패했습니다.';
          _log('$event 실패: ${map['reason'] ?? map['error']}');
        } else {
          gostopError = null;
        }
        notifyListeners();
      },
    );
  }

  void startGostop({int perPointBet = 100}) =>
      _gostopEmit('game:gostop:new', {'perPointBet': perPointBet});

  void playGostopCard(String cardId) =>
      _gostopEmit('game:gostop:play', {'cardId': cardId});

  void pickGostopField(String fieldCardId) =>
      _gostopEmit('game:gostop:pick', {'fieldCardId': fieldCardId});

  void declareGostop(String decision) =>
      _gostopEmit('game:gostop:gostop', {'decision': decision});

  void declareGostopShake(String decision) =>
      _gostopEmit('game:gostop:shake', {'decision': decision});

  void playGostopBomb(int month) =>
      _gostopEmit('game:gostop:bomb', {'month': month});

  void retryGostopSettlement() =>
      _gostopEmit('game:gostop:settlement_retry', null);

  void requestGostopState() {
    _socket?.emitWithAck(
      'game:gostop:state',
      null,
      ack: (r) {
        final map = _m(r);
        if (map['ok'] == true) {
          _applyGostopState(_m(map['state']));
          gostopError = null;
        } else if (map['reason'] != 'no_game') {
          gostopError = map['reason']?.toString() ?? '게임 상태를 불러오지 못했습니다.';
        }
        notifyListeners();
      },
    );
  }

  void clearGostopError() {
    gostopError = null;
    notifyListeners();
  }

  void clearGostopNageori() {
    gostopNageoriMultiplier = null;
    notifyListeners();
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

  void setItemEffectCallback(Function(Map<String, dynamic>)? cb) =>
      _onItemEffect = cb;

  void startCatch({int maxRounds = 6}) {
    _emitGame('game:catch:start', {'maxRounds': maxRounds});
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
    _emitGame('game:catch:guess', {'text': text});
  }

  void requestCatchHint() {
    _emitGame('game:catch:hint_req');
  }

  void timeoutCatch() {
    _emitGame('game:catch:timeout');
  }

  void nextCatchRound() {
    _emitGame('game:catch:next');
  }

  /// 서버의 reset_done 이벤트가 오면 상태를 비운다(낙관적 초기화 금지).
  void resetCatch() {
    _emitGame('game:catch:reset');
  }

  void newYutGame({Map<String, String>? characters, String? bgm, int? stake}) {
    final payload = <String, dynamic>{};
    if (characters != null && characters.isNotEmpty) {
      payload['characters'] = characters;
    }
    if (bgm != null) payload['bgm'] = bgm;
    // 판돈은 서버가 로비 합의값으로 적용한다(payload의 stake는 무시됨).
    _emitGame('game:yut:new', payload);
  }

  void rollYutStartDice() => _emitGame('game:yut:roll_start');
  void throwYut() => _emitGame('game:yut:throw');
  void moveYut(int pieceId, {int moveIndex = 0, int? backdoDir}) {
    final payload = <String, dynamic>{
      'pieceId': pieceId,
      'moveIndex': moveIndex,
    };
    if (backdoDir != null) payload['backdoDir'] = backdoDir;
    _socket?.emitWithAck(
      'game:yut:move',
      payload,
      ack: (r) {
        final map = _m(r);
        if (map['ok'] == true) {
          // The room broadcast normally updates this state first. Applying
          // the ACK as well prevents the mover's board from staying stale
          // when a room event is delayed or missed during a reconnect.
          final event = _m(map['event'] ?? map['gameState']);
          if (event.isNotEmpty) _applyYutMoveResult(event);
        } else {
          _log('윷 말 이동 실패: ${map['reason'] ?? map['error']}');
        }
        notifyListeners();
      },
    );
  }

  void sendYutChat(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    _socket?.emit('game:yut:chat', {'message': trimmed});
  }

  void sendMarbleChat(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    _socket?.emit('game:marble:chat', {'message': trimmed});
  }

  // ─── marble emit ─────────────────────────────────────────────────────────────

  void newMarbleGame({Map<String, String>? characters}) {
    final payload = <String, dynamic>{};
    if (characters != null && characters.isNotEmpty) {
      payload['characters'] = characters;
    }
    _emitGame('game:marble:new', payload);
  }

  void rollMarbleStartDice() => _emitGame('game:marble:roll_start');
  void rollMarble() => _emitGame('game:marble:roll');

  void moveMarble(int pieceId, {int moveIndex = 0}) {
    final payload = <String, dynamic>{
      'pieceId': pieceId,
      'moveIndex': moveIndex,
    };
    _emitGame('game:marble:move', payload);
  }

  void actMarbleLand(String action, int pos) {
    marbleLandPrompt = null;
    _emitGame('game:marble:land_act', {'action': action, 'pos': pos});
  }

  void dismissMarbleLandPrompt() {
    marbleLandPrompt = null;
    notifyListeners();
  }

  void setUnoMode(String mode) {
    if (mode != 'classic' && mode != 'go_wild') return;
    selectedUnoMode = mode;
    notifyListeners();
  }

  void newUnoGame({String? mode, int? stake}) {
    final finalStake = stake ?? (lobbyStartedStake > 0 ? lobbyStartedStake : 0);
    _emitGame('game:uno:new', {
      'mode': mode ?? selectedUnoMode,
      if (finalStake > 0) 'stake': finalStake,
    });
  }

  void playUnoCard(String cardId, {String? color}) {
    final payload = {'cardId': cardId};
    if (color != null) {
      payload['declaredColor'] = color;
    }
    _emitGame('game:uno:play', payload);
  }

  void drawUnoCard() => _emitGame('game:uno:draw');
  void passUnoDrawChoice() =>
      _emitGame('game:uno:draw_decision', {'play': false});
  void callUno() => _emitGame('game:uno:call');
  void catchUno() => _emitGame('game:uno:catch');
  void pressUnoButton() {
    if (unoPendingCall) {
      callUno();
      return;
    }
    if (unoCatchable) {
      catchUno();
    }
  }

  void challengeDraw4() => _emitGame('game:uno:challenge');
  void discardAllUno() => _socket?.emit('game:uno:discard_all');
  void sendUnoReaction(String type) =>
      _socket?.emit('game:uno:reaction', {'type': type});

  void newBombGame({int duration = 30}) =>
      _emitGame('game:bomb:new', {'duration': duration});
  void answerBomb(String answer) {
    bombLastAnswerCorrect = null;
    notifyListeners();
    _emitGame('game:bomb:answer', {'answer': answer});
  }

  @visibleForTesting
  void restoreGamesForTest(Map<String, dynamic> games) => _restoreGames(games);

  void _restoreGames(Map<String, dynamic> games) {
    try {
      // 끊긴 동안 끝난 이어하기 게임이 "진행 중"으로 남지 않도록 응답에 없는 게임은 비활성화한다.
      if (!games.containsKey('yut')) yutActive = false;
      if (!games.containsKey('uno')) unoActive = false;
      if (!games.containsKey('marble')) marbleActive = false;
      if (!games.containsKey('bomb')) bombActive = false;
      if (!games.containsKey('gostop') && !gostopSettlementPending) {
        gostopActive = false;
      }
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
        final drawnCardId = uno['drawnCardId'] as String?;
        unoDrawChoiceCard = null;
        if (drawnCardId != null) {
          for (final rawCard in unoHand) {
            final card = _cardMap(rawCard);
            if (card?['id'] == drawnCardId) {
              unoDrawChoiceCard = card;
              break;
            }
          }
        }
        unoCanPlayDrawn = unoDrawChoiceCard != null;
        _log('UNO 복원');
      }
      if (games.containsKey('gostop')) {
        _applyGostopState(_m(games['gostop']));
        _log('고스톱 복원');
      }
      if (games.containsKey('bomb')) {
        final bomb = _m(games['bomb']);
        bombActive = true;
        bombCurrentPlayer = bomb['currentPlayer'] as String?;
        bombDuration = (bomb['timer'] as num?)?.toInt();
        bombQuestion = bomb['question'] as String? ?? bombQuestion;
        bombStartTime = (bomb['startTime'] as num?)?.toInt() ?? bombStartTime;
        bombCategory = bomb['category'] as String? ?? bombCategory;
        _log('폭탄 복원');
      }
      // 마블 게임 복원
      if (games.containsKey('marble')) {
        _applyMarbleState(_m(games['marble']));
        _log('마블 작전 복원');
      }
    } catch (e, stack) {
      _log('게임 복원 중 에러 발생: $e\n$stack');
    }
    notifyListeners();
  }

  void _applyGostopState(Map<String, dynamic> map) {
    gostopState = map;
    gostopSettlement = map['settlement'] is Map
        ? Map<String, dynamic>.from(map['settlement'] as Map)
        : null;
    gostopSettlementPending = map['settlementStatus'] == 'pending';
    gostopActive = map['phase'] != 'finished' || gostopSettlementPending;
  }

  void _log(String msg) {
    _logs.insert(0, msg);
    if (_logs.length > 100) _logs.removeLast();
    log('[SocketService] $msg');
  }

  Future<void> _loadProfileEmoji() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      profileEmoji = prefs.getString(_profileEmojiKey) ?? defaultProfileEmoji;
      notifyListeners();
    } catch (error, stack) {
      // Widget tests and early platform startup may not have a preferences
      // channel yet; the in-memory default is still a valid profile state.
      _log('프로필 이모지 저장소를 불러오지 못함: $error\n$stack');
    }
  }

  void _applyYutState(Map<String, dynamic> map) {
    final nextGameId = map['id'] as String? ?? yutGameId ?? 'active';
    if (nextGameId != yutGameId) {
      yutChatMessages = [];
    }
    yutActive = true;
    yutGameId = nextGameId;
    yutPhase = map['phase'] as String? ?? yutPhase ?? 'throwing';
    yutCurrentTurn = map['currentTurn'] as String?;
    yutCharacters = _stringMap(map['characters']);
    final equippedRaw = map['equippedItems'];
    if (equippedRaw is Map) {
      yutEquippedItems = equippedRaw.map(
        (k, v) => MapEntry('$k', v is Map ? Map<String, dynamic>.from(v) : {}),
      );
    }
    yutHasBonusThrow = map['hasBonusThrow'] == true;
    yutBgm = map['bgm'] as String? ?? yutBgm;
    yutOrderCountdownUntil = (map['orderCountdownUntil'] as num?)?.toInt();
    yutStartRolls = _m(map['startRolls'] ?? yutStartRolls);
    final pending = map['pendingMoves'];
    yutPendingMoves = pending is List ? List<dynamic>.from(pending) : [];
    final turnThrows = map['turnThrows'];
    if (turnThrows is List) {
      yutTurnThrows = turnThrows
          .whereType<Map>()
          .map((throwResult) => Map<String, dynamic>.from(throwResult))
          .toList();
    } else if (map.containsKey('turnThrows')) {
      yutTurnThrows = [];
    }
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
          pieces
              .map((piece) {
                if (piece is Map) {
                  final pos = piece['position'];
                  return (pos is num) ? pos.toInt() : 0;
                }
                if (piece is num) return piece.toInt();
                return 0;
              })
              .toList()
              .cast<int>(),
        ),
      );
    }
  }

  void _applyYutMoveResult(Map<String, dynamic> map) {
    _applyYutState(map);
    yutLastMoveBy = map['by'] as String?;
    yutLastMoveAt =
        (map['at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
    yutLastCapturedCount = (map['capturedCount'] as num?)?.toInt() ?? 0;
    yutLastCaptureBlockedCount =
        (map['captureBlockedCount'] as num?)?.toInt() ?? 0;
    yutLastCarriedCount = (map['carriedCount'] as num?)?.toInt() ?? 0;
    yutLastStackedCount = (map['stackedCount'] as num?)?.toInt() ?? 0;
    if (map['winner'] != null) {
      yutWinner = map['winner'] as String?;
      yutActive = false;
    }
  }

  void _applyMarbleState(Map<String, dynamic> map) {
    final nextGameId = map['id'] as String? ?? marbleGameId ?? 'active';
    if (nextGameId != marbleGameId) {
      marbleChatMessages = [];
      // 새 판: 이전 판 결과가 다시 뜨지 않게 지운다.
      marbleWinner = null;
      marbleWinReason = null;
    }
    marbleActive = true;
    marbleGameId = nextGameId;
    marblePhase = map['phase'] as String? ?? marblePhase ?? 'throwing';
    marbleCurrentTurn = map['currentTurn'] as String?;
    marbleCharacters = _stringMap(map['characters']);
    marbleHasDoubleRoll = map['hasDoubleRoll'] == true;
    marbleOrderCountdownUntil = (map['orderCountdownUntil'] as num?)?.toInt();
    marbleStartRolls = _m(map['startRolls'] ?? marbleStartRolls);
    final pending = map['pendingMoves'];
    marblePendingMoves = pending is List ? List<dynamic>.from(pending) : [];
    marbleRound = (map['round'] as num?)?.toInt() ?? marbleRound;
    final pendingLand = _m(map['pendingLandAction']);
    if (pendingLand['userId'] == userId) {
      marbleLandPrompt = Map<String, dynamic>.from(pendingLand)
        ..remove('userId');
    } else if (map.containsKey('pendingLandAction') && pendingLand.isEmpty) {
      marbleLandPrompt = null;
    }
    if (map['winner'] != null) {
      marbleWinner = map['winner'] as String?;
      marbleWinReason = map['winReason'] as String?;
      marbleActive = false;
    }
    final playersRaw = map['players'];
    if (playersRaw is List) {
      marblePlayers = playersRaw.map((e) => '$e').toList();
    }
    final piecesRaw = _m(map['pieces']);
    if (piecesRaw.isNotEmpty) {
      marblePieceDetails = piecesRaw.map(
        (player, value) => MapEntry(player, value is List ? value : []),
      );
    }
    final landsRaw = map['lands'];
    if (landsRaw is Map) {
      marbleLands = Map<String, dynamic>.from(landsRaw);
    }
    final coinsRaw = map['coins'];
    if (coinsRaw is Map) {
      marbleCoins = coinsRaw.map(
        (k, v) => MapEntry('$k', (v as num?)?.toInt() ?? 0),
      );
    }
    final assetsRaw = map['assets'];
    if (assetsRaw is Map) {
      marbleAssets = assetsRaw.map(
        (k, v) => MapEntry('$k', (v as num?)?.toInt() ?? 0),
      );
    }
    final equippedRaw = map['equippedItems'];
    if (equippedRaw is Map) {
      marbleEquippedItems = equippedRaw.map(
        (k, v) => MapEntry('$k', v is Map ? Map<String, dynamic>.from(v) : {}),
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

  /// 로비 옵션: 숫자는 int로, 문자열은 그대로. 그 외 값은 버린다.
  static Map<String, Object> _optionMap(dynamic v) {
    final out = <String, Object>{};
    _m(v).forEach((key, value) {
      if (value is num) {
        out[key] = value.toInt();
      } else if (value is String) {
        out[key] = value;
      }
    });
    return out;
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

/// 공용 리액션 한 건(게임 2.0).
class GameReaction {
  final String by;
  final String emoji;
  final String? gameType;
  final int at;

  const GameReaction({
    required this.by,
    required this.emoji,
    required this.gameType,
    required this.at,
  });
}
