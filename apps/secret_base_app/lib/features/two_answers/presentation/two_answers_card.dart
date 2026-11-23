import 'package:flutter/material.dart';

import '../../../v2/v2.dart';
import '../domain/two_answer.dart';

/// 홈의 "마주 열기" 카드. 상태 세 가지: 내 차례 / 상대 기다리는 중 / 열림.
class TwoAnswersHomeCard extends StatelessWidget {
  final TwoAnswerCard card;
  final VoidCallback? onTap;

  const TwoAnswersHomeCard({super.key, required this.card, this.onTap});

  (String, String, IconData) get _copy => switch (card.status) {
    TwoAnswerStatus.myTurn => (
      '내 차례예요',
      card.partnerAnswered ? '상대가 먼저 답했어요. 나도 답하면 열려요' : '오늘의 질문에 먼저 답해 볼까요?',
      V2Icons.edit,
    ),
    TwoAnswerStatus.waiting => (
      '상대를 기다리는 중이에요',
      '상대가 답하면 봉인이 풀려요',
      V2Icons.lock,
    ),
    TwoAnswerStatus.open => (
      '봉인이 풀렸어요',
      '둘의 답변을 함께 볼 수 있어요',
      V2Icons.visibility,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final (headline, sub, icon) = _copy;
    return V2Card(
      key: const ValueKey('two-answers-card'),
      variant: V2CardVariant.soft,
      onTap: onTap,
      semanticLabel: '마주 열기, $headline',
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: p.primarySoft,
              borderRadius: BorderRadius.circular(V2Radius.ctl),
            ),
            child: Icon(icon, color: p.primary, size: 22),
          ),
          const SizedBox(width: V2Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('마주 열기', style: V2Text.cap.copyWith(color: p.sub)),
                const SizedBox(height: 2),
                Text(headline, style: V2Text.bodyStrong.copyWith(color: p.ink)),
                const SizedBox(height: 2),
                Text(
                  V2Text.keepAll(sub),
                  style: V2Text.cap.copyWith(color: p.sub),
                ),
              ],
            ),
          ),
          if (card.streak > 0)
            Text(
              '${card.streak}일 연속',
              style: V2Text.cap.copyWith(color: p.primary),
            ),
          Icon(V2Icons.chevron, color: p.sub, size: 20),
        ],
      ),
    );
  }
}
