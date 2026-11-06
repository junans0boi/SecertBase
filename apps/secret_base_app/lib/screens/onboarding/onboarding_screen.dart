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
  const _Card(this.title, this.body, this.scene);
  final String title;
  final String body;
  final V2Scene scene;
}

const _cards = [
  _Card(
    '우리의 하루를\n기록해요',
    '사진 한 장, 한 줄이면 충분해요. 둘만 보는 기록이 차곡차곡 쌓여요.',
    V2Scene.photo,
  ),
  _Card(
    '같은 날, 같은 순간을\n함께 남겨요',
    '한 사람이 오늘을 남기면 다른 한 사람에게 바로 알려드려요.',
    V2Scene.couple,
  ),
  _Card(
    '둘만 열 수 있는\n비밀기지',
    '기록과 장소는 우리 둘에게만 보여요. 언제든 내보내고 지울 수 있어요.',
    V2Scene.hearts,
  ),
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
    return AuthFrame(
      hero: true,
      body: SizedBox(
        height: 460,
        child: PageView.builder(
          controller: _controller,
          itemCount: _cards.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) {
            final c = _cards[i];
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                V2SceneIllustration(c.scene, width: 240),
                const SizedBox(height: V2Space.x8),
                Text(
                  c.title,
                  textAlign: TextAlign.center,
                  style: V2Text.title.copyWith(fontSize: 26, height: 1.3),
                ),
                const SizedBox(height: V2Space.x3),
                Text(
                  V2Text.keepAll(c.body),
                  textAlign: TextAlign.center,
                  style: V2Text.body.copyWith(color: p.sub),
                ),
              ],
            );
          },
        ),
      ),
      footer: Column(
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
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _index ? p.primary : p.line2,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: V2Space.x5),
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
    );
  }
}
