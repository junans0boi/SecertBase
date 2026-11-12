import 'package:flutter/material.dart';

import '../../../core/today_api.dart';
import '../../../features/moment_loop/domain/moment.dart';
import '../../../v2/v2.dart';
import 'moment_days.dart';
import 'moment_format.dart';
import 'moment_month_grid.dart';

/// 우리의 하루: a vertical feed of day cards. Each card has a row for me and
/// a row for the partner; each row scrolls sideways through everything that
/// person kept that day. A 달력 view jumps to a day.
class MomentDayFeed extends StatefulWidget {
  const MomentDayFeed({
    super.key,
    required this.pages,
    required this.baseUrl,
    required this.myName,
    required this.partnerName,
    required this.calendar,
    required this.onCalendar,
    required this.onCompose,
    required this.onOpenDay,
    required this.onLocked,
    this.today,
    this.banner,
    this.jumpTo,
  });

  final List<MomentDayPage> pages;
  final String baseUrl;
  final String myName;
  final String partnerName;

  /// 달력 instead of the feed.
  final bool calendar;
  final ValueChanged<bool> onCalendar;

  /// New record; [date] when it belongs to a given day, [todayMoment] when
  /// it should become today's 오늘의 순간.
  final void Function({DateTime? date, bool todayMoment}) onCompose;

  /// Opens the day viewer at [start].
  final void Function(MomentDayPage page, Moment start) onOpenDay;

  /// A partner's 오늘의 순간 I can't see yet was tapped.
  final VoidCallback onLocked;
  final TodayState? today;
  final Widget? banner;

  /// Scrolls to this day when it changes (calendar pick, after posting).
  final DateTime? jumpTo;

  @override
  State<MomentDayFeed> createState() => _MomentDayFeedState();
}

