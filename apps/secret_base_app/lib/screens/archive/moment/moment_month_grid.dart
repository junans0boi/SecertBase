import 'package:flutter/material.dart';

import '../../../features/moment_loop/domain/moment.dart';
import '../../../v2/v2.dart';
import 'moment_days.dart';
import 'moment_format.dart';

/// 달력: one month, each day split in half — my photo on the left, the
/// partner's on the right — so the days we both kept stand out.
class MomentMonthGrid extends StatefulWidget {
  const MomentMonthGrid({
    super.key,
    required this.pages,
    required this.baseUrl,
    required this.partnerName,
    required this.onPickDay,
  });

  final List<MomentDayPage> pages;
  final String baseUrl;
  final String partnerName;
  final ValueChanged<DateTime> onPickDay;

  @override
  State<MomentMonthGrid> createState() => _MomentMonthGridState();
}

class _MomentMonthGridState extends State<MomentMonthGrid> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime get _earliest {
    if (widget.pages.isEmpty) return _month;
    final d = widget.pages.last.day;
    return DateTime(d.year, d.month);
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final today = dateOnly(now);
    final byKey = {for (final pg in widget.pages) dayKey(pg.day): pg};
    final first = DateTime(_month.year, _month.month);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday first
    var kept = 0;
    var both = 0;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
    ];
    for (var d = 1; d <= days; d++) {
      final date = DateTime(_month.year, _month.month, d);
      final page = byKey[dayKey(date)];
      if (page != null) {
        kept++;
        if (page.hasMine && page.hasTheirs) both++;
      }
      cells.add(
        _SplitCell(
          key: Key('moment_day_cell_${dayKey(date)}'),
          day: d,
          page: page,
          baseUrl: widget.baseUrl,
          today: date == today,
          future: date.isAfter(today),
          onTap: page == null ? null : () => widget.onPickDay(date),
        ),
      );
    }
    final canPrev = _month.isAfter(_earliest);
    final canNext = _month.isBefore(thisMonth);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        Row(
          children: [
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${_month.year}년 ${_month.month}월',
                style: V2Text.head.copyWith(fontSize: 19),
              ),
            ),
            IconButton(
              tooltip: '이전 달',
              onPressed: canPrev
                  ? () => setState(
                      () => _month = DateTime(_month.year, _month.month - 1),
                    )
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: '다음 달',
              onPressed: canNext
                  ? () => setState(
                      () => _month = DateTime(_month.year, _month.month + 1),
                    )
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final w in ['일', '월', '화', '수', '목', '금', '토'])
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: V2Text.label.copyWith(
                      color: p.muted,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          key: const Key('moment_month_grid'),
          crossAxisCount: 7,
          shrinkWrap: true,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: .72,
          physics: const NeverScrollableScrollPhysics(),
          children: cells,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _Legend(color: p.me, label: '나만'),
            _Legend(color: p.partner, label: '${widget.partnerName}만'),
            _Legend(color: p.me, color2: p.partner, label: '둘 다'),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${_month.month}월에 $kept일 남겼어요 · 둘 다 남긴 날 $both일',
          key: const Key('moment_month_summary'),
          style: V2Text.cap,
        ),
      ],
    );
  }
}

class _SplitCell extends StatelessWidget {
  const _SplitCell({
    super.key,
    required this.day,
    required this.page,
    required this.baseUrl,
    required this.today,
    required this.future,
    this.onTap,
  });

  final int day;
  final MomentDayPage? page;
  final String baseUrl;
  final bool today;
  final bool future;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final pg = page;
    Widget half(Moment? m) => m == null
        ? ColoredBox(color: p.soft)
        : MomentFill(
            moment: m,
            baseUrl: baseUrl,
            blur: m.todayLocked,
            cacheWidth: 160,
          );
    final label = Text(
      '$day',
      style: V2Text.label.copyWith(
        fontSize: 11.5,
        letterSpacing: 0,
        color: pg != null ? Colors.white : (future ? p.disabled : p.muted),
        shadows: pg != null
            ? const [Shadow(color: Colors.black54, blurRadius: 3)]
            : null,
      ),
    );
    final cell = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (pg == null)
            ColoredBox(color: future ? Colors.transparent : p.soft)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: half(pg.hasMine ? pg.mine.first : null)),
                const SizedBox(width: 1),
                Expanded(child: half(pg.hasTheirs ? pg.theirs.first : null)),
              ],
            ),
          Positioned(left: 5, top: 3, child: label),
          if (today)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.primary, width: 2),
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return ExcludeSemantics(child: cell);
    final who = pg!.hasMine && pg.hasTheirs
        ? '둘 다'
        : (pg.hasMine ? '나만' : '상대만');
    return Semantics(
      button: true,
      label: '$day일 기록 보기, $who',
      child: GestureDetector(
        onTap: onTap,
        child: ExcludeSemantics(child: cell),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, this.color2, required this.label});

  final Color color;
  final Color? color2;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            width: 12,
            height: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: ColoredBox(color: color)),
                Expanded(child: ColoredBox(color: color2 ?? color)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: V2Text.cap),
      ],
    );
  }
}
