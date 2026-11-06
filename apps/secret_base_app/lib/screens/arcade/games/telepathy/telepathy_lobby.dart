import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import 'telepathy_widgets.dart';

/// 텔레파시 로비(별빛 편지 목업): 머리 문구 · 두 사람 · 문제 수 · 질문 수위 · 시작.
/// 19+ 수위는 경고와 상대(비방장)의 명시적 동의가 있어야 시작할 수 있다.
class TelepathyLobbyView extends StatelessWidget {
  final bool isHost;
  final bool hasTwoPlayers;
  final String myName;
  final String partnerName;
  final int rounds;

  /// mild | spicy | nuclear
  final String heat;

  /// 비방장이 19+에 동의했는가.
  final bool partnerAccepted;

  /// 내가 비방장이고 19+에 동의했는가.
  final bool iAccepted;
  final bool canStart;
  final String startLabel;
  final VoidCallback onBack;
  final ValueChanged<int> onRounds;
  final ValueChanged<String> onHeat;
  final VoidCallback onStart;
  final ValueChanged<bool> onAccept;

  const TelepathyLobbyView({
    super.key,
    required this.isHost,
    required this.hasTwoPlayers,
    required this.myName,
    required this.partnerName,
    required this.rounds,
    required this.heat,
    required this.partnerAccepted,
    required this.iAccepted,
    required this.canStart,
    required this.startLabel,
    required this.onBack,
    required this.onRounds,
    required this.onHeat,
    required this.onStart,
    required this.onAccept,
  });

  bool get _nuclear => heat == 'nuclear';

