import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/upload_image.dart';
import '../../../features/moment_loop/domain/moment.dart';
import '../../../v2/v2.dart';
import 'moment_format.dart';

/// 기록 2.1: a dark, one-day-per-page feed (SNS style), a stories row, a big
/// "내 순간 올리기" button for today, and a calendar view to jump around.
/// The screen owns loading and uploads; this file is presentation only.

const _feedBg = Color(0xFF0C0C0E);
const _sheetBg = Color(0xFF1C1C20);

/// How the composer should start when opened from the feed.
enum MomentStartSource { none, camera, gallery }

/// One day of the feed: my posts and the partner's posts.
class MomentDayPage {
  MomentDayPage(this.day, this.mine, this.theirs);

  final DateTime day;
  final List<Moment> mine;
  final List<Moment> theirs;

  bool get hasMine => mine.isNotEmpty;
  bool get hasTheirs => theirs.isNotEmpty;
}

/// Groups posts into day pages, newest day first. Posts in a day keep their
/// order (session position, then capture time).
List<MomentDayPage> buildMomentDayPages(Iterable<Moment> moments, int? me) {
  final byDay = <String, MomentDayPage>{};
  for (final m in moments) {
    final d = momentDay(m);
    if (d == null) continue;
    final page = byDay.putIfAbsent(dayKey(d), () => MomentDayPage(d, [], []));
    (m.userId == me ? page.mine : page.theirs).add(m);
  }
  int order(Moment a, Moment b) {
    final t = (a.capturedAt ?? a.takenAt ?? '').compareTo(
      b.capturedAt ?? b.takenAt ?? '',
    );
    return t != 0 ? t : a.position.compareTo(b.position);
  }

  for (final p in byDay.values) {
    p.mine.sort(order);
    p.theirs.sort(order);
  }
  return byDay.values.toList()..sort((a, b) => b.day.compareTo(a.day));
}

String momentFeedDayLabel(DateTime day, [DateTime? now]) {
  final today = dateOnly(now ?? DateTime.now());
  final diff = today.difference(dateOnly(day)).inDays;
  if (diff == 0) return '오늘';
  if (diff == 1) return '어제';
  return '${day.month}/${day.day}';
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

String momentFeedDayLong(DateTime day, [DateTime? now]) {
  final short = momentFeedDayLabel(day, now);
  final md = '${day.month}월 ${day.day}일 ${_weekdays[day.weekday - 1]}';
  return short == '오늘' || short == '어제' ? '$short · $md' : md;
}

/// Photo/video/text fill for one post.
class MomentFill extends StatelessWidget {
  const MomentFill({
    super.key,
    required this.moment,
    required this.baseUrl,
    this.blur = false,
    this.cacheWidth,
  });

  final Moment? moment;
  final String baseUrl;
  final bool blur;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final m = moment;
    Widget fill;
    if (m == null) {
      fill = const V2PhotoPlaceholder(seed: 'none');
    } else if (m.isVideo) {
      fill = Stack(
        fit: StackFit.expand,
        children: [
          V2PhotoPlaceholder(seed: m.id),
          const Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 52,
            ),
          ),
        ],
      );
    } else if (m.mediaUrl != null && m.mediaType != 'text') {
      fill = UploadImage(
        raw: m.mediaUrl!,
        baseUrl: baseUrl,
        pixelWidth: cacheWidth,
        error: V2PhotoPlaceholder(seed: m.id),
      );
    } else {
      fill = Container(
        color: const Color(0xFF2B2440),
        padding: const EdgeInsets.fromLTRB(28, 140, 28, 200),
        alignment: Alignment.center,
        child: Text(
          m.caption ?? '',
          textAlign: TextAlign.center,
          style: V2Text.sans(
            size: 22,
            weight: FontWeight.w700,
            color: Colors.white,
            height: 1.45,
          ),
        ),
      );
    }
    if (!blur) return fill;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
      child: Transform.scale(scale: 1.15, child: fill),
    );
  }
}

