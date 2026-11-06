import 'package:flutter/material.dart';

import '../../../core/today_api.dart';
import '../../../features/moment_loop/domain/moment.dart';
import '../../../v2/v2.dart';
import 'moment_format.dart';
import 'moment_media.dart';

/// Pinned "오늘" card: empty / partner waiting / me waiting / complete.
class MomentTodayCard extends StatelessWidget {
  final TodayState? state;
  final bool loading;
  final bool failed;
  final String myName;
  final String partnerName;
  final VoidCallback onCompose;
  final VoidCallback onOpenLoop;

  const MomentTodayCard({
    super.key,
    required this.state,
    required this.loading,
    required this.failed,
    required this.myName,
    required this.partnerName,
    required this.onCompose,
    required this.onOpenLoop,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && state == null) {
      return const V2Shimmer(
        child: V2SkeletonBox(height: 132, radius: V2Radius.card),
      );
    }
    final p = V2Palette.of(context);
    final status = state?.status ?? TodayStatus.empty;
    final today = longDate(DateTime.now());
    final partner = partnerName;

    late final Widget lead;
    late final String title;
    late final String body;
    late final String action;
    late final VoidCallback onAction;
    var actionVariant = V2ButtonVariant.primary;
    switch (status) {
      case TodayStatus.empty:
        lead = const V2Art(icon: V2Icons.camera, size: 52);
        title = '오늘의 순간';
        body = '$today · ${josa(partner, '과', '와')} 같은 하루를 한 장씩';
        action = '오늘의 순간 남기기';
        onAction = onCompose;
      case TodayStatus.selfWaiting:
        lead = V2Avatar(name: myName, size: V2AvatarSize.md);
        title = '${josa(partner, '을', '를')} 기다려요';
        body = '${josa(partner, '이', '가')} 남기면 둘의 순간이 함께 열려요';
        action = '내 순간 보기';
        onAction = onOpenLoop;
        actionVariant = V2ButtonVariant.soft;
      case TodayStatus.partnerWaiting:
        lead = V2Avatar(
          name: partner,
          color: V2Avatar.partnerColor,
          size: V2AvatarSize.md,
        );
        title = '${josa(partner, '이', '가')} 먼저 남겼어요';
        body = '내 순간을 남기면 $partner의 순간이 열려요';
        action = '내 순간 남기기';
        onAction = onCompose;
      case TodayStatus.complete:
      case TodayStatus.viewed:
        lead = V2AvatarPair(me: myName, partner: partner);
        title = '둘의 순간이 열렸어요';
        final revealed = DateTime.tryParse(state?.revealedAt ?? '')?.toLocal();
        body = revealed == null
            ? '둘 다 오늘의 순간을 남겼어요'
            : '둘 다 남겼어요 · ${clockLabel(revealed)}';
        action = status == TodayStatus.viewed ? '다시 보기' : '함께 보기';
        onAction = onOpenLoop;
    }

    return V2Card(
      key: const Key('moment_today_card'),
      gradient: V2Gradients.heroSoft,
      padding: const EdgeInsets.all(V2Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              lead,
              const SizedBox(width: V2Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: V2Text.head.copyWith(color: p.ink)),
                    const SizedBox(height: 2),
                    Text(body, style: V2Text.cap.copyWith(color: p.sub)),
                  ],
                ),
              ),
            ],
          ),
          if (failed) ...[
            const SizedBox(height: V2Space.x2),
            Row(
              children: [
                Icon(V2Icons.offline, size: 16, color: p.sub),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '최근 상태를 불러오지 못했어요',
                    style: V2Text.cap.copyWith(color: p.sub),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: V2Space.x3),
          V2Button(
            key: const Key('moment_today_action'),
            label: action,
            variant: actionVariant,
            size: V2ButtonSize.sm,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

/// Week navigation + calendar + grid/list in one row.
class MomentWeekToolbar extends StatelessWidget {
  final DateTime weekStart;
  final bool isCurrentWeek;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback onCalendar;
  final bool gridView;
  final VoidCallback onToggleView;
  final bool showWeekNav;
  final String? label;

  const MomentWeekToolbar({
    super.key,
    required this.weekStart,
    required this.isCurrentWeek,
    required this.onPrev,
    required this.onNext,
    required this.onCalendar,
    required this.gridView,
    required this.onToggleView,
    this.showWeekNav = true,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (showWeekNav) ...[
            V2IconButton(
              key: const Key('moment_week_prev'),
              icon: Icons.chevron_left_rounded,
              tooltip: '이전 주',
              onPressed: onPrev,
            ),
            Expanded(
              child: Text(
                label ?? weekRangeLabel(weekStart),
                textAlign: TextAlign.center,
                style: V2Text.bodyStrong.copyWith(color: p.ink),
              ),
            ),
            V2IconButton(
              key: const Key('moment_week_next'),
              icon: Icons.chevron_right_rounded,
              tooltip: '다음 주',
              onPressed: onNext,
            ),
          ] else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: V2Space.x1),
                child: Text(
                  label ?? '',
                  style: V2Text.bodyStrong.copyWith(color: p.ink),
                ),
              ),
            ),
          V2IconButton(
            key: const Key('moment_calendar_btn'),
            icon: V2Icons.calendar,
            tooltip: '달력으로 날짜 고르기',
            onPressed: onCalendar,
          ),
          V2IconButton(
            key: const Key('moment_view_toggle'),
            icon: gridView
                ? Icons.view_agenda_rounded
                : Icons.grid_view_rounded,
            tooltip: gridView ? '목록으로 보기' : '격자로 보기',
            onPressed: onToggleView,
          ),
        ],
      ),
    );
  }
}

