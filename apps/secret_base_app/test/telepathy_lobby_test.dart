// 텔레파시 로비: 문제 수·질문 수위를 방장만 바꾸고, 19+는 경고와 상대(비방장)의 동의가 있어야 시작한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/game_lobby_screen.dart';
import 'package:secret_base_app/screens/arcade/games/telepathy/telepathy_lobby.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  Widget view({
    bool isHost = true,
    bool two = true,
    int rounds = 10,
    String heat = 'mild',
    bool partnerAccepted = false,
    bool iAccepted = false,
    bool canStart = true,
    String label = '시작하기',
    ValueChanged<int>? onRounds,
    ValueChanged<String>? onHeat,
    VoidCallback? onStart,
    ValueChanged<bool>? onAccept,
  }) => MaterialApp(
    home: TelepathyLobbyView(
      isHost: isHost,
      hasTwoPlayers: two,
      myName: '민지',
      partnerName: '준호',
      rounds: rounds,
      heat: heat,
      partnerAccepted: partnerAccepted,
      iAccepted: iAccepted,
      canStart: canStart,
      startLabel: label,
      onBack: () {},
      onRounds: onRounds ?? (_) {},
      onHeat: onHeat ?? (_) {},
      onStart: onStart ?? () {},
      onAccept: onAccept ?? (_) {},
    ),
  );

  Future<void> pump(
    WidgetTester tester,
    Widget w, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(w);
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final size in const [Size(360, 640), Size(390, 844), Size(1000, 700)]) {
    for (final heat in ['mild', 'nuclear']) {
      testWidgets(
        'lobby fits ${size.width.toInt()}x${size.height.toInt()} at $heat',
        (tester) async {
          await pump(tester, view(heat: heat), size: size);
          expect(tester.takeException(), isNull);
          expect(find.text('질문 수위'), findsOneWidget);
          expect(find.text('시작하기'), findsOneWidget);
          expect(find.text('같은 마음인지\n확인해 볼까요?'), findsOneWidget);
        },
      );
    }
  }

  testWidgets('the host changes rounds and heat, the guest only sees them', (
    tester,
  ) async {
    final rounds = <int>[];
    final heats = <String>[];
    await pump(
      tester,
      view(onRounds: rounds.add, onHeat: heats.add),
      size: const Size(390, 1000),
    );
    await tester.tap(find.bySemanticsLabel('15, 천천히'));
    await tester.tap(find.bySemanticsLabel('살짝 매운맛, 분위기 있게'));
    await tester.tap(find.bySemanticsLabel('핵폭탄 매운맛, 🔞 19+'));
    expect(rounds, [15]);
    expect(heats, ['spicy', 'nuclear']);

    final guestRounds = <int>[];
    await pump(
      tester,
      view(isHost: false, onRounds: guestRounds.add, canStart: false),
      size: const Size(390, 1000),
    );
    await tester.tap(find.bySemanticsLabel('15, 천천히'), warnIfMissed: false);
    expect(guestRounds, isEmpty);
    expect(find.text('방장이 시작할 때까지 기다려 주세요'), findsOneWidget);
    expect(find.text('시작하기'), findsNothing);
  });

  testWidgets('19+ shows a clear adult warning only for that level', (
    tester,
  ) async {
    await pump(tester, view(heat: 'spicy'), size: const Size(390, 1000));
    expect(find.textContaining('19+ 성인 전용'), findsNothing);
    expect(find.text('분위기 있는 스킨십·장소·속옷 취향'), findsOneWidget);
    expect(find.textContaining('BDSM'), findsNothing);
    await pump(
      tester,
      view(heat: 'nuclear', canStart: false, label: '상대의 동의를 기다리는 중'),
      size: const Size(390, 1000),
    );
    expect(find.text('🔞 19+ 성인 전용'), findsOneWidget);
    expect(find.textContaining('만 19세 이상'), findsOneWidget);
    expect(find.textContaining('BDSM'), findsWidgets);
    expect(find.textContaining('하드한 성인 질문'), findsWidgets);
    expect(find.text('상대의 동의를 기다리는 중이에요'), findsOneWidget);
    expect(
      find.text('상대의 동의를 기다리는 중'),
      findsOneWidget,
      reason: 'start button label',
    );
    expect(find.text('동의 대기'), findsOneWidget);
  });

  testWidgets('19+ start only works after the guest accepted', (tester) async {
    var started = 0;
    await pump(
      tester,
      view(
        heat: 'nuclear',
        canStart: false,
        label: '상대의 동의를 기다리는 중',
        onStart: () => started++,
      ),
      size: const Size(390, 1000),
    );
    await tester.tap(find.text('상대의 동의를 기다리는 중'), warnIfMissed: false);
    expect(started, 0);

    await pump(
      tester,
      view(heat: 'nuclear', partnerAccepted: true, onStart: () => started++),
      size: const Size(390, 1000),
    );
    expect(find.text('상대가 동의했어요'), findsOneWidget);
    expect(find.text('동의 완료'), findsOneWidget);
    await tester.tap(find.text('시작하기'));
    expect(started, 1);
  });

  testWidgets(
    'the guest accepts 19+ with an explicit button and can take it back',
    (tester) async {
      final answers = <bool>[];
      await pump(
        tester,
        view(
          isHost: false,
          heat: 'nuclear',
          canStart: false,
          onAccept: answers.add,
        ),
        size: const Size(390, 1000),
      );
      expect(find.text('19세 이상이며 동의해요'), findsOneWidget);
      await tester.tap(find.text('19세 이상이며 동의해요'));
      expect(answers, [true]);

      await pump(
        tester,
        view(
          isHost: false,
          heat: 'nuclear',
          iAccepted: true,
          canStart: false,
          onAccept: answers.add,
        ),
        size: const Size(390, 1000),
      );
      await tester.tap(find.text('동의했어요 · 눌러서 취소'));
      expect(answers, [true, false]);
    },
  );

  testWidgets('the real lobby screen wires 19+ to the guest ready state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final socket = SocketService();
    void join(String type) {
      socket.userId = 'ME';
      socket.lobbyGameType = type;
      socket.lobbyHost = 'ME';
      socket.lobbyPlayers = ['ME', 'YOU'];
      socket.lobbyOptions = {'rounds': 10, 'heat': 'nuclear'};
      socket.lobbyReady = {};
      socket.presenceNicknames = {'ME': '민지', 'YOU': '준호'};
    }

    addTearDown(() {
      socket
        ..userId = null
        ..lobbyOptions = {}
        ..lobbyPlayers = []
        ..lobbyReady = {}
        ..presenceNicknames = {};
    });
    await tester.pumpWidget(
      MaterialApp(
        home: GameLobbyScreen(
          gameType: 'telepathy',
          title: '텔레파시',
          description: '',
          emoji: '💫',
          color: Colors.indigo,
          backgroundColor: Colors.white,
          gameScreen: const SizedBox(),
          onJoinLobby: join,
        ),
      ),
    );
    await tester.pump();
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    socket.notifyListeners();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('상대의 동의를 기다리는 중'), findsOneWidget);

    socket.lobbyReady = {'YOU': true};
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    socket.notifyListeners();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('시작하기'), findsOneWidget);

    socket.lobbyOptions = {'rounds': 10, 'heat': 'spicy'};
    socket.lobbyReady = {};
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    socket.notifyListeners();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('시작하기'),
      findsOneWidget,
      reason: 'no consent needed below 19+',
    );
  });
}