/// The feed itself.
class MomentStoryFeed extends StatefulWidget {
  const MomentStoryFeed({
    super.key,
    required this.pages,
    required this.showTodayCta,
    required this.partnerPostedToday,
    required this.partnerTodayMoment,
    required this.baseUrl,
    required this.myUserId,
    required this.myName,
    required this.partnerName,
    required this.onCompose,
    required this.onOpenGroup,
    required this.onHeart,
    required this.onComments,
    required this.onShowCalendar,
    this.banner,
    this.jumpTo,
  });

  final List<MomentDayPage> pages;

  /// I have not posted today: the first page is the "내 순간 올리기" page.
  final bool showTodayCta;
  final bool partnerPostedToday;
  final Moment? partnerTodayMoment;
  final String baseUrl;
  final int? myUserId;
  final String myName;
  final String partnerName;
  final void Function(MomentStartSource source) onCompose;
  final Future<void> Function(List<Moment> group) onOpenGroup;
  final Future<void> Function(Moment post) onHeart;
  final Future<void> Function(Moment post) onComments;
  final VoidCallback onShowCalendar;

  /// Upload / storage banner shown under the stories row.
  final Widget? banner;

  /// Scrolls to this day when it changes (calendar pick, after posting).
  final DateTime? jumpTo;

  @override
  State<MomentStoryFeed> createState() => _MomentStoryFeedState();
}

class _MomentStoryFeedState extends State<MomentStoryFeed> {
  final _pager = PageController();
  final _stories = ScrollController();
  int _index = 0;

  /// Stories stop while a sheet or the full view is open.
  bool _hold = false;

  int get _offset => widget.showTodayCta ? 1 : 0;
  int get _count => widget.pages.length + _offset;