  bool _short(BuildContext context) => MediaQuery.sizeOf(context).height < 700;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTpBg,
      body: GameBackdrop(
        theme: GameTheme.starlight,
        frame: false,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  SizedBox(
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text('텔레파시', style: tpSerif(size: 19)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: IconButton(
                              tooltip: '뒤로',
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 20,
                                color: kTpInk,
                              ),
                              onPressed: onBack,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      children: [
                        // 19+ 안내와 수위 선택이 화면 안에 들어오도록, 19+이거나 화면이 낮으면 머리를 줄인다.
                        if (!_nuclear && !_short(context)) ...[
                          const Center(child: TelepathySigil(size: 64)),
                          const SizedBox(height: 18),
                        ],
                        Text(
                          '같은 마음인지\n확인해 볼까요?',
                          textAlign: TextAlign.center,
                          style: tpSerif(
                            size: _nuclear ? 24 : 28,
                            height: 1.35,
                          ),
                        ),
                        if (!_nuclear && !_short(context)) ...[
                          const SizedBox(height: 10),
                          Text(
                            '둘 중 하나를 몰래 고르고,\n동시에 열어 봐요.',
                            textAlign: TextAlign.center,
                            style: tpSans(size: 14, color: kTpSub, height: 1.6),
                          ),
                        ],
                        SizedBox(height: _nuclear || _short(context) ? 16 : 26),
                        _pair(),
                        const SizedBox(height: 24),
                        _options(),
                      ],
                    ),
                  ),
                  _footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pair() {
    final partnerStatus = !hasTwoPlayers
        ? '기다리는 중…'
        : _nuclear
        ? (partnerAccepted ? '동의 완료' : '동의 대기')
        : '준비 완료';
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: TelepathyCapsule(
            name: myName,
            mine: true,
            status: isHost ? '방장' : '참가자',
          ),
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: TelepathyLink(),
          ),
        ),
        Expanded(
          flex: 5,
          child: TelepathyCapsule(
            name: partnerName,
            mine: false,
            status: partnerStatus,
            statusGold: hasTwoPlayers && (!_nuclear || partnerAccepted),
          ),
        ),
      ],
    );
  }

  Widget _options() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kTpLine),
        color: const Color(0x09FFFFFF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header('문제 수', '방장만 바꿀 수 있어요'),
          const SizedBox(height: 12),
          _Seg<int>(
            enabled: isHost,
            value: rounds,
            onChanged: onRounds,
            items: const [
              _SegItem(10, '10', '약 3분'),
              _SegItem(5, '5', '가볍게'),
              _SegItem(15, '15', '천천히'),
            ],
            serif: true,
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: kTpLine),
          const SizedBox(height: 16),
          _header('질문 수위', '방장만 바꿀 수 있어요'),
          const SizedBox(height: 12),
          _Seg<String>(
            enabled: isHost,
            value: heat,
            onChanged: onHeat,
            items: const [
              _SegItem('mild', '순한맛', '편하게'),
              _SegItem('spicy', '살짝 매운맛', '분위기 있게'),
              _SegItem('nuclear', '핵폭탄 매운맛', '🔞 19+'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            switch (heat) {
              'spicy' => '분위기 있는 스킨십·장소·속옷 취향',
              'nuclear' => '하드한 성인 질문 · BDSM 취향 포함',
              _ => '편하게 즐기는 질문만 나와요',
            },
            textAlign: TextAlign.center,
            style: tpSans(size: 12.5, color: kTpSub),
          ),
          if (_nuclear) ...[const SizedBox(height: 14), _adultNotice()],
        ],
      ),
    );
  }

  Widget _header(String title, String hint) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: tpSans(size: 15, weight: FontWeight.w700)),
        const Spacer(),
        Text(hint, style: tpSans(size: 12, color: kTpSub)),
      ],
    ),
  );

  /// 19+ 성인 전용 경고. 비방장은 여기서 직접 동의한다.
  Widget _adultNotice() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kTpWarn.withValues(alpha: 0.5)),
        color: kTpWarn.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '🔞 19+ 성인 전용',
            style: tpSans(size: 14, color: kTpWarn, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '노골적이고 하드한 성인 질문이 나오고, 묶기·복종 같은 BDSM 취향 주제도 포함돼요. '
            '두 사람 모두 만 19세 이상이어야 하고, 상대가 직접 동의해야 시작할 수 있어요.',
            style: tpSans(size: 12.5, color: kTpSub, height: 1.5),
          ),
          if (!isHost) ...[
            const SizedBox(height: 10),
            Semantics(
              button: true,
              onTap: () => onAccept(!iAccepted),
              label: iAccepted ? '19세 이상 동의 취소' : '19세 이상이며 동의해요',
              child: ExcludeSemantics(
                child: Material(
                  color: iAccepted ? kTpWarn : Colors.transparent,
                  shape: StadiumBorder(
                    side: BorderSide(color: kTpWarn, width: 1.4),
                  ),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => onAccept(!iAccepted),
                    child: SizedBox(
                      height: 48,
                      child: Center(
                        child: Text(
                          iAccepted ? '동의했어요 · 눌러서 취소' : '19세 이상이며 동의해요',
                          style: tpSans(
                            size: 14.5,
                            color: iAccepted ? kTpBg : kTpWarn,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              !hasTwoPlayers
                  ? '상대가 들어오면 동의를 받아요'
                  : partnerAccepted
                  ? '상대가 동의했어요'
                  : '상대의 동의를 기다리는 중이에요',
              style: tpSans(
                size: 12.5,
                color: partnerAccepted ? kTpGold : kTpWarn,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isHost)
            Semantics(
              button: true,
              enabled: canStart,
              onTap: canStart ? onStart : null,
              label: startLabel,
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: canStart ? 1 : 0.5,
                  child: Material(
                    color: kTpGold,
                    borderRadius: BorderRadius.circular(28),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: canStart ? onStart : null,
                      child: SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: Center(
                          child: Text(
                            startLabel,
                            textAlign: TextAlign.center,
                            style: tpSans(
                              size: 17,
                              color: const Color(0xFF1B1A30),
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 56,
              child: Center(
                child: Text(
                  '방장이 시작할 때까지 기다려 주세요',
                  style: tpSans(size: 14, color: kTpSub),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text('두 사람 모두 15초 안에 골라요', style: tpSans(size: 12, color: kTpSub)),
        ],
      ),
    );
  }
}

class _SegItem<T> {
  final T value;
  final String label;
  final String sub;

  const _SegItem(this.value, this.label, this.sub);
}

/// 3칸 선택(방장만 바꿀 수 있고, 상대는 방장이 고른 값만 본다).
class _Seg<T> extends StatelessWidget {
  final List<_SegItem<T>> items;
  final T value;
  final bool enabled;
  final bool serif;
  final ValueChanged<T> onChanged;

  const _Seg({
    required this.items,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.serif = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _cell(items[i])),
        ],
      ],
    );
  }

  Widget _cell(_SegItem<T> item) {
    final on = item.value == value;
    final dimmed = !enabled && !on;
    return Semantics(
      button: enabled,
      selected: on,
      label: '${item.label}, ${item.sub}',
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: dimmed ? 0.45 : 1,
          child: Material(
            color: on ? kTpGold : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: enabled && !on ? () => onChanged(item.value) : null,
              child: Container(
                height: 62,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: on ? kTpGold : kTpLine),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        style: serif
                            ? tpSerif(
                                size: 22,
                                color: on ? const Color(0xFF1B1A30) : kTpInk,
                              )
                            : tpSans(
                                size: 14,
                                color: on ? const Color(0xFF1B1A30) : kTpInk,
                                weight: FontWeight.w700,
                              ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.sub,
                        maxLines: 1,
                        style: tpSans(
                          size: 12,
                          color: on ? const Color(0xFF3A3552) : kTpSub,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