typedef MomentGroupTap = void Function(List<Moment> group);

/// One day: header + 3-column grid or list rows.
class MomentDaySection extends StatelessWidget {
  final DateTime day;
  final List<List<Moment>> groups;
  final bool gridView;
  final String baseUrl;
  final int? myUserId;
  final String myName;
  final String partnerName;
  final MomentGroupTap onTap;

  const MomentDaySection({
    super.key,
    required this.day,
    required this.groups,
    required this.gridView,
    required this.baseUrl,
    required this.myUserId,
    required this.myName,
    required this.partnerName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final rel = relativeDay(day);
    final dateText = '${day.month}월 ${day.day}일 ${weekdayShort(day)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: V2Space.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: V2Space.x2),
            child: Semantics(
              header: true,
              child: Text.rich(
                TextSpan(
                  children: [
                    if (rel == '오늘' || rel == '어제')
                      TextSpan(
                        text: '$rel  ',
                        style: V2Text.bodyStrong.copyWith(color: p.ink),
                      ),
                    TextSpan(
                      text: dateText,
                      style:
                          (rel == '오늘' || rel == '어제'
                                  ? V2Text.cap
                                  : V2Text.bodyStrong)
                              .copyWith(
                                color: rel == '오늘' || rel == '어제'
                                    ? p.sub
                                    : p.ink,
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (gridView)
            MomentGrid(
              groups: groups,
              baseUrl: baseUrl,
              myUserId: myUserId,
              myName: myName,
              partnerName: partnerName,
              onTap: onTap,
            )
          else
            for (final g in groups)
              MomentListRow(
                group: g,
                baseUrl: baseUrl,
                isMine: g.first.userId == myUserId,
                authorName: g.first.userId == myUserId
                    ? myName
                    : (g.first.userName ?? partnerName),
                onTap: () => onTap(g),
              ),
        ],
      ),
    );
  }
}

class MomentGrid extends StatelessWidget {
  final List<List<Moment>> groups;
  final String baseUrl;
  final int? myUserId;
  final String myName;
  final String partnerName;
  final MomentGroupTap onTap;

  const MomentGrid({
    super.key,
    required this.groups,
    required this.baseUrl,
    required this.myUserId,
    required this.myName,
    required this.partnerName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      key: const Key('moment_three_column_grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final g = groups[i];
        final mine = g.first.userId == myUserId;
        final name = mine ? myName : (g.first.userName ?? partnerName);
        return _TapTile(
          label: _groupLabel(g, name),
          onTap: () => onTap(g),
          child: MomentTile(
            moment: g.first,
            baseUrl: baseUrl,
            count: g.length,
            authorName: name,
            isMine: mine,
          ),
        );
      },
    );
  }
}

String _groupLabel(List<Moment> g, String author) {
  final first = g.first;
  final kind = first.todayLocked
      ? '잠긴 순간'
      : first.hasMedia
      ? (first.isVideo ? '영상' : '사진')
      : '글';
  final caption = (first.caption ?? '').trim();
  return [
    '$author의 $kind${g.length > 1 ? ' ${g.length}개' : ''}',
    if (caption.isNotEmpty && !first.todayLocked) caption,
  ].join(', ');
}

class _TapTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Widget child;

  const _TapTile({
    required this.label,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: V2Radius.ctlAll,
          child: child,
        ),
      ),
    );
  }
}

class MomentListRow extends StatelessWidget {
  final List<Moment> group;
  final String baseUrl;
  final bool isMine;
  final String authorName;
  final VoidCallback onTap;