class _MomentDayFeedState extends State<MomentDayFeed> {
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};

  static const _estimatedCard = 560.0;

  @override
  void initState() {
    super.initState();
    _scheduleJump(widget.jumpTo);
  }

  @override
  void didUpdateWidget(covariant MomentDayFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.jumpTo != oldWidget.jumpTo ||
        (widget.calendar != oldWidget.calendar && !widget.calendar)) {
      _scheduleJump(widget.jumpTo);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scheduleJump(DateTime? day) {
    if (day == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _jump(day));
  }

  void _jump(DateTime day) {
    if (!mounted || !_scroll.hasClients) return;
    final key = dayKey(dateOnly(day));
    final i = widget.pages.indexWhere((p) => dayKey(p.day) == key);
    if (i < 0) return;
    final built = _keys[key]?.currentContext;
    if (built != null) {
      Scrollable.ensureVisible(built, duration: Duration.zero);
      return;
    }
    // Not built yet: jump near it, then align once it exists.
    final pos = _scroll.position;
    _scroll.jumpTo((i * _estimatedCard).clamp(0, pos.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[key]?.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(ctx, duration: Duration.zero);
      }
    });
  }

  bool get _partnerWaitingForMe {
    final t = widget.today;
    return t != null && t.hasPartnerMoment && t.myMoment == null;
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(V2Space.page, 8, 12, 4),
      child: Row(
        children: [
          Expanded(child: Text('우리의 하루', style: V2Text.title)),
          IconButton.filled(
            key: const Key('moment_add'),
            tooltip: '기록 남기기',
            style: IconButton.styleFrom(
              backgroundColor: p.primary,
              foregroundColor: p.onPrimary,
              minimumSize: const Size(44, 44),
            ),
            onPressed: () => widget.onCompose(),
            icon: const Icon(V2Icons.add),
          ),
        ],
      ),
    );
    final toggle = Padding(
      padding: const EdgeInsets.fromLTRB(V2Space.page, 4, V2Space.page, 8),
      child: Row(
        children: [
          _Seg(
            key: const Key('moment_view_feed'),
            label: '피드',
            on: !widget.calendar,
            onTap: () => widget.onCalendar(false),
          ),
          const SizedBox(width: 6),
          _Seg(
            key: const Key('moment_calendar_toggle'),
            label: '달력',
            on: widget.calendar,
            onTap: () => widget.onCalendar(true),
          ),
        ],
      ),
    );
    final Widget body;
    if (widget.calendar) {
      body = MomentMonthGrid(
        pages: widget.pages,
        baseUrl: widget.baseUrl,
        partnerName: widget.partnerName,
        onPickDay: (day) {
          widget.onCalendar(false);
          _scheduleJump(day);
        },
      );
    } else {
      final lead = <Widget>[
        if (widget.banner != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              V2Space.page,
              0,
              V2Space.page,
              10,
            ),
            child: widget.banner,
          ),
        if (_partnerWaitingForMe)
          _TodayStrip(
            partnerName: widget.partnerName,
            onTap: () => widget.onCompose(
              date: dateOnly(DateTime.now()),
              todayMoment: true,
            ),
          ),
      ];
      if (widget.pages.isEmpty) {
        body = ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ...lead,
            const SizedBox(height: 40),
            V2EmptyState(
              illustration: const V2SceneIllustration(V2Scene.hearts),
              title: '첫 기록을 남겨 볼까요?',
              body: '사진 찍은 날로 쌓여요. 지난 데이트도 그날에 남길 수 있어요.',
              actionLabel: '기록 남기기',
              onAction: () => widget.onCompose(),
            ),
          ],
        );
      } else {
        body = ListView.builder(
          key: const Key('moment_day_feed'),
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: lead.length + widget.pages.length,
          itemBuilder: (context, i) {
            if (i < lead.length) return lead[i];
            final page = widget.pages[i - lead.length];
            final key = _keys.putIfAbsent(
              dayKey(page.day),
              () => GlobalKey(debugLabel: dayKey(page.day)),
            );
            return MomentDayCard(
              key: key,
              page: page,
              baseUrl: widget.baseUrl,
              myName: widget.myName,
              partnerName: widget.partnerName,
              onFill: () => widget.onCompose(date: page.day),
              onOpen: (m) => widget.onOpenDay(page, m),
              onLocked: widget.onLocked,
            );
          },
        );
      }
    }
    return ColoredBox(
      color: p.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            toggle,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        color: on ? p.ink : p.soft,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36, minWidth: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: V2Text.buttonSm.copyWith(color: on ? p.bg : p.sub),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayStrip extends StatelessWidget {
  const _TodayStrip({required this.partnerName, required this.onTap});

  final String partnerName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(V2Space.page, 0, V2Space.page, 14),
      child: Material(
        color: p.primarySoft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const Key('moment_today_strip'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: p.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(V2Icons.lock, color: p.onPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${josa(partnerName, '이', '가')} 오늘의 순간을 올렸어요',
                        style: V2Text.bodyStrong,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '내 순간을 올리면 바로 열려요',
                        style: V2Text.cap.copyWith(color: p.onPrimarySoft),
                      ),
                    ],
                  ),
                ),
                Icon(V2Icons.chevron, color: p.onPrimarySoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One day: header, my row, the partner's row, captions and reactions.
class MomentDayCard extends StatelessWidget {
  const MomentDayCard({
    super.key,
    required this.page,
    required this.baseUrl,
    required this.myName,
    required this.partnerName,
    required this.onFill,
    required this.onOpen,
    required this.onLocked,
  });

  final MomentDayPage page;
  final String baseUrl;
  final String myName;
  final String partnerName;
  final VoidCallback onFill;
  final ValueChanged<Moment> onOpen;
  final VoidCallback onLocked;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final places = page.places;
    final sub = [
      if (places.isNotEmpty) places.take(2).join(' · '),
      '${page.count}개',
    ].join(' · ');
    // One caption per post (session), newest last, at most two lines.
    final captions = <({bool mine, String text})>[];
    final seen = <String>{};
    for (final m in page.all) {
      final text = (m.caption ?? '').trim();
      if (m.todayLocked || text.isEmpty || !seen.add(m.sessionKey)) continue;
      captions.add((mine: page.mine.contains(m), text: text));
    }
    final sessions = <String, Moment>{
      for (final m in page.all)
        if (!m.todayLocked) m.sessionKey: m,
    };
    final hearts = sessions.values.fold<int>(
      0,
      (n, m) => n + m.reactions.length,
    );
    final comments = page.all.fold<int>(0, (n, m) => n + m.commentCount);
    return Padding(
      key: Key('moment_day_${dayKey(page.day)}'),
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              V2Space.page,
              0,
              V2Space.page,
              10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    momentFeedDayLong(page.day),
                    style: V2Text.bodyStrong.copyWith(fontSize: 16),
                  ),
                ),
                Flexible(
                  child: Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V2Text.cap,
                  ),
                ),
              ],
            ),
          ),
          _Lane(
            key: Key('moment_lane_me_${dayKey(page.day)}'),
            name: '나',
            color: p.me,
            items: page.mine,
            baseUrl: baseUrl,
            empty: _EmptyLane(
              key: Key('moment_fill_${dayKey(page.day)}'),
              text: '내 하루 채우기',
              icon: V2Icons.add,
              onTap: onFill,
            ),
            onOpen: onOpen,
            onLocked: onLocked,
          ),
          const SizedBox(height: 10),
          _Lane(
            key: Key('moment_lane_partner_${dayKey(page.day)}'),
            name: partnerName,
            color: p.partner,
            items: page.theirs,
            baseUrl: baseUrl,
            empty: _EmptyLane(
              text: '$partnerName의 하루를 기다려요',
              icon: V2Icons.heart,
            ),
            onOpen: onOpen,
            onLocked: onLocked,
          ),
          if (captions.isNotEmpty || hearts > 0 || comments > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                V2Space.page,
                10,
                V2Space.page,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final c in captions.take(2))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: c.mine ? '나 ' : '$partnerName ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(text: c.text),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: V2Text.body.copyWith(fontSize: 14.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (hearts > 0 || comments > 0)
                    Semantics(
                      button: true,
                      label: '하트 $hearts개, 댓글 $comments개, 크게 보기',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          final first = page.all
                              .where((m) => !m.todayLocked)
                              .firstOrNull;
                          if (first != null) onOpen(first);
                        },
                        child: ExcludeSemantics(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(V2Icons.heart, size: 18, color: p.sub),
                                const SizedBox(width: 3),
                                Text('$hearts', style: V2Text.cap),
                                const SizedBox(width: 10),
                                Icon(V2Icons.chat, size: 18, color: p.sub),
                                const SizedBox(width: 3),
                                Text('$comments', style: V2Text.cap),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({
    super.key,
    required this.name,
    required this.color,
    required this.items,
    required this.baseUrl,
    required this.empty,
    required this.onOpen,
    required this.onLocked,
  });

  final String name;
  final Color color;
  final List<Moment> items;
  final String baseUrl;
  final Widget empty;
  final ValueChanged<Moment> onOpen;
  final VoidCallback onLocked;

  static const tileWidth = 150.0;
  static const tileHeight = 200.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(V2Space.page, 0, V2Space.page, 6),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(name, style: V2Text.label.copyWith(letterSpacing: 0)),
              if (items.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text('${items.length}', style: V2Text.cap),
              ],
            ],
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.page),
            child: empty,
          )
        else
          SizedBox(
            height: tileHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: V2Space.page),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) => _Tile(
                moment: items[i],
                baseUrl: baseUrl,
                onTap: items[i].todayLocked ? onLocked : () => onOpen(items[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.moment,
    required this.baseUrl,
    required this.onTap,
  });

  final Moment moment;
  final String baseUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = moment;
    final time = clockLabel(momentTime(m));
    final label = m.todayLocked
        ? '잠긴 오늘의 순간'
        : '${m.isVideo ? '영상' : (m.hasMedia ? '사진' : '글')} $time';
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: Key('moment_tile_${m.id}'),
        onTap: onTap,
        child: ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: _Lane.tileWidth,
              height: _Lane.tileHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MomentFill(
                    moment: m,
                    baseUrl: baseUrl,
                    blur: m.todayLocked,
                    cacheWidth: 480,
                  ),
                  if (m.todayLocked)
                    Container(
                      color: Colors.black.withValues(alpha: .25),
                      padding: const EdgeInsets.all(10),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(V2Icons.lock, color: Colors.white),
                          const SizedBox(height: 6),
                          Text(
                            '내 순간을 올리면\n열려요',
                            textAlign: TextAlign.center,
                            style: V2Text.cap.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    )
                  else if (time.isNotEmpty)
                    Positioned(
                      left: 8,
                      bottom: 6,
                      child: Text(
                        time,
                        style: V2Text.label.copyWith(
                          color: Colors.white,
                          fontSize: 11.5,
                          letterSpacing: 0,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
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
}

class _EmptyLane extends StatelessWidget {
  const _EmptyLane({
    super.key,
    required this.text,
    required this.icon,
    this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final box = Container(
      height: 64,
      decoration: BoxDecoration(
        color: p.soft,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: onTap == null ? p.muted : p.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: V2Text.body.copyWith(
                fontSize: 14,
                color: onTap == null ? p.muted : p.ink,
                fontWeight: onTap == null ? null : FontWeight.w600,
              ),
            ),
          ),
          if (onTap != null) Icon(V2Icons.chevron, color: p.control),
        ],
      ),
    );
    if (onTap == null) return box;
    return Semantics(
      button: true,
      child: GestureDetector(onTap: onTap, child: box),
    );
  }
}