  @override
  void didUpdateWidget(covariant MomentStoryFeed old) {
    super.didUpdateWidget(old);
    final target = widget.jumpTo;
    if (target != null && target != old.jumpTo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jump(target));
    }
  }

  @override
  void initState() {
    super.initState();
    final target = widget.jumpTo;
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jump(target));
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    _stories.dispose();
    super.dispose();
  }

  void _jump(DateTime day) {
    if (!mounted || !_pager.hasClients) return;
    final key = dayKey(dateOnly(day));
    final i = widget.pages.indexWhere((p) => dayKey(p.day) == key);
    final page = i < 0 ? 0 : i + _offset;
    _pager.jumpToPage(page);
  }

  void _goTo(int page) {
    if (!_pager.hasClients) return;
    _pager.animateToPage(
      page,
      duration: V2Motion.of(context, V2Motion.base),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPage(int i) {
    setState(() => _index = i);
    if (!_stories.hasClients) return;
    final target = (i * 66.0) - 120;
    _stories.animateTo(
      target.clamp(0, _stories.position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Moment? _thumb(MomentDayPage p) => p.mine.isNotEmpty
      ? p.mine.first
      : (p.theirs.isEmpty ? null : p.theirs.first);

  Future<void> _holdWhile(Future<void> Function() action) async {
    setState(() => _hold = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _hold = false);
    }
  }

  Future<void> _chooseSource() async {
    final source = await showModalBottomSheet<MomentStartSource>(
      context: context,
      backgroundColor: _sheetBg,
      shape: const RoundedRectangleBorder(borderRadius: V2Radius.sheetTop),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '오늘의 순간 올리기',
                style: V2Text.head.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              _SourceRow(
                key: const Key('moment_source_camera'),
                icon: V2Icons.camera,
                title: '카메라로 찍기',
                sub: '지금 이 순간을 바로 찍어요',
                onTap: () => Navigator.pop(ctx, MomentStartSource.camera),
              ),
              _SourceRow(
                key: const Key('moment_source_gallery'),
                icon: V2Icons.gallery,
                title: '앨범에서 고르기',
                sub: '오늘 찍어 둔 사진을 골라요',
                onTap: () => Navigator.pop(ctx, MomentStartSource.gallery),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  '취소',
                  style: V2Text.body.copyWith(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null && mounted) widget.onCompose(source);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: _feedBg,
      child: Stack(
        children: [
          PageView.builder(
            key: const Key('moment_story_pages'),
            controller: _pager,
            scrollDirection: Axis.vertical,
            itemCount: _count,
            onPageChanged: _onPage,
            itemBuilder: (context, i) {
              if (widget.showTodayCta && i == 0) return _todayCta();
              final page = widget.pages[i - _offset];
              return _StoryDay(
                key: ValueKey('story-${dayKey(page.day)}'),
                page: page,
                active: i == _index && !_hold,
                baseUrl: widget.baseUrl,
                myUserId: widget.myUserId,
                myName: widget.myName,
                partnerName: widget.partnerName,
                onHeart: widget.onHeart,
                onComments: (m) => _holdWhile(() => widget.onComments(m)),
                onOpen: (g) => _holdWhile(() => widget.onOpenGroup(g)),
                onDone: () {
                  if (i + 1 < _count) _goTo(i + 1);
                },
                onBack: () {
                  if (i > 0) _goTo(i - 1);
                },
              );
            },
          ),
          // Top: title, buttons, stories.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              child: Container(
                height: top + 170,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 10,
            top: top + 4,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '기록',
                    style: V2Text.sans(
                      size: 22,
                      weight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                _GlassButton(
                  key: const Key('moment_calendar_toggle'),
                  icon: Icons.grid_view_rounded,
                  tooltip: '모아보기',
                  onTap: widget.onShowCalendar,
                ),
                const SizedBox(width: 8),
                _GlassButton(
                  key: const Key('moment_add'),
                  icon: V2Icons.add,
                  tooltip: '순간 남기기',
                  onTap: () => widget.onCompose(MomentStartSource.none),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: top + 50,
            height: 80,
            child: _storiesRow(),
          ),
          if (widget.banner != null)
            Positioned(
              left: 16,
              right: 16,
              top: top + 134,
              child: widget.banner!,
            ),
        ],
      ),
    );
  }

  Widget _storiesRow() {
    final items = <({String label, Moment? thumb, bool locked, bool fresh})>[
      if (widget.showTodayCta)
        (
          label: '오늘',
          thumb: widget.partnerTodayMoment,
          locked: true,
          fresh: widget.partnerPostedToday,
        ),
      for (final p in widget.pages.take(30))
        (
          label: momentFeedDayLabel(p.day),
          thumb: _thumb(p),
          locked: false,
          fresh: momentFeedDayLabel(p.day) == '오늘',
        ),
    ];
    return ListView.separated(
      controller: _stories,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, i) {
        final it = items[i];
        final on = i == _index;
        final ring = it.fresh
            ? SweepGradient(
                colors: [V2Colors.rose, const Color(0xFFFFC46B), V2Colors.rose],
              )
            : null;
        return Semantics(
          button: true,
          selected: on,
          label: '${it.label} 기록으로 가기',
          child: GestureDetector(
            onTap: () => _goTo(i),
            child: SizedBox(
              width: 54,
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: ring,
                      color: ring == null ? Colors.white38 : null,
                      boxShadow: on
                          ? const [
                              BoxShadow(color: Colors.white, spreadRadius: 2),
                            ]
                          : null,
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _feedBg,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            MomentFill(
                              moment: it.thumb,
                              baseUrl: widget.baseUrl,
                              blur: it.locked,
                              cacheWidth: 120,
                            ),
                            if (it.locked)
                              const ColoredBox(
                                color: Color(0x55000000),
                                child: Icon(
                                  V2Icons.lock,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    it.label,
                    maxLines: 1,
                    style: V2Text.label.copyWith(
                      color: Colors.white.withValues(alpha: on ? 1 : .72),
                      letterSpacing: 0,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _todayCta() {
    final partnerFirst = widget.partnerPostedToday;
    return Stack(
      key: const Key('moment_today_cta'),
      fit: StackFit.expand,
      children: [
        MomentFill(
          moment: widget.partnerTodayMoment,
          baseUrl: widget.baseUrl,
          blur: true,
          cacheWidth: 400,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x8C000000), Color(0x59000000), Color(0xBF000000)],
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, -.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        V2Colors.rose,
                        const Color(0xFFFFC46B),
                        V2Colors.rose,
                      ],
                    ),
                  ),
                  child: V2Avatar(
                    name: partnerFirst ? widget.partnerName : widget.myName,
                    color: partnerFirst
                        ? V2Avatar.partnerColor
                        : V2Avatar.meColor,
                    size: V2AvatarSize.lg,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  partnerFirst
                      ? '${josa(widget.partnerName, '이', '가')} 오늘의 순간을 올렸어요'
                      : '오늘의 첫 순간을 남겨 볼까요?',
                  textAlign: TextAlign.center,
                  style: V2Text.sans(
                    size: 19,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  partnerFirst
                      ? '내 사진을 올리면 서로의 오늘이 열려요'
                      : '${josa(widget.partnerName, '와', '과')} 서로의 오늘을 바꿔 봐요',
                  textAlign: TextAlign.center,
                  style: V2Text.cap.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 28,
          child: Column(
            children: [
              _PulseButton(
                key: const Key('moment_upload_cta'),
                label: '내 순간 올리기',
                onTap: _chooseSource,
              ),
              const SizedBox(height: 10),
              Text(
                '카메라로 찍거나 앨범에서 골라요',
                style: V2Text.cap.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x66000000),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: V2Text.label.copyWith(
          color: Colors.white,
          fontSize: 12,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.zero,
      icon: Icon(icon, color: color, size: 27),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .16),
              border: Border.all(color: Colors.white.withValues(alpha: .14)),
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    super.key,
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: V2Text.bodyStrong.copyWith(color: Colors.white),
                      ),
                      Text(
                        sub,
                        style: V2Text.cap.copyWith(color: Colors.white60),
                      ),
                    ],
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

class _PulseButton extends StatefulWidget {
  const _PulseButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<_PulseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating && _c.value == 0) {
      // A few pulses to draw the eye, then it rests.
      _c.repeat(count: 3);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = V2Colors.rose600;
    return SizedBox(
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              return Transform.scale(
                scale: .96 + t * .12,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: color.withValues(alpha: (1 - t) * .7),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),
          Material(
            color: color,
            shape: const StadiumBorder(),
            elevation: 6,
            shadowColor: Colors.black54,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: widget.onTap,
              child: SizedBox(
                height: 58,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(V2Icons.camera, color: V2Colors.onPrimary, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      widget.label,
                      style: V2Text.sans(
                        size: 16.5,
                        weight: FontWeight.w800,
                        color: V2Colors.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 모아보기: one month of days as a photo calendar.
class MomentMonthGrid extends StatefulWidget {
  const MomentMonthGrid({
    super.key,
    required this.pages,
    required this.baseUrl,
    required this.myUserId,
    required this.todayOpen,
    required this.onPickDay,
    required this.onShowFeed,
  });

  final List<MomentDayPage> pages;
  final String baseUrl;
  final int? myUserId;

  /// I already posted today (today's cell is a photo, not a dashed ring).
  final bool todayOpen;
  final ValueChanged<DateTime> onPickDay;
  final VoidCallback onShowFeed;

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
    final top = MediaQuery.paddingOf(context).top;
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final byKey = {for (final p in widget.pages) dayKey(p.day): p};
    final first = DateTime(_month.year, _month.month);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday first
    var count = 0;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
    ];
    final today = dateOnly(now);
    for (var d = 1; d <= days; d++) {
      final date = DateTime(_month.year, _month.month, d);
      final page = byKey[dayKey(date)];
      final isToday = date == today;
      if (date.isAfter(today)) {
        cells.add(_DayCell(label: '$d', faint: true));
      } else if (isToday && !widget.todayOpen) {
        cells.add(
          _DayCell(
            label: '$d',
            dashed: true,
            onTap: () => widget.onPickDay(date),
          ),
        );
      } else if (page != null) {
        count++;
        final thumb = page.mine.isNotEmpty
            ? page.mine.first
            : page.theirs.first;
        cells.add(
          _DayCell(
            label: '$d',
            today: isToday,
            photo: MomentFill(
              moment: thumb,
              baseUrl: widget.baseUrl,
              blur: thumb.todayLocked,
              cacheWidth: 160,
            ),
            onTap: () => widget.onPickDay(date),
          ),
        );
      } else {
        cells.add(_DayCell(label: '$d'));
      }
    }
    final canPrev = _month.isAfter(_earliest);
    final canNext = _month.isBefore(thisMonth);
    return ColoredBox(
      color: _feedBg,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, top + 8, 16, 32),
        children: [
          _FeedSwitch(onFeed: widget.onShowFeed),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_month.year}년 ${_month.month}월',
                  style: V2Text.head.copyWith(
                    color: Colors.white,
                    fontSize: 19,
                  ),
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
                color: Colors.white,
                disabledColor: Colors.white24,
              ),
              IconButton(
                tooltip: '다음 달',
                onPressed: canNext
                    ? () => setState(
                        () => _month = DateTime(_month.year, _month.month + 1),
                      )
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
                color: Colors.white,
                disabledColor: Colors.white24,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final w in ['일', '월', '화', '수', '목', '금', '토'])
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: V2Text.label.copyWith(
                        color: Colors.white54,
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
            physics: const NeverScrollableScrollPhysics(),
            children: cells,
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${_month.month}월에 '),
                TextSpan(
                  text: '$count일',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' 남겼어요'),
              ],
            ),
            style: V2Text.cap.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _FeedSwitch extends StatelessWidget {
  const _FeedSwitch({required this.onFeed});

  final VoidCallback onFeed;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool on, VoidCallback? tap) => Expanded(
      child: Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          onTap: tap,
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? Colors.white.withValues(alpha: .16) : null,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
              style: V2Text.buttonSm.copyWith(
                color: on ? Colors.white : Colors.white60,
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [seg('한 장씩', false, onFeed), seg('모아보기', true, null)],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    this.photo,
    this.faint = false,
    this.dashed = false,
    this.today = false,
    this.onTap,
  });

  final String label;
  final Widget? photo;
  final bool faint;
  final bool dashed;
  final bool today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = V2Colors.rose;
    Widget cell;
    if (photo != null) {
      cell = ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          fit: StackFit.expand,
          children: [
            photo!,
            Positioned(
              left: 5,
              top: 3,
              child: Text(
                label,
                style: V2Text.label.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                  letterSpacing: 0,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
                ),
              ),
            ),
            if (today)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: accent, width: 2),
                ),
              ),
          ],
        ),
      );
    } else {
      cell = Container(
        alignment: Alignment.center,
        decoration: dashed
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: accent, width: 1.5),
              )
            : null,
        child: Text(
          label,
          style: V2Text.label.copyWith(
            letterSpacing: 0,
            color: dashed
                ? accent
                : Colors.white.withValues(alpha: faint ? .18 : .35),
          ),
        ),
      );
    }
    if (onTap == null) return cell;
    return Semantics(
      button: true,
      label: '$label일 기록 보기',
      child: GestureDetector(onTap: onTap, child: cell),
    );
  }
}

/// One day played like Instagram stories: my items, then the partner's,
/// then the next day. Photos stay [photoTime]; videos play to their end.
/// Tap the right side for next, the left for previous; hold to pause.
class _StoryDay extends StatefulWidget {
  const _StoryDay({
    super.key,
    required this.page,
    required this.active,
    required this.baseUrl,
    required this.myUserId,
    required this.myName,
    required this.partnerName,
    required this.onHeart,
    required this.onComments,
    required this.onOpen,
    required this.onDone,
    required this.onBack,
  });

  static const photoTime = Duration(seconds: 5);

  final MomentDayPage page;

  /// This page is on screen and nothing covers it.
  final bool active;
  final String baseUrl;
  final int? myUserId;
  final String myName;
  final String partnerName;
  final Future<void> Function(Moment post) onHeart;
  final Future<void> Function(Moment post) onComments;
  final Future<void> Function(List<Moment> group) onOpen;
  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  State<_StoryDay> createState() => _StoryDayState();
}

class _StoryDayState extends State<_StoryDay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _StoryDay.photoTime,
  )..addStatusListener(_onClock);
  final _progress = ValueNotifier<double>(0);
  VideoPlayerController? _video;
  int _videoToken = 0;

  /// 0: the first person's items, 1: the other person's.
  int _phase = 0;
  int _i = 0;
  bool _holding = false;

  static bool _playable(Moment m) => !m.todayLocked;

  List<Moment> get _mine => widget.page.mine.where(_playable).toList();
  List<Moment> get _theirs => widget.page.theirs.where(_playable).toList();
  bool get _mineFirst => _mine.isNotEmpty;
  List<Moment> get _first => _mineFirst ? _mine : _theirs;
  List<Moment> get _second => _mineFirst ? _theirs : const [];
  List<Moment> get _list => _phase == 0 ? _first : _second;
  Moment? get _cur =>
      _list.isEmpty ? null : _list[_i.clamp(0, _list.length - 1)];
  bool get _curIsMine => _phase == 0 ? _mineFirst : false;
  List<Moment> get _otherList => _phase == 0 ? _second : _first;

  @override
  void initState() {
    super.initState();
    _clock.addListener(() {
      if (_video == null) _progress.value = _clock.value;
    });
  }

  bool _started = false;

  @override
  void didUpdateWidget(covariant _StoryDay old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      // Back on this day: start over from the first item.
      if (old.page != widget.page || _phase != 0 || _i != 0) {
        _phase = 0;
        _i = 0;
        _start();
      } else {
        _sync();
      }
    } else if (!widget.active && old.active) {
      _sync();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      // First build: inherited widgets (TickerMode) are available now.
      _started = true;
      if (widget.active) {
        _start();
        return;
      }
    }
    _sync(); // tab switched away / back (TickerMode)
  }

  @override
  void dispose() {
    _clock.dispose();
    _progress.dispose();
    _video?.dispose();
    super.dispose();
  }

  bool get _running =>
      widget.active && !_holding && TickerMode.valuesOf(context).enabled;

  void _sync() {
    if (!mounted) return;
    final run = _running;
    final v = _video;
    if (v != null) {
      if (run && v.value.isInitialized) {
        v.play();
      } else {
        v.pause();
      }
      return;
    }
    if (run) {
      if (!_clock.isAnimating && _clock.value < 1) _clock.forward();
    } else {
      _clock.stop();
    }
  }

  void _onClock(AnimationStatus s) {
    if (s == AnimationStatus.completed && _video == null) _next();
  }

  void _start() {
    final cur = _cur;
    _clock.stop();
    _clock.value = 0;
    _progress.value = 0;
    final old = _video;
    _video = null;
    old?.dispose();
    if (cur == null) return;
    _precacheNext();
    if (cur.isVideo && cur.mediaUrl != null) {
      final raw = cur.mediaUrl!;
      final url = raw.startsWith('http') ? raw : '${widget.baseUrl}$raw';
      final token = ++_videoToken;
      final v = VideoPlayerController.networkUrl(Uri.parse(url));
      _video = v;
      v.addListener(() {
        if (token != _videoToken) return;
        final d = v.value.duration.inMilliseconds;
        if (d <= 0) return;
        final pos = v.value.position.inMilliseconds;
        _progress.value = (pos / d).clamp(0, 1).toDouble();
        if (v.value.isInitialized && !v.value.isPlaying && pos >= d - 120) {
          _next();
        }
      });
      v
          .initialize()
          .then((_) {
            if (!mounted || token != _videoToken) return;
            setState(() {});
            _sync();
          })
          .catchError((Object _) {
            // Can't play: treat it like a photo so the story keeps moving.
            if (!mounted || token != _videoToken) return;
            setState(() => _video = null);
            v.dispose();
            _sync();
          });
      if (mounted) setState(() {});
      return;
    }
    if (mounted) setState(() {});
    _sync();
  }

  void _precacheNext() {
    final list = _list;
    Moment? next;
    if (_i + 1 < list.length) {
      next = list[_i + 1];
    } else if (_phase == 0 && _second.isNotEmpty) {
      next = _second.first;
    }
    final raw = next?.mediaUrl;
    if (next == null ||
        next.isVideo ||
        raw == null ||
        next.mediaType == 'text') {
      return;
    }
    // Same key as the UploadImage that will show it (1080px server copy).
    final url = uploadUrl(raw, widget.baseUrl, width: 1080)!;
    precacheImage(
      ResizeImage(NetworkImage(url), width: 1080),
      context,
      onError: (_, _) {},
    );
  }

  void _next() {
    if (_i + 1 < _list.length) {
      _i++;
    } else if (_phase == 0 && _second.isNotEmpty) {
      _phase = 1;
      _i = 0;
    } else {
      _clock.stop();
      _video?.pause();
      widget.onDone();
      return;
    }
    _start();
  }

  void _prev() {
    if (_i > 0) {
      _i--;
    } else if (_phase == 1) {
      _phase = 0;
      _i = _first.length - 1;
    } else {
      widget.onBack();
      return;
    }
    _start();
  }

  void _switchPerson() {
    if (_otherList.isEmpty) return;
    _phase = _phase == 0 ? 1 : 0;
    _i = 0;
    _start();
  }

  void _setHold(bool v) {
    if (_holding == v) return;
    setState(() => _holding = v);
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final cur = _cur;
    if (cur == null) return const SizedBox.shrink();
    final top = MediaQuery.paddingOf(context).top;
    final other = _otherList.isEmpty ? null : _otherList.first;
    final owner = _curIsMine ? widget.myName : widget.partnerName;
    final group = _list.where((m) => m.sessionKey == cur.sessionKey).toList();
    final mineHeart = cur.reactions.any((r) => r.userId == widget.myUserId);
    final theirHeart = cur.reactions.any(
      (r) => r.userId != null && r.userId != widget.myUserId,
    );
    final likes = mineHeart && theirHeart
        ? '${josa(widget.partnerName, '와', '과')} 내가 좋아해요'
        : theirHeart
        ? '${josa(widget.partnerName, '이', '가')} 좋아해요'
        : mineHeart
        ? '내가 좋아해요'
        : null;
    final caption = cur.caption?.trim();
    final time = _clockText(cur.capturedAt ?? cur.takenAt);
    final v = _video;
    Widget fade(Widget child) => AnimatedOpacity(
      opacity: _holding ? 0 : 1,
      duration: const Duration(milliseconds: 150),
      child: IgnorePointer(ignoring: _holding, child: child),
    );

    return Stack(
      key: Key('moment_day_${dayKey(widget.page.day)}'),
      fit: StackFit.expand,
      children: [
        if (v != null && v.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: v.value.size.width,
              height: v.value.size.height,
              child: VideoPlayer(v),
            ),
          )
        else if (v != null)
          Stack(
            fit: StackFit.expand,
            children: [
              MomentFill(moment: cur, baseUrl: widget.baseUrl, blur: true),
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          )
        else
          MomentFill(
            key: ValueKey('story-item-${cur.id}'),
            moment: cur,
            baseUrl: widget.baseUrl,
            cacheWidth: 1080,
          ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .22, .4, .52, 1],
                colors: [
                  Color(0x8C000000),
                  Color(0x26000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xB8000000),
                ],
              ),
            ),
          ),
        ),
        // Tap left / right, hold to pause, swipe sideways for the other
        // person. Vertical drags still go to the day pager.
        LayoutBuilder(
          builder: (context, box) => GestureDetector(
            key: Key('story_tap_${dayKey(widget.page.day)}'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) =>
                d.localPosition.dx < box.maxWidth * .3 ? _prev() : _next(),
            onLongPressStart: (_) => _setHold(true),
            onLongPressEnd: (_) => _setHold(false),
            onLongPressCancel: () => _setHold(false),
            onHorizontalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0).abs() > 120) _switchPerson();
            },
          ),
        ),
        // Progress bars for the person being shown.
        Positioned(
          left: 12,
          right: 12,
          top: top + 134,
          child: fade(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: _progress,
                  builder: (context, value, _) => Row(
                    children: [
                      for (var k = 0; k < _list.length; k++) ...[
                        if (k > 0) const SizedBox(width: 3),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              minHeight: 2.5,
                              value: k < _i ? 1 : (k == _i ? value : 0),
                              backgroundColor: Colors.white30,
                              valueColor: const AlwaysStoppedAnimation(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ExcludeSemantics(
                      child: V2Avatar(
                        name: owner,
                        color: _curIsMine
                            ? V2Avatar.meColor
                            : V2Avatar.partnerColor,
                        size: V2AvatarSize.sm,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      owner,
                      style: V2Text.bodyStrong.copyWith(color: Colors.white),
                    ),
                    if (time != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        time,
                        style: V2Text.cap.copyWith(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        if (other != null)
          Positioned(
            right: 16,
            top: top + 172,
            child: fade(
              Semantics(
                button: true,
                label: '${_curIsMine ? widget.partnerName : '내'} 순간 보기',
                child: GestureDetector(
                  key: Key('story_switch_${dayKey(widget.page.day)}'),
                  onTap: _switchPerson,
                  child: Container(
                    width: 84,
                    height: 112,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66000000), blurRadius: 20),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MomentFill(
                          moment: other,
                          baseUrl: widget.baseUrl,
                          cacheWidth: 240,
                        ),
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: _Tag(
                            _curIsMine ? widget.partnerName : widget.myName,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 18,
          child: fade(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  momentFeedDayLong(widget.page.day),
                  style: V2Text.cap.copyWith(color: Colors.white70),
                ),
                if (caption != null && caption.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$owner  ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: caption),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: V2Text.body.copyWith(color: Colors.white),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    _ActionIcon(
                      key: Key('moment_heart_${cur.id}'),
                      icon: mineHeart
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: mineHeart ? V2Colors.rose : Colors.white,
                      tooltip: mineHeart ? '하트 취소' : '하트 보내기',
                      onTap: () => widget.onHeart(cur),
                    ),
                    _ActionIcon(
                      key: Key('moment_comments_${cur.id}'),
                      icon: V2Icons.chat,
                      color: Colors.white,
                      tooltip: '댓글',
                      onTap: () => widget.onComments(cur),
                    ),
                    _ActionIcon(
                      icon: Icons.open_in_full_rounded,
                      color: Colors.white,
                      tooltip: '크게 보기',
                      onTap: () => widget.onOpen(group.isEmpty ? [cur] : group),
                    ),
                    const Spacer(),
                    if (likes != null)
                      Text(
                        likes,
                        style: V2Text.cap.copyWith(color: Colors.white),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String? _clockText(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return null;
    final am = d.hour < 12;
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '${am ? '오전' : '오후'} $h:${d.minute.toString().padLeft(2, '0')}';
  }
}
