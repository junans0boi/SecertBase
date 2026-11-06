// 해적 룰렛·제로·그림 맞히기·고스톱의 전용 대기실: 옵션은 방장만 고르고, 상대는 읽기만 하며,
// 판돈이 걸린 고스톱은 상대가 "준비 완료"로 동의해야 시작할 수 있다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/game_lobby_screen.dart';
import 'package:secret_base_app/screens/arcade/games/catch/catch_lobby.dart';
import 'package:secret_base_app/screens/arcade/games/gostop/gostop_lobby.dart';
import 'package:secret_base_app/screens/arcade/games/pirate/pirate_lobby.dart';
import 'package:secret_base_app/screens/arcade/games/zero/zero_lobby.dart';
import 'package:secret_base_app/screens/arcade/lobby_kit.dart';
import 'package:secret_base_app/screens/arcade/lobby_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sizes = [Size(360, 640), Size(390, 844), Size(1000, 700)];

Future<void> _pump(
  WidgetTester tester,
  Widget w, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: w));
  await tester.pump(const Duration(milliseconds: 300));
}

/// 하단 주 버튼 안의 글자만(같은 글자의 상태 표시와 구분).
Finder _button(String label) => find.descendant(
  of: find.byType(LobbyMainButton),
  matching: find.text(label),
);

/// 카운트다운의 큰 숫자.
Finder _count(int n) => find.byWidgetPredicate(
  (w) => w is Text && w.data == '$n' && w.style?.fontSize == 96,
);

