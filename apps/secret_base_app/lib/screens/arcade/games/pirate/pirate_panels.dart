import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'pirate_controller.dart';

/// 폭탄 확률 게이지: 남은 구멍 기준 %. 위험하면 하트비트처럼 뛴다.
class PirateRiskGauge extends StatefulWidget {
  final GameTheme theme;
  final int riskPct;
  final int remaining;

  const PirateRiskGauge({
    super.key,
    required this.theme,
    required this.riskPct,
    required this.remaining,
  });

  /// 이 값 이상이면 심장 박동 연출.
  static const int highRisk = 33;

  @override
  State<PirateRiskGauge> createState() => _PirateRiskGaugeState();
}

class _PirateRiskGaugeState extends State<PirateRiskGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  );

  @override
  void initState() {
    super.initState();
    _syncBeat();
  }

  @override
  void didUpdateWidget(covariant PirateRiskGauge old) {
    super.didUpdateWidget(old);
    _syncBeat();
  }

  void _syncBeat() {
    final high = widget.riskPct >= PirateRiskGauge.highRisk;
    if (high && !_beat.isAnimating) {
      _beat.repeat();
    } else if (!high && _beat.isAnimating) {
      _beat.stop();
      _beat.value = 0;
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  Color _color(int pct) {
    if (pct >= 50) return const Color(0xFFFF4D3D);
    if (pct >= 30) return const Color(0xFFFF8A2A);
    if (pct >= 20) return const Color(0xFFF2B33D);
    return const Color(0xFF9BD27A);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final pct = widget.riskPct.clamp(0, 100);
    final color = _color(pct);
    return Semantics(
      label: '폭탄 확률 $pct퍼센트, 남은 구멍 ${widget.remaining}개',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: t.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.gold.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _beat,
              builder: (context, child) {
                final v = _beat.value;
                // 두 번 뛰는 심장 박동
                final kick =
                    math.max(0.0, math.sin(v * math.pi * 2)) * 0.18 +
                    math.max(0.0, math.sin(v * math.pi * 2 - 1.1)) * 0.1;
                return Transform.scale(scale: 1 + kick, child: child);
              },
              child: const Text('💣', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('폭탄 확률', style: t.body(size: 12, color: t.subInk)),
                      const Spacer(),
                      Text(
                        '남은 구멍 ${widget.remaining}개',
                        style: t.body(size: 11.5, color: t.subInk),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: SizedBox(
                      height: 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: t.ink.withValues(alpha: 0.12)),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: pct / 100,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color.lerp(color, Colors.white, 0.25)!,
                                    color,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: Text(
                '$pct%',
                key: ValueKey(pct),
                style: t.display(size: 26, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 벌칙 단계 공통 판: 아래에서 올라오는 양피지 느낌 패널.
class PiratePhasePanel extends StatelessWidget {
  final GameTheme theme;
  final Widget child;

  const PiratePhasePanel({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, (1 - v) * 80),
        child: Opacity(opacity: v, child: child),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: GamePanel(
          theme: theme,
          radius: 26,
          glow: theme.gold.withValues(alpha: 0.6),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: child,
        ),
      ),
    );
  }
}

/// 이긴 사람: 프리셋 칩 10개 + 직접 입력(1~30자) → 벌칙 정하기.
class PiratePenaltyPicker extends StatefulWidget {
  final GameTheme theme;
  final String loserName;
  final bool sending;

  /// 보낸다. 검증에 걸리면 안내 문구를 돌려준다.
  final String? Function(String text) onSubmit;
  final VoidCallback? onSkip;

  const PiratePenaltyPicker({
    super.key,
    required this.theme,
    required this.loserName,
    required this.onSubmit,
    this.sending = false,
    this.onSkip,
  });

  @override
  State<PiratePenaltyPicker> createState() => _PiratePenaltyPickerState();
}

class _PiratePenaltyPickerState extends State<PiratePenaltyPicker> {
  final _text = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final error = validatePiratePenalty(_text.text);
    if (error != null) {
      setState(() => _error = error);
      GameSfx.instance.play(GameSound.warn);
      return;
    }
    final serverError = widget.onSubmit(_text.text);
    if (serverError != null) {
      setState(() => _error = serverError);
    } else {
      GameSfx.instance.play(GameSound.confirm);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final current = normalizePiratePenalty(_text.text);
    final canSend =
        !widget.sending && validatePiratePenalty(_text.text) == null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '벌칙을 정해 주세요',
          textAlign: TextAlign.center,
          style: t.display(size: 24, color: t.gold),
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.loserName}에게 줄 벌칙을 고르거나 직접 적어요',
          textAlign: TextAlign.center,
          style: t.body(size: 13, color: t.subInk),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final preset in kPiratePenaltyPresets)
              _PresetChip(
                theme: t,
                label: preset,
                selected: current == preset,
                onTap: () {
                  GameSfx.instance.play(GameSound.select);
                  _text.value = TextEditingValue(
                    text: preset,
                    selection: TextSelection.collapsed(offset: preset.length),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('pirate-penalty-input'),
          controller: _text,
          maxLength: kPiratePenaltyMax,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          inputFormatters: [
            LengthLimitingTextInputFormatter(kPiratePenaltyMax),
          ],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          style: t.body(size: 15, color: const Color(0xFF3A2414)),
          cursorColor: t.accent,
          decoration: InputDecoration(
            hintText: '직접 적기 (최대 $kPiratePenaltyMax자)',
            hintStyle: t.body(size: 14, color: const Color(0x993A2414)),
            filled: true,
            fillColor: const Color(0xFFF6E7C8),
            counterStyle: t.body(size: 11, color: t.subInk),
            errorText: _error,
            errorStyle: t.body(size: 12, color: const Color(0xFFFF9C8A)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: t.gold),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: t.gold.withValues(alpha: 0.7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: t.accent, width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 6),
        GamePrimaryButton(
          key: const ValueKey('pirate-penalty-send'),
          theme: t,
          label: widget.sending ? '보내는 중…' : '이 벌칙으로 정하기',
          icon: Icons.gavel_rounded,
          height: 52,
          onPressed: canSend ? _submit : null,
        ),
        if (widget.onSkip != null)
          TextButton(
            onPressed: widget.onSkip,
            child: Text('결과 화면 보기', style: t.body(size: 13, color: t.subInk)),
          ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final GameTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? t.accent.withValues(alpha: 0.9)
            : t.surface.withValues(alpha: 0.85),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? t.gold : t.gold.withValues(alpha: 0.45),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                label,
                style: t.body(
                  size: 13,
                  color: selected ? Colors.white : t.ink,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 진 사람: 이긴 사람이 벌칙을 고르는 동안.
class PiratePenaltyWaiting extends StatefulWidget {
  final GameTheme theme;
  final String winnerName;
  final VoidCallback? onSkip;

  const PiratePenaltyWaiting({
    super.key,
    required this.theme,
    required this.winnerName,
    this.onSkip,
  });

  @override
  State<PiratePenaltyWaiting> createState() => _PiratePenaltyWaitingState();
}

class _PiratePenaltyWaitingState extends State<PiratePenaltyWaiting>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final name = widget.winnerName;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _spin,
          builder: (context, child) => Transform.rotate(
            angle: math.sin(_spin.value * math.pi * 2) * 0.25,
            child: child,
          ),
          child: const Text('📜', style: TextStyle(fontSize: 44)),
        ),
        const SizedBox(height: 8),
        Text(
          '$name${josaIGa(name)} 벌칙을 고르는 중…',
          textAlign: TextAlign.center,
          style: t.display(size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          '두근두근, 어떤 벌칙이 나올까요?',
          textAlign: TextAlign.center,
          style: t.body(size: 13, color: t.subInk),
        ),
        if (widget.onSkip != null) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: widget.onSkip,
            child: Text('결과 화면 보기', style: t.body(size: 13, color: t.subInk)),
          ),
        ],
      ],
    );
  }
}

/// 정해진 벌칙을 크게 보여 주는 양피지 카드. 진 사람에게는 "했어요!" 버튼.
class PiratePenaltyCard extends StatefulWidget {
  final GameTheme theme;
  final String text;
  final String winnerName;
  final String loserName;
  final bool iAmLoser;
  final bool done;
  final VoidCallback? onDone;
  final VoidCallback? onSkip;

  const PiratePenaltyCard({
    super.key,
    required this.theme,
    required this.text,
    required this.winnerName,
    required this.loserName,
    required this.iAmLoser,
    required this.done,
    this.onDone,
    this.onSkip,
  });

  @override
  State<PiratePenaltyCard> createState() => _PiratePenaltyCardState();
}

class _PiratePenaltyCardState extends State<PiratePenaltyCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void initState() {
    super.initState();
    GameSfx.instance.play(GameSound.sparkle);
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    const parchmentInk = Color(0xFF4A2A14);
    final loser = widget.loserName;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _reveal,
          builder: (context, child) {
            final v = Curves.easeOutBack.transform(_reveal.value);
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateX((1 - v) * 1.2),
              child: Opacity(
                opacity: _reveal.value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: Container(
            key: const ValueKey('pirate-penalty-card'),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFBEED2),
                  Color(0xFFF1D9A8),
                  Color(0xFFE6C48A),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF8A5530), width: 2),
              boxShadow: [
                BoxShadow(
                  color: t.accent.withValues(alpha: 0.35),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '오늘의 벌칙',
                  style: t.body(
                    size: 13,
                    color: parchmentInk.withValues(alpha: 0.8),
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: t.display(size: 30, color: parchmentInk),
                ),
                const SizedBox(height: 10),
                Text(
                  '${widget.winnerName} → $loser',
                  style: t.body(
                    size: 12.5,
                    color: parchmentInk.withValues(alpha: 0.75),
                  ),
                ),
                if (widget.done) ...[
                  const SizedBox(height: 10),
                  Transform.rotate(
                    angle: -0.12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFB0302A),
                          width: 2.4,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '완료!',
                        style: t.display(
                          size: 20,
                          color: const Color(0xFFB0302A),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.iAmLoser && !widget.done)
          GamePrimaryButton(
            key: const ValueKey('pirate-penalty-done'),
            theme: t,
            label: '했어요!',
            icon: Icons.check_rounded,
            height: 52,
            onPressed: widget.onDone,
          )
        else
          Text(
            widget.done
                ? '$loser${josaIGa(loser)} 벌칙을 했어요!'
                : '$loser${josaIGa(loser)} 벌칙을 하는 중이에요',
            textAlign: TextAlign.center,
            style: t.body(size: 14, color: t.ink),
          ),
        if (widget.onSkip != null)
          TextButton(
            onPressed: widget.onSkip,
            child: Text('결과 화면 보기', style: t.body(size: 13, color: t.subInk)),
          ),
      ],
    );
  }
}
