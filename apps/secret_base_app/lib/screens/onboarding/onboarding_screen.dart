import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../v2/v2.dart';
import '../auth/auth_parts.dart';

const _seenKey = 'onboarding_seen_v2';

/// 처음 실행 때만 보여 주는 3장 소개를 이미 봤는지.
Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_seenKey) ?? false;
}

Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_seenKey, true);
}

class _Card {
  const _Card(this.title, this.body, this.art);
  final String title;
  final String body;
  final int art;
}

const _cards = [
  _Card('우리의 하루를\n기록해요', '사진 한 장, 한 줄이면 충분해요. 둘만 보는 기록이 차곡차곡 쌓여요.', 0),
  _Card('같은 날, 같은 순간을\n함께 남겨요', '한 사람이 오늘을 남기면 다른 한 사람에게 바로 알려드려요.', 1),
  _Card('둘만 열 수 있는\n비밀기지', '기록과 장소는 우리 둘에게만 보여요. 언제든 내보내고 지울 수 있어요.', 2),
];

/// 온보딩 3장. 건너뛰기/시작하기를 누르면 [onDone]을 부른다.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await markOnboardingSeen();
    if (mounted) widget.onDone();
  }

  void _next() {
    if (_index >= _cards.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: V2Motion.of(context, V2Motion.base),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final last = _index == _cards.length - 1;
    return V2Theme(
      child: Scaffold(
        backgroundColor: p.bg,
        body: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _cards.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final c = _cards[i];
                  return Column(
                    children: [
                      Expanded(
                        child: SizedBox(
                          width: double.infinity,
                          child: AuthHeroBlock(
                            expand: true,
                            child: _OnboardingArt(c.art),
                          ),
                        ),
                      ),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              V2Space.page + V2Space.x2,
                              V2Space.x6,
                              V2Space.page + V2Space.x2,
                              V2Space.x2,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(
                                    c.title,
                                    textAlign: TextAlign.center,
                                    style: V2Text.title.copyWith(
                                      fontSize: 30,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: V2Space.x2),
                                Text(
                                  V2Text.keepAll(c.body),
                                  textAlign: TextAlign.center,
                                  style: V2Text.body.copyWith(color: p.sub),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      V2Space.page,
                      V2Space.x2,
                      V2Space.page,
                      V2Space.x4,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          label: '${_cards.length}장 중 ${_index + 1}장',
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < _cards.length; i++)
                                AnimatedContainer(
                                  duration: V2Motion.of(context, V2Motion.base),
                                  width: i == _index ? 22 : 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: i == _index ? p.primary : p.line2,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: V2Space.x4),
                        V2Button(label: last ? '시작하기' : '다음', onPressed: _next),
                        const SizedBox(height: V2Space.x1),
                        Opacity(
                          opacity: last ? 0 : 1,
                          child: V2Button(
                            label: '건너뛰기',
                            variant: V2ButtonVariant.text,
                            onPressed: last ? null : _finish,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 장미빛 상단에 놓이는 장면 그림 3종(기록 카드 / 두 사람 / 열쇠 하트).
class _OnboardingArt extends StatelessWidget {
  const _OnboardingArt(this.index);
  final int index;

  Widget _chip(BuildContext context, {required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: V2Colors.surface,
      borderRadius: BorderRadius.circular(99),
      boxShadow: V2Shadow.level1,
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return ExcludeSemantics(
      child: switch (index) {
        0 => SizedBox(
          width: 260,
          height: 270,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: -0.13,
                child: Container(
                  width: 150,
                  height: 190,
                  margin: const EdgeInsets.only(right: 70),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              Transform.rotate(
                angle: 0.1,
                child: Container(
                  width: 150,
                  height: 190,
                  margin: const EdgeInsets.only(left: 70, bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              Container(
                width: 156,
                height: 204,
                padding: const EdgeInsets.all(V2Space.x3),
                decoration: BoxDecoration(
                  color: V2Colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: V2Shadow.level2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 116,
                        color: V2Colors.peachSoft,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 16,
                              top: 14,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: V2Colors.peach,
                                ),
                              ),
                            ),
                            Positioned(
                              left: -10,
                              right: -10,
                              bottom: -26,
                              child: Container(
                                height: 70,
                                decoration: BoxDecoration(
                                  color: V2Colors.rose.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(60),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: V2Space.x3),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 70,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: V2Colors.roseSoft,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 44,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: p.soft2,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(V2Icons.heart, size: 24, color: V2Colors.rose),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 6,
                right: 0,
                child: _chip(
                  context,
                  child: Text(
                    'D+412',
                    textScaler: TextScaler.noScaling,
                    style: V2Text.bodyStrong.copyWith(color: p.onPrimarySoft),
                  ),
                ),
              ),
            ],
          ),
        ),
        1 => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(V2Icons.heart, size: 40, color: V2Colors.onHeroStrong),
            const SizedBox(height: V2Space.x2),
            SizedBox(
              width: 212,
              height: 136,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    child: Container(
                      width: 136,
                      height: 136,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: V2Colors.surface,
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 92,
                        color: V2Colors.rose,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: Container(
                      width: 136,
                      height: 136,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: V2Colors.honeySoft,
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 92,
                        color: V2Colors.peach,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: V2Space.x5),
            _chip(
              context,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(V2Icons.ok, size: 24, color: V2Colors.ok),
                  const SizedBox(width: V2Space.x2),
                  Text(
                    '오늘의 기록 2/2',
                    textScaler: TextScaler.noScaling,
                    style: V2Text.bodyStrong.copyWith(color: p.sub),
                  ),
                ],
              ),
            ),
          ],
        ),
        _ => SizedBox(
          width: 260,
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              const AuthHeartKey(size: 156),
              Positioned(
                left: 18,
                top: 24,
                child: Icon(
                  V2Icons.sparkle,
                  size: 28,
                  color: V2Colors.onHeroStrong,
                ),
              ),
              Positioned(
                right: 26,
                top: 8,
                child: Icon(
                  V2Icons.sparkle,
                  size: 20,
                  color: V2Colors.onHeroStrong,
                ),
              ),
            ],
          ),
        ),
      },
    );
  }
}
