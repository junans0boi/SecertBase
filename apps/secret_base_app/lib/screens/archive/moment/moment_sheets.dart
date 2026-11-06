import 'package:flutter/material.dart';

import '../../../features/moment_loop/application/upload_outbox.dart';
import '../../../v2/v2.dart';
import 'moment_format.dart';

/// 업로드 상태 한 줄: 올리는 중 / 실패(이유) / 대기.
class MomentUploadBanner extends StatelessWidget {
  final List<UploadDraft> drafts;
  final VoidCallback onRetry;
  final VoidCallback onOpen;

  const MomentUploadBanner({
    super.key,
    required this.drafts,
    required this.onRetry,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (drafts.isEmpty) return const SizedBox.shrink();
    final failed = drafts.where((d) => d.status == UploadDraftStatus.failed);
    final uploading = drafts.where(
      (d) => d.status == UploadDraftStatus.uploading,
    );
    if (failed.isNotEmpty) {
      final first = failed.first;
      final reason = momentFailureReason(first.error);
      final needsEdit = momentFailureNeedsEdit(first.error);
      return V2Banner(
        key: const Key('moment_upload_banner'),
        tone: V2BannerTone.err,
        title: failed.length > 1
            ? '기록 ${failed.length}개를 올리지 못했어요'
            : '기록을 올리지 못했어요',
        message: reason,
        actionLabel: needsEdit ? '고치기' : '다시 시도',
        onAction: needsEdit ? onOpen : onRetry,
      );
    }
    if (uploading.isNotEmpty) {
      final d = uploading.first;
      return V2Banner(
        key: const Key('moment_upload_banner'),
        tone: V2BannerTone.info,
        message: '올리는 중이에요 · ${d.uploadedCount}/${d.fileCount}',
        actionLabel: '자세히',
        onAction: onOpen,
      );
    }
    return V2Banner(
      key: const Key('moment_upload_banner'),
      tone: V2BannerTone.info,
      message: '올릴 준비를 하고 있어요',
      actionLabel: '자세히',
      onAction: onOpen,
    );
  }
}

/// 업로드 관리 시트 본문.
class MomentDraftsSheet extends StatelessWidget {
  final UploadOutbox outbox;
  final void Function(String id) onOpenDraft;
  final VoidCallback onRetry;

  const MomentDraftsSheet({
    super.key,
    required this.outbox,
    required this.onOpenDraft,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: outbox,
      builder: (context, _) {
        final drafts = outbox.drafts;
        if (drafts.isEmpty) {
          return const V2EmptyState(
            illustration: V2SceneIllustration(V2Scene.photo),
            title: '기다리는 기록이 없어요',
            body: '올리는 중이거나 올리지 못한 기록이 여기에 모여요.',
          );
        }
        return V2List(
          children: [
            for (final d in drafts)
              V2ListTile(
                key: Key('moment_draft_${d.id}'),
                icon: d.status == UploadDraftStatus.failed
                    ? V2Icons.warn
                    : V2Icons.refresh,
                tone: d.status == UploadDraftStatus.failed
                    ? V2Tone.err
                    : V2Tone.sky,
                title: d.caption.trim().isEmpty ? '사진·영상 기록' : d.caption,
                subtitle: switch (d.status) {
                  UploadDraftStatus.failed =>
                    '${momentFailureReason(d.error)} · ${d.uploadedCount}/${d.fileCount}',
                  UploadDraftStatus.uploading =>
                    '올리는 중이에요 · ${d.uploadedCount}/${d.fileCount}',
                  _ => '올릴 차례를 기다려요 · ${d.uploadedCount}/${d.fileCount}',
                },
                trailing: d.status == UploadDraftStatus.uploading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : d.status == UploadDraftStatus.failed &&
                          !momentFailureNeedsEdit(d.error)
                    ? V2IconButton(
                        icon: V2Icons.refresh,
                        tooltip: '다시 올리기',
                        onPressed: onRetry,
                      )
                    : null,
                onTap: d.status == UploadDraftStatus.uploading
                    ? null
                    : () => onOpenDraft(d.id),
              ),
          ],
        );
      },
    );
  }
}

/// 달력 시트: 기록 있는 날에 점, 날짜를 누르면 그 주로 이동.
class MomentCalendarSheet extends StatefulWidget {
  final DateTime month;
  final Set<String> daysWithMoments;
  final ValueChanged<DateTime> onDay;

  const MomentCalendarSheet({
    super.key,
    required this.month,
    required this.daysWithMoments,
    required this.onDay,
  });

  @override
  State<MomentCalendarSheet> createState() => _MomentCalendarSheetState();
}

class _MomentCalendarSheetState extends State<MomentCalendarSheet> {
  late DateTime _month = DateTime(widget.month.year, widget.month.month);

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final today = dateOnly(DateTime.now());
    final first = _month;
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final lead = first.weekday - 1;
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();
    final canNext = DateTime(first.year, first.month + 1).isBefore(today);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            V2IconButton(
              icon: Icons.chevron_left_rounded,
              tooltip: '이전 달',
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1),
              ),
            ),
            Expanded(
              child: Text(
                '${_month.year}년 ${_month.month}월',
                textAlign: TextAlign.center,
                style: V2Text.head.copyWith(color: p.ink),
              ),
            ),
            V2IconButton(
              icon: Icons.chevron_right_rounded,
              tooltip: '다음 달',
              onPressed: canNext
                  ? () => setState(
                      () => _month = DateTime(_month.year, _month.month + 1),
                    )
                  : null,
            ),
          ],
        ),
        Row(
          children: [
            for (final d in const ['월', '화', '수', '목', '금', '토', '일'])
              Expanded(
                child: Center(
                  child: Text(d, style: V2Text.label.copyWith(color: p.sub)),
                ),
              ),
          ],
        ),
        const SizedBox(height: V2Space.x1),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: _cell(r * 7 + c - lead + 1, daysInMonth, today, p),
                ),
            ],
          ),
      ],
    );
  }

  Widget _cell(int day, int daysInMonth, DateTime today, V2Palette p) {
    if (day < 1 || day > daysInMonth) {
      return const SizedBox(height: V2Space.tap);
    }
    final date = DateTime(_month.year, _month.month, day);
    final future = date.isAfter(today);
    final has = widget.daysWithMoments.contains(dayKey(date));
    final isToday = date == today;
    return Semantics(
      button: !future,
      label: '${date.month}월 $day일${has ? ', 기록 있음' : ''}',
      onTap: future ? null : () => widget.onDay(date),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: future ? null : () => widget.onDay(date),
          borderRadius: BorderRadius.circular(V2Radius.ctl),
          child: SizedBox(
            height: V2Space.tap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isToday ? p.primarySoft : null,
                  ),
                  child: Text(
                    '$day',
                    style: V2Text.bodyStrong.copyWith(
                      color: future
                          ? p.disabled
                          : (isToday ? p.onPrimarySoft : p.ink),
                    ),
                  ),
                ),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: has ? p.primary : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
