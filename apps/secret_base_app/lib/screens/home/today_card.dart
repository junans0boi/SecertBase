import 'package:flutter/material.dart';

import '../../core/today_api.dart';
import '../../v2/v2.dart';
import 'home_format.dart';

/// 홈 "오늘의 순간" card: two slots (me / partner) and one state-based CTA.
///
/// * empty / partnerWaiting → [onCreateMoment] (opens the 기록 composer)
/// * selfWaiting → [onPoke] (콕 찌르기, once a day) or [onOpenLoop]
/// * complete / viewed → [onOpenLoop]
class TodayCard extends StatelessWidget {
  final TodayState state;
  final VoidCallback onCreateMoment;
  final VoidCallback onOpenLoop;
  final String myName;
  final String partnerName;
  final VoidCallback? onPoke;
  final bool pokedToday;
  final bool poking;
  final bool offline;
  final String? baseUrl;

  const TodayCard({
    super.key,
    required this.state,
    required this.onCreateMoment,
    required this.onOpenLoop,
    this.myName = '나',
    this.partnerName = '짝꿍',
    this.onPoke,
    this.pokedToday = false,
    this.poking = false,
    this.offline = false,
    this.baseUrl,
  });

  ({String chip, V2Tone tone}) get _status => switch (state.status) {
    TodayStatus.empty => (chip: '아직 비어 있어요', tone: V2Tone.neutral),
    TodayStatus.partnerWaiting => (
      chip: '${josa(partnerName, '이', '가')} 남겼어요',
      tone: V2Tone.rose,
    ),
    TodayStatus.selfWaiting => (chip: '나만 남겼어요', tone: V2Tone.sky),
    TodayStatus.complete => (chip: '둘 다 남겼어요', tone: V2Tone.rose),
    TodayStatus.viewed => (chip: '함께 봤어요', tone: V2Tone.ok),
  };

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final mine = state.myMoment;
    final partner = state.partnerMoment;
    final partnerLeft =
        state.hasPartnerMoment ||
        partner != null ||
        state.status == TodayStatus.partnerWaiting ||
        state.canOpenLoop;
    final iLeft =
        mine != null ||
        state.status == TodayStatus.selfWaiting ||
        state.canOpenLoop;

    final Widget mySlot = iLeft
        ? _MomentSlot(
            moment: mine,
            name: myName,
            isMe: true,
            baseUrl: baseUrl,
            onTap: offline ? null : onOpenLoop,
          )
        : _EmptySlot(
            name: myName,
            isMe: true,
            caption: state.status == TodayStatus.partnerWaiting
                ? '내 차례예요'
                : myName,
          );
    final Widget partnerSlot = !partnerLeft
        ? _EmptySlot(
            name: partnerName,
            isMe: false,
            caption: state.status == TodayStatus.selfWaiting
                ? '${josa(partnerName, '을', '를')} 기다리는 중'
                : partnerName,
          )
        : state.status == TodayStatus.partnerWaiting
        ? const _LockedSlot()
        : _MomentSlot(
            moment: partner,
            name: partnerName,
            isMe: false,
            baseUrl: baseUrl,
            onTap: offline ? null : onOpenLoop,
          );