  const MomentListRow({
    super.key,
    required this.group,
    required this.baseUrl,
    required this.isMine,
    required this.authorName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final first = group.first;
    final caption = (first.caption ?? '').trim();
    final meta = [
      authorName,
      if (first.todayMoment) '오늘의 순간',
      if ((first.linkedPlaceName ?? '').isNotEmpty) first.linkedPlaceName!,
    ].join(' · ');
    final day = momentDay(first);
    return _TapTile(
      label: _groupLabel(group, authorName),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: MomentTile(
                moment: first,
                baseUrl: baseUrl,
                count: group.length,
                authorName: authorName,
                isMine: isMine,
                showAuthor: false,
              ),
            ),
            const SizedBox(width: V2Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    first.todayLocked
                        ? '내 순간을 남기면 열려요'
                        : caption.isEmpty
                        ? (first.hasMedia
                              ? (first.isVideo ? '영상으로 남긴 순간' : '사진으로 남긴 순간')
                              : '말없이 남긴 순간')
                        : caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V2Text.bodyStrong.copyWith(color: p.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V2Text.cap.copyWith(color: p.sub),
                  ),
                ],
              ),
            ),
            const SizedBox(width: V2Space.x2),
            Text(
              day != null && relativeDay(day) == '오늘'
                  ? clockLabel(momentTime(first))
                  : day == null
                  ? ''
                  : relativeDay(day),
              style: V2Text.cap.copyWith(color: p.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// "지난 기록": one month with a count summary.
class MomentMonthSection extends StatelessWidget {
  final DateTime month;
  final List<List<Moment>> groups;
  final int bothDays;
  final bool gridView;
  final String baseUrl;
  final int? myUserId;
  final String myName;
  final String partnerName;
  final MomentGroupTap onTap;

  const MomentMonthSection({
    super.key,
    required this.month,
    required this.groups,
    required this.bothDays,
    required this.gridView,
    required this.baseUrl,
    required this.myUserId,
    required this.myName,
    required this.partnerName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final total = groups.fold<int>(0, (sum, g) => sum + 1);
    final now = DateTime.now();
    final title = month.year == now.year
        ? '${month.month}월'
        : '${month.year}년 ${month.month}월';
    return Padding(
      padding: const EdgeInsets.only(bottom: V2Space.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: V2Text.head.copyWith(color: p.ink)),
          ),
          const SizedBox(height: 2),
          Text(
            '기록 $total개 · 둘의 순간 $bothDays일',
            style: V2Text.cap.copyWith(color: p.sub),
          ),
          const SizedBox(height: V2Space.x3),
          if (gridView)
            MomentGrid(
              groups: groups,
              baseUrl: baseUrl,
              myUserId: myUserId,
              myName: myName,
              partnerName: partnerName,
              onTap: onTap,
            )
          else
            for (final g in groups)
              MomentListRow(
                group: g,
                baseUrl: baseUrl,
                isMine: g.first.userId == myUserId,
                authorName: g.first.userId == myUserId
                    ? myName
                    : (g.first.userName ?? partnerName),
                onTap: () => onTap(g),
              ),
        ],
      ),
    );
  }
}

class MomentFeedSkeleton extends StatelessWidget {
  const MomentFeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return V2Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var day = 0; day < 2; day++) ...[
            const V2SkeletonBox(width: 120, height: 16, radius: 8),
            const SizedBox(height: V2Space.x2),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  const Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: V2SkeletonBox(height: 100, radius: V2Radius.ctl),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: V2Space.x5),
          ],
        ],
      ),
    );
  }
}
