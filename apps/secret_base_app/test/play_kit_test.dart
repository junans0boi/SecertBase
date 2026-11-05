// 게임 2.0 공용 부품: 여섯 테마 모두에서 그려지고 휴대폰 폭에서 넘치지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secret_base_app/core/game_sfx/game_sounds.dart';
import 'package:secret_base_app/core/game_sfx/synth.dart';
import 'package:secret_base_app/widgets/game_notice_listener.dart';
import 'package:secret_base_app/widgets/play_kit/play_kit.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(360, 760),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pump(const Duration(milliseconds: 600));
  }

  for (final theme in GameTheme.all) {
    testWidgets('${theme.id}: backdrop, HUD, buttons and cards fit 360px', (
      tester,
    ) async {
      await pump(
        tester,
        GameBackdrop(
          theme: theme,
          child: Column(
            children: [
              GameTopBar(
                theme: theme,
                title: '테스트 게임',
                gameType: 'blackjack',
                canRestart: true,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: PlayerBadge(
                      theme: theme,
                      emoji: '🐻',
                      name: '아주아주긴닉네임입니다',
                      subtitle: '카드 7장',
                      active: true,
                      isMe: true,
                    ),
                  ),
                  TurnTimerRing(
                    theme: theme,
                    deadline: GameDeadline(
                      DateTime.now().add(const Duration(seconds: 12)),
                      const Duration(seconds: 20),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                children: [
                  GameChip(theme: theme, label: '라운드 2/5', leading: '🎯'),
                  GameChip(theme: theme, label: '내 차례', emphasized: true),
                  SeriesScore(
                    theme: theme,
                    myWins: 2,
                    opponentWins: 1,
                    draws: 1,
                  ),
                ],
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PlayingCard(suit: '♠', rank: 'A'),
                  PlayingCard(suit: '♥', rank: '10', size: CardSize.small),
                  PlayingCard(
                    suit: '♦',
                    rank: 'Q',
                    highlight: true,
                    badge: 'NEW',
                  ),
                  PlayingCard(rank: 'JOKER', suit: '🃏'),
                  PlayingCard(faceUp: false),
                ],
              ),
              GamePrimaryButton(
                theme: theme,
                label: '아주 긴 버튼 문구도 한 줄로 줄여서 보여 줍니다',
                icon: Icons.bolt,
                onPressed: () {},
              ),
              GameSecondaryButton(theme: theme, label: '보조', onPressed: () {}),
              ReactionButton(theme: theme, gameType: 'blackjack'),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('${theme.id}: result overlay with series', (tester) async {
      await pump(
        tester,
        GameResultOverlay(
          theme: theme,
          outcome: GameOutcome.win,
          reason: '21을 먼저 만들었어요',
          series: const {
            'wins': {'ME': 2, 'YOU': 1},
            'draws': 1,
          },
          me: 'ME',
          onRematch: () {},
          resultId: 'test-${theme.id}',
        ),
      );
      expect(find.text('한 판 더!'), findsOneWidget);
      expect(find.text('이번 방 전적'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
    });
  }

  test('series score reads wins for me and the partner', () {
    final s = SeriesScore.fromMap(GameTheme.lounge, const {
      'wins': {'ME': 3, 'YOU': 1},
      'draws': 2,
    }, 'ME');
    expect([s.myWins, s.opponentWins, s.draws], [3, 1, 2]);
  });

  test(
    'server deadline is converted with the server clock, not the device clock',
    () {
      final received = DateTime(2026, 1, 1, 12);
      final d = GameDeadline.fromServer(
        deadlineMs: 1_000_000 + 15_000,
        serverNowMs: 1_000_000,
        total: const Duration(seconds: 20),
        receivedAt: received,
      )!;
      expect(d.remaining(received).inSeconds, 15);
      expect(
        d.remaining(received.add(const Duration(seconds: 30))),
        Duration.zero,
      );
    },
  );

  test('suit parsing accepts server glyphs and letters', () {
    expect(suitFrom('♠'), Suit.spade);
    expect(suitFrom('H'), Suit.heart);
    expect(suitFrom('♦'), Suit.diamond);
    expect(suitFrom('club'), Suit.club);
    expect(suitFrom('🃏'), isNull);
  });

  test('notices for another game are filtered; zero is rps on the server', () {
    expect(gameNoticeMatches('penalty', 'oldmaid'), isFalse);
    expect(gameNoticeMatches('rps', 'zero'), isTrue);
    expect(gameNoticeMatches(null, 'oldmaid'), isTrue);
    expect(gameNoticeMatches('penalty', null), isTrue);
  });

  test('every sound renders a short, normalized, click-free clip', () {
    for (final sound in GameSound.values) {
      final pcm = GameSoundRecipes.render(sound);
      expect(pcm.length, greaterThan(0), reason: sound.name);
      expect(
        pcm.length / Synth.sampleRate,
        lessThanOrEqualTo(2.0),
        reason: sound.name,
      );
      final peak = pcm.fold<double>(0, (m, v) => v.abs() > m ? v.abs() : m);
      expect(peak, inInclusiveRange(0.1, 1.0), reason: sound.name);
      expect(
        pcm.last.abs(),
        lessThan(0.02),
        reason: '${sound.name} ends with a fade',
      );
      final wav = Synth.wav(pcm);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    }
  });
}