    return V2Card(
      padding: const EdgeInsets.all(V2Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('오늘의 순간', style: V2Text.head),
                ),
              ),
              V2Chip(
                label: offline ? '저장된 내용' : status.chip,
                tone: offline ? V2Tone.neutral : status.tone,
              ),
            ],
          ),
          const SizedBox(height: V2Space.x3),
          SizedBox(
            height: 112,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: mySlot),
                const SizedBox(width: 10),
                Expanded(child: partnerSlot),
              ],
            ),
          ),
          const SizedBox(height: V2Space.x3),
          if (state.status == TodayStatus.empty && !offline) ...[
            Text(
              '사진·글·영상 중 편한 걸로 남겨요',
              style: V2Text.cap,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: V2Space.x2),
          ],
          _cta(),
        ],
      ),
    );
  }

  Widget _cta() {
    if (offline) {
      return const V2Button(label: '연결되면 같이 볼 수 있어요', onPressed: null);
    }
    return switch (state.status) {
      TodayStatus.empty => V2Button(
        label: '오늘의 순간 남기기',
        icon: V2Icons.camera,
        onPressed: onCreateMoment,
      ),
      TodayStatus.partnerWaiting => V2Button(
        label: '내 순간 남기기',
        icon: V2Icons.camera,
        onPressed: onCreateMoment,
      ),
      TodayStatus.selfWaiting =>
        onPoke == null
            ? V2Button(label: '내 순간 보기', onPressed: onOpenLoop)
            : pokedToday
            ? const V2Button(
                label: '오늘은 콕 찔렀어요',
                icon: V2Icons.check,
                onPressed: null,
              )
            : V2Button(
                label: '$partnerName에게 콕 찌르기',
                icon: Icons.touch_app_rounded,
                loading: poking,
                onPressed: onPoke,
              ),
      TodayStatus.complete => V2Button(
        label: '둘이 같이 보기',
        icon: V2Icons.heart,
        onPressed: onOpenLoop,
      ),
      TodayStatus.viewed => V2Button(
        label: '오늘의 순간 다시 보기',
        variant: V2ButtonVariant.soft,
        onPressed: onOpenLoop,
      ),
    };
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({
    required this.name,
    required this.isMe,
    required this.caption,
  });

  final String name;
  final bool isMe;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line2, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: V2Space.x2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          V2Avatar(
            name: name,
            size: V2AvatarSize.sm,
            color: isMe ? V2Avatar.meColor : V2Avatar.partnerColor,
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: V2Text.cap.copyWith(
              color: p.sub,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedSlot extends StatelessWidget {
  const _LockedSlot();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '잠긴 순간, 내 순간을 남기면 열려요',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: V2Gradients.placeholders[1],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: V2Colors.surface,
                  shape: BoxShape.circle,
                  boxShadow: V2Shadow.level1,
                ),
                child: const Icon(
                  V2Icons.lock,
                  size: 18,
                  color: V2Colors.rose600,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: V2Space.x2),
                child: Text(
                  V2Text.keepAll('내 순간을 남기면 열려요'),
                  textAlign: TextAlign.center,
                  style: V2Text.cap.copyWith(
                    color: V2Colors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MomentSlot extends StatelessWidget {
  const _MomentSlot({
    required this.moment,
    required this.name,
    required this.isMe,
    required this.baseUrl,
    required this.onTap,
  });

  final TodayMoment? moment;
  final String name;
  final bool isMe;
  final String? baseUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = moment;
    final time = clockLabel(m?.capturedAt ?? m?.takenAt);
    final tag = time == null ? name : '$name · $time';
    final rawUrl = m?.mediaUrl;
    final url = rawUrl == null
        ? null
        : rawUrl.startsWith('http')
        ? rawUrl
        : '${baseUrl ?? ''}$rawUrl';
    final isImage =
        url != null &&
        m?.mediaType != 'video' &&
        m?.mediaType != 'text' &&
        baseUrl != null;

    Widget fill;
    if (m != null && m.deleted) {
      fill = _textFill(context, '지운 순간이에요', muted: true);
    } else if (isImage) {
      fill = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => V2PhotoPlaceholder(seed: m?.id ?? name),
      );
    } else if (m?.mediaType == 'video') {
      fill = Stack(
        fit: StackFit.expand,
        children: [
          V2PhotoPlaceholder(seed: m?.id ?? name),
          const Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: V2Colors.surface,
              size: 36,
            ),
          ),
        ],
      );
    } else if (m?.caption != null) {
      fill = _textFill(context, m!.caption!);
    } else {
      fill = V2PhotoPlaceholder(seed: m?.id ?? name);
    }

    return Semantics(
      button: onTap != null,
      label: '${isMe ? '내' : '$name의'} 오늘의 순간${time == null ? '' : ', $time'}',
      onTap: onTap,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  fill,
                  Positioned(
                    left: 8,
                    bottom: 8,
                    right: 8,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _NameTag(label: tag, isMe: isMe),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textFill(BuildContext context, String text, {bool muted = false}) {
    final p = V2Palette.of(context);
    return Container(
      color: muted ? p.soft2 : V2Colors.honeySoft,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 36),
      alignment: Alignment.topLeft,
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: V2Text.cap.copyWith(
          color: muted ? p.sub : V2Colors.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NameTag extends StatelessWidget {
  const _NameTag({required this.label, required this.isMe});
  final String label;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.fromLTRB(4, 0, 9, 0),
      decoration: BoxDecoration(
        color: V2Colors.snack.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: isMe ? V2Colors.rose : V2Colors.sky,
              shape: BoxShape.circle,
              border: Border.all(color: V2Colors.surface, width: 2),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V2Text.label.copyWith(
                color: V2Colors.surface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