/// 버튼 글자에서 위로 올라가며 InkWell을 찾아 눌릴 수 있는지(onTap) 본다.
bool _tappable(WidgetTester tester, String label) {
  final ink = find.ancestor(
    of: find.text(label),
    matching: find.byType(InkWell),
  );
  expect(ink, findsOneWidget, reason: '$label button');
  return tester.widget<InkWell>(ink).onTap != null;
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  final nicks = {'YOU': '하린'};

  Widget pirate({
    bool host = true,
    int holes = 8,
    bool two = true,
    bool canStart = true,
    String label = '게임 시작',
    ValueChanged<int>? onHoles,
    VoidCallback? onStart,
    VoidCallback? onBack,
    VoidCallback? onHelp,
  }) => PirateLobbyView(
    holesDef: lobbyOptionsFor('pirate').single,
    holesValue: holes,
    players: two ? ['ME', 'YOU'] : ['ME'],
    host: 'ME',
    me: host ? 'ME' : 'YOU',
    nicknames: nicks,
    isHost: host,
    canStart: canStart,
    startLabel: label,
    onHoles: onHoles ?? (_) {},
    onStart: onStart ?? () {},
    onBack: onBack ?? () {},
    onHelp: onHelp,
  );

  Widget zero({
    bool host = true,
    bool two = true,
    bool canStart = true,
    String label = '게임 시작',
    VoidCallback? onStart,
  }) => ZeroLobbyView(
    players: two ? ['ME', 'YOU'] : ['ME'],
    host: 'ME',
    me: host ? 'ME' : 'YOU',
    nicknames: nicks,
    isHost: host,
    canStart: canStart,
    startLabel: label,
    onStart: onStart ?? () {},
    onBack: () {},
    onHelp: () {},
  );

  Widget catchGame({
    bool host = true,
    int rounds = 6,
    bool two = true,
    bool canStart = true,
    String label = '게임 시작',
    ValueChanged<int>? onRounds,
    VoidCallback? onStart,
  }) => CatchLobbyView(
    roundsDef: lobbyOptionsFor('catch').single,
    roundsValue: rounds,
    players: two ? ['ME', 'YOU'] : ['ME'],
    host: 'ME',
    me: host ? 'ME' : 'YOU',
    nicknames: nicks,
    isHost: host,
    canStart: canStart,
    startLabel: label,
    onRounds: onRounds ?? (_) {},
    onStart: onStart ?? () {},
    onBack: () {},
    onHelp: () {},
  );

  Widget gostop({
    bool host = true,
    int stake = 0,
    bool guestReady = false,
    bool two = true,
    bool? canStart,
    String? label,
    ValueChanged<int>? onStake,
    ValueChanged<bool>? onReady,
    VoidCallback? onStart,
  }) {
    final can = canStart ?? (host && two && (stake == 0 || guestReady));
    return GostopLobbyView(
      players: two ? ['ME', 'YOU'] : ['ME'],
      host: 'ME',
      me: host ? 'ME' : 'YOU',
      nicknames: nicks,
      ready: {'YOU': guestReady},
      stake: stake,
      isHost: host,
      canStart: can,
      startLabel:
          label ??
          (can
              ? '게임 시작'
              : two
              ? '상대의 판돈 동의를 기다리는 중'
              : '상대방을 기다리는 중'),
      onStake: onStake ?? (_) {},
      onReady: onReady ?? (_) {},
      onStart: onStart ?? () {},
      onBack: () {},
      onHelp: () {},
    );
  }

  group('fits every window without overflow', () {
    for (final size in _sizes) {
      final tag = '${size.width.toInt()}x${size.height.toInt()}';
      for (final host in [true, false]) {
        final who = host ? 'host' : 'guest';
        testWidgets('pirate $who $tag', (tester) async {
          await _pump(tester, pirate(host: host), size: size);
          expect(tester.takeException(), isNull);
          expect(find.text('해적 룰렛'), findsOneWidget);
          expect(find.text('보통'), findsOneWidget);
        });
        testWidgets('zero $who $tag', (tester) async {
          await _pump(tester, zero(host: host), size: size);
          expect(tester.takeException(), isNull);
          expect(find.text('두 사람 합계를 예측해요'), findsOneWidget);
        });
        testWidgets('catch $who $tag', (tester) async {
          await _pump(tester, catchGame(host: host), size: size);
          expect(tester.takeException(), isNull);
          expect(find.text('번갈아 그리고,\n그림으로 맞혀요'), findsOneWidget);
        });
        testWidgets('gostop $who $tag', (tester) async {
          await _pump(tester, gostop(host: host, stake: 500), size: size);
          expect(tester.takeException(), isNull);
          expect(find.text('판돈 · 1점당'), findsOneWidget);
        });
      }
    }
    testWidgets('lone host with nobody else yet', (tester) async {
      for (final w in [
        pirate(two: false, canStart: false, label: '상대방을 기다리는 중'),
        zero(two: false, canStart: false, label: '상대방을 기다리는 중'),
        catchGame(two: false, canStart: false, label: '상대방을 기다리는 중'),
        gostop(two: false),
      ]) {
        await _pump(tester, w, size: const Size(360, 640));
        expect(tester.takeException(), isNull);
        expect(find.text('비어 있음'), findsOneWidget);
        expect(find.text('상대방을 기다리는 중'), findsOneWidget);
        expect(_tappable(tester, '상대방을 기다리는 중'), isFalse);
      }
    });
  });

  group('pirate', () {
    testWidgets('host picks the hole count, the guest only reads it', (
      tester,
    ) async {
      final picked = <int>[];
      await _pump(tester, pirate(onHoles: picked.add));
      await tester.tap(find.text('짧게'));
      await tester.tap(find.text('길게'));
      await tester.tap(find.text('보통')); // 이미 고른 칸은 다시 안 눌린다
      expect(picked, [6, 12]);
      expect(find.text('첫 폭탄 확률 17%'), findsOneWidget);
      expect(find.text('첫 폭탄 확률 13%'), findsOneWidget);
      expect(find.text('첫 폭탄 확률 8%'), findsOneWidget);

      final guest = <int>[];
      await _pump(
        tester,
        pirate(host: false, holes: 12, canStart: false, onHoles: guest.add),
      );
      await tester.tap(find.text('짧게'), warnIfMissed: false);
      expect(guest, isEmpty);
      expect(find.text('방장이 구멍 수를 골랐어요'), findsOneWidget);
      expect(find.text('방장이 시작할 때까지 기다려 주세요'), findsOneWidget);
      expect(find.text('게임 시작'), findsNothing);
    });

    testWidgets('options and start work through accessibility taps too', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final picked = <int>[];
      var started = 0;
      await _pump(
        tester,
        pirate(onHoles: picked.add, onStart: () => started++),
      );
      tester.semantics.tap(find.semantics.byLabel('12구멍, 길게, 첫 폭탄 확률 8%'));
      tester.semantics.tap(find.semantics.byLabel('게임 시작'));
      await tester.pump();
      expect(picked, [12]);
      expect(started, 1);
      handle.dispose();
    });

    testWidgets('start button state and back/help callbacks', (tester) async {
      var started = 0, back = 0, help = 0;
      await _pump(
        tester,
        pirate(
          canStart: false,
          label: '상대방을 기다리는 중',
          onStart: () => started++,
          onBack: () => back++,
          onHelp: () => help++,
        ),
      );
      expect(_tappable(tester, '상대방을 기다리는 중'), isFalse);
      await tester.tap(find.text('상대방을 기다리는 중'), warnIfMissed: false);
      expect(started, 0);
      await tester.tap(find.byTooltip('게임 나가기'));
      await tester.tap(find.byTooltip('규칙 보기'));
      expect([back, help], [1, 1]);

      await _pump(tester, pirate(onStart: () => started++));
      expect(_tappable(tester, '게임 시작'), isTrue);
      await tester.tap(find.text('게임 시작'));
      expect(started, 1);
    });
  });

  group('zero', () {
    testWidgets('has no options; only the host can start', (tester) async {
      var started = 0;
      await _pump(tester, zero(onStart: () => started++));
      expect(find.text('손가락 0~5개를 비공개로 고르고'), findsOneWidget);
      expect(find.text('나'), findsWidgets); // 아바타 글자 + 이름
      expect(find.text('하린'), findsOneWidget);
      await tester.tap(find.text('게임 시작'));
      expect(started, 1);

      await _pump(tester, zero(host: false, canStart: false));
      expect(find.text('방장이 시작할 때까지 기다려 주세요'), findsOneWidget);
      expect(_tappable(tester, '방장이 시작할 때까지 기다려 주세요'), isFalse);
    });
  });

  group('catch', () {
    testWidgets('host picks the round count, the guest only reads it', (
      tester,
    ) async {
      final picked = <int>[];
      await _pump(tester, catchGame(onRounds: picked.add));
      expect(find.text('한 사람이 세 번씩 그려요'), findsOneWidget);
      await tester.tap(find.text('짧게'));
      await tester.tap(find.text('길게'));
      await tester.tap(find.text('보통'));
      expect(picked, [4, 8]);

      final guest = <int>[];
      await _pump(
        tester,
        catchGame(host: false, rounds: 8, canStart: false, onRounds: guest.add),
      );
      expect(find.text('한 사람이 네 번씩 느긋하게'), findsOneWidget);
      expect(find.text('방장이 고른 설정'), findsOneWidget);
      await tester.tap(find.text('짧게'), warnIfMissed: false);
      expect(guest, isEmpty);
      expect(find.text('방장이 시작할 때까지 기다려 주세요'), findsOneWidget);
    });

    testWidgets('round choice works through accessibility taps too', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final picked = <int>[];
      await _pump(tester, catchGame(onRounds: picked.add));
      tester.semantics.tap(find.semantics.byLabel('8라운드, 길게, 한 사람이 네 번씩 느긋하게'));
      await tester.pump();
      expect(picked, [8]);
      handle.dispose();
    });
  });

  group('gostop', () {
    testWidgets('free game: host starts, guest just waits', (tester) async {
      var started = 0;
      await _pump(tester, gostop(onStart: () => started++));
      expect(find.text('판돈 없이 가볍게 즐겨요.'), findsOneWidget);
      expect(find.text('상대가 준비를 마쳤어요'), findsNothing);
      await tester.tap(find.text('게임 시작'));
      expect(started, 1);

      await _pump(tester, gostop(host: false, canStart: false));
      expect(find.text('방장이 시작할 때까지 기다려 주세요'), findsOneWidget);
      expect(find.text('준비 완료'), findsWidgets); // 두 사람 모두 준비 완료 표시
    });

    testWidgets('host picks the stake, the guest only reads it', (
      tester,
    ) async {
      final stakes = <int>[];
      await _pump(tester, gostop(stake: 100, onStake: stakes.add));
      await tester.tap(find.text('500'));
      await tester.tap(find.text('1,000'));
      await tester.tap(find.text('무료'));
      await tester.tap(find.text('100')); // 이미 고른 칸은 다시 안 눌린다
      expect(stakes, [500, 1000, 0]);
      expect(find.textContaining('7점 스톱이면 700코인부터'), findsOneWidget);

      final guest = <int>[];
      await _pump(
        tester,
        gostop(host: false, stake: 500, canStart: false, onStake: guest.add),
      );
      await tester.tap(find.text('100'), warnIfMissed: false);
      expect(guest, isEmpty);
      expect(find.text('방장이 고른 설정'), findsOneWidget);
    });

    testWidgets('guest must agree with 준비 완료 when a stake is set', (
      tester,
    ) async {
      final ready = <bool>[];
      await _pump(
        tester,
        gostop(host: false, stake: 500, canStart: false, onReady: ready.add),
      );
      expect(find.text('동의 대기 중'), findsOneWidget);
      expect(find.textContaining('1점에 500코인이 걸려 있어요'), findsOneWidget);
      expect(find.text('방장이 시작할 때까지 기다려 주세요'), findsNothing);
      await tester.tap(_button('준비 완료'));
      expect(ready, [true]);

      // 동의한 뒤에는 취소 버튼이 된다.
      await _pump(
        tester,
        gostop(
          host: false,
          stake: 500,
          guestReady: true,
          canStart: false,
          onReady: ready.add,
        ),
      );
      expect(find.textContaining('500코인 판돈에 동의했어요'), findsOneWidget);
      await tester.tap(_button('준비 완료 취소'));
      expect(ready, [true, false]);
    });

    testWidgets('guest agreement works through accessibility taps too', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final ready = <bool>[];
      await _pump(
        tester,
        gostop(host: false, stake: 100, canStart: false, onReady: ready.add),
      );
      tester.semantics.tap(find.semantics.byLabel('준비 완료'));
      await tester.pump();
      expect(ready, [true]);
      handle.dispose();
    });

    testWidgets('host start waits for the guest to agree', (tester) async {
      var started = 0;
      await _pump(tester, gostop(stake: 500, onStart: () => started++));
      expect(find.text('상대가 판돈에 동의하면 시작할 수 있어요'), findsOneWidget);
      expect(find.text('상대의 판돈 동의를 기다리는 중'), findsOneWidget);
      expect(_tappable(tester, '상대의 판돈 동의를 기다리는 중'), isFalse);
      await tester.tap(find.text('상대의 판돈 동의를 기다리는 중'), warnIfMissed: false);
      expect(started, 0);

      await _pump(
        tester,
        gostop(stake: 500, guestReady: true, onStart: () => started++),
      );
      expect(find.text('상대가 준비를 마쳤어요'), findsOneWidget);
      expect(_tappable(tester, '게임 시작'), isTrue);
      await tester.tap(find.text('게임 시작'));
      expect(started, 1);
    });
  });

  group('inside GameLobbyScreen', () {
    Future<SocketService> pumpLobby(
      WidgetTester tester, {
      required String gameType,
      required bool host,
      Map<String, Object> options = const {},
      int stake = 0,
      Map<String, bool> ready = const {},
      Size size = const Size(390, 844),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final socket = SocketService();
      void join(String type) {
        socket.userId = host ? 'ME' : 'YOU';
        socket.lobbyGameType = type;
        socket.lobbyHost = 'ME';
        socket.lobbyPlayers = ['ME', 'YOU'];
        socket.lobbyOptions = options;
        socket.lobbyStake = stake;
        socket.lobbyReady = ready;
        socket.lobbyStartedGameType = null;
        socket.presenceNicknames = {'YOU': '하린'};
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        socket.notifyListeners();
      }

      await tester.pumpWidget(
        MaterialApp(
          home: GameLobbyScreen(
            gameType: gameType,
            title: '테스트',
            description: '테스트',
            emoji: '🎮',
            color: Colors.teal,
            backgroundColor: Colors.teal.shade50,
            gameScreen: const SizedBox(),
            onJoinLobby: join,
          ),
        ),
      );
      await tester.pump();
      return socket;
    }

    testWidgets('pirate: host option change reaches the lobby state', (
      tester,
    ) async {
      final socket = await pumpLobby(tester, gameType: 'pirate', host: true);
      expect(find.byType(PirateLobbyView), findsOneWidget);
      expect(find.byType(LobbyOptionPicker), findsNothing);
      await tester.tap(find.text('짧게'));
      await tester.pump();
      expect(socket.lobbyOptions['holes'], 6);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pirate: guest sees the host choice read-only', (tester) async {
      final socket = await pumpLobby(
        tester,
        gameType: 'pirate',
        host: false,
        options: {'holes': 12},
      );
      await tester.tap(find.text('짧게'), warnIfMissed: false);
      await tester.pump();
      expect(socket.lobbyOptions['holes'], 12);
      expect(find.text('방장이 시작할 때까지 기다려 주세요'), findsOneWidget);
    });

    testWidgets('catch: host rounds change reaches the lobby state', (
      tester,
    ) async {
      final socket = await pumpLobby(tester, gameType: 'catch', host: true);
      expect(find.byType(CatchLobbyView), findsOneWidget);
      await tester.tap(find.text('길게'));
      await tester.pump();
      expect(socket.lobbyOptions['rounds'], 8);
    });

    testWidgets('zero: themed lobby, host can start', (tester) async {
      await pumpLobby(tester, gameType: 'zero', host: true);
      expect(find.byType(ZeroLobbyView), findsOneWidget);
      expect(find.text('게임 시작'), findsOneWidget);
      expect(_tappable(tester, '게임 시작'), isTrue);
    });

    testWidgets('gostop: stake agreement flow end to end', (tester) async {
      final socket = await pumpLobby(tester, gameType: 'gostop', host: false);
      expect(find.byType(GostopLobbyView), findsOneWidget);
      expect(find.text('방장이 시작할 때까지 기다려 주세요'), findsOneWidget);

      // 방장이 판돈을 걸었다.
      socket.lobbyStake = 500;
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      socket.notifyListeners();
      await tester.pump();
      expect(find.text('동의 대기 중'), findsOneWidget);
      await tester.tap(_button('준비 완료'));
      await tester.pump();
      expect(socket.lobbyReady['YOU'], isTrue);
      expect(_button('준비 완료 취소'), findsOneWidget);
      await tester.tap(_button('준비 완료 취소'));
      await tester.pump();
      expect(socket.lobbyReady['YOU'], isFalse);
    });

    testWidgets('gostop: host start waits until the guest agrees', (
      tester,
    ) async {
      final socket = await pumpLobby(
        tester,
        gameType: 'gostop',
        host: true,
        stake: 100,
      );
      expect(find.text('상대의 판돈 동의를 기다리는 중'), findsOneWidget);
      expect(_tappable(tester, '상대의 판돈 동의를 기다리는 중'), isFalse);
      await tester.tap(find.text('500'));
      await tester.pump();
      expect(socket.lobbyStake, 500);

      socket.lobbyReady = {'YOU': true};
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      socket.notifyListeners();
      await tester.pump();
      expect(find.text('게임 시작'), findsOneWidget);
      expect(_tappable(tester, '게임 시작'), isTrue);
    });

    for (final game in ['pirate', 'zero', 'catch', 'gostop']) {
      testWidgets('$game: help opens the rules and the back button pops', (
        tester,
      ) async {
        await pumpLobby(tester, gameType: game, host: true);
        await tester.tap(find.byTooltip('규칙 보기'));
        await tester.pumpAndSettle();
        expect(find.text('알겠어요'), findsOneWidget);
        await tester.tap(find.text('알겠어요'));
        await tester.pumpAndSettle();
        expect(find.text('알겠어요'), findsNothing);
        expect(find.byTooltip('게임 나가기'), findsOneWidget);
      });
    }

    for (final game in ['pirate', 'zero', 'catch', 'gostop']) {
      testWidgets('$game: start countdown overlay shows over the lobby', (
        tester,
      ) async {
        final socket = await pumpLobby(tester, gameType: game, host: true);
        socket.lobbyStartedGameType = game;
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        socket.notifyListeners();
        await tester.pump();
        expect(_count(5), findsOneWidget);
        expect(find.text('게임 시작!'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        expect(_count(4), findsOneWidget);
        // 화면을 치워 타이머를 멈춘다.
        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}
