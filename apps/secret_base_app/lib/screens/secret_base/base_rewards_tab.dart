import 'package:flutter/material.dart';

import '../../v2/v2.dart';
import '../arcade/arcade_screen.dart';
import '../home/home_format.dart';
import '../home/start_date_sheet.dart';
import '../shop/shop_screen.dart';
import 'base_api.dart';
import 'base_common.dart';

enum MilestoneGroup { moments, places, days }

extension on MilestoneGroup {
  String get label => switch (this) {
    MilestoneGroup.moments => '순간',
    MilestoneGroup.places => '장소',
    MilestoneGroup.days => '함께한 날',
  };
}

/// One row of `/retention/secret-base/milestones`.
class Milestone {
  Milestone({
    required this.type,
    required this.label,
    required this.achieved,
    required this.claimed,
    this.achievedAt,
    this.value,
    this.rewardName,
    this.rewardIcon,
    this.rewardGrade,
  });

  final String type;
  final String label;

  /// For day milestones this is recomputed on the device: the server returns
  /// the future date as "achieved", so the date decides.
  final bool achieved;
  final bool claimed;
  final DateTime? achievedAt;
  final int? value;
  final String? rewardName;
  final String? rewardIcon;
  final String? rewardGrade;

  bool get hasReward => rewardName != null;
  bool get claimable => achieved && !claimed && hasReward;

  MilestoneGroup get group {
    if (RegExp(r'^d\d+$').hasMatch(type)) return MilestoneGroup.days;
    if (type.contains('pin') || type.contains('visit')) {
      return MilestoneGroup.places;
    }
    return MilestoneGroup.moments;
  }

  /// 50 for `moments_50`, 365 for `d365`, 1 for `first_*`.
  int? get target {
    final m = RegExp(r'(\d+)$').firstMatch(type);
    if (m != null) return int.parse(m.group(1)!);
    return type.startsWith('first_') ? 1 : null;
  }

  factory Milestone.fromJson(Map<String, dynamic> json) {
    final type = '${json['type']}';
    final isDay = RegExp(r'^d\d+$').hasMatch(type);
    final at = parseDay('${json['achieved_at'] ?? ''}');
    final reward = json['reward'] is Map
        ? Map<String, dynamic>.from(json['reward'] as Map)
        : null;
    var achieved = json['achieved'] == true;
    if (isDay) achieved = at != null && !at.isAfter(today());
    return Milestone(
      type: type,
      label: '${json['label'] ?? ''}',
      achieved: achieved,
      claimed: json['claimed'] == true,
      achievedAt: at,
      value: json['value'] is num ? (json['value'] as num).toInt() : null,
      rewardName: reward?['name'] as String?,
      rewardIcon: reward?['icon'] as String?,
      rewardGrade: reward?['grade'] as String?,
    );
  }

  String get icon => rewardIcon ?? '🎁';

  /// The sentence under the row title.
  String subtitle() {
    final reward = rewardName ?? '';
    if (achieved) {
      final when = achievedAt == null ? '' : '${dotDate(achievedAt!)} 달성';
      final parts = [if (when.isNotEmpty) when, if (reward.isNotEmpty) reward];
      return parts.join(' · ');
    }
    if (group == MilestoneGroup.days) {
      if (achievedAt == null) return '첫날을 정하면 열려요';
      final left = achievedAt!.difference(today()).inDays;
      return '${reward.isEmpty ? '' : '$reward · '}$left일 남았어요';
    }
    final t = target;
    final v = value;
    if (v != null && t != null && t > 1) {
      return '${reward.isEmpty ? '' : '$reward · '}$v/$t번째';
    }
    return reward;
  }
}

const _gradeTone = {
  'B': V2Tone.neutral,
  'A': V2Tone.sage,
  'S': V2Tone.sky,
  'SS': V2Tone.lilac,
  'SSS': V2Tone.peach,
};

/// 보상 탭: progress summary, claimable rewards, and three groups.
class BaseRewardsTab extends StatefulWidget {
  const BaseRewardsTab({
    super.key,
    required this.hub,
    this.onClaimableChanged,
    this.onGoToTab,
  });

  final BaseHub hub;
  final ValueChanged<int>? onClaimableChanged;
  final ValueChanged<int>? onGoToTab;

  @override
  State<BaseRewardsTab> createState() => _BaseRewardsTabState();
}

class _BaseRewardsTabState extends State<BaseRewardsTab> {
  BaseLoad _load = BaseLoad.loading;
  List<Milestone> _items = const [];
  MilestoneGroup _group = MilestoneGroup.moments;
  final Set<String> _claiming = {};
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _revision = widget.hub.couple.revision;
    widget.hub.couple.addListener(_onCouple);
    _fetch();
  }

  @override
  void dispose() {
    widget.hub.couple.removeListener(_onCouple);
    super.dispose();
  }

  void _onCouple() {
    if (!mounted) return;
    if (widget.hub.couple.revision != _revision) {
      // The server derives day rewards from the first day on every request and
      // keeps claimed ones, so reloading is the recalculation.
      _revision = widget.hub.couple.revision;
      _fetch(silent: true);
    } else {
      setState(() {});
    }
  }

  Future<void> _fetch({bool silent = false}) async {
    if (!silent) setState(() => _load = BaseLoad.loading);
    try {
      final body = await widget.hub.api.get(
        '/retention/secret-base/milestones',
      );
      final raw = body['milestones'];
      if (raw is! List) throw const BaseApiException('invalid_response');
      if (!mounted) return;
      final items = [
        for (final m in raw.whereType<Map>())
          Milestone.fromJson(Map<String, dynamic>.from(m)),
      ];
      setState(() {
        _items = items;
        _load = BaseLoad.ready;
      });
      widget.onClaimableChanged?.call(items.where((m) => m.claimable).length);
    } catch (e) {
      if (!mounted) return;
      if (silent && _load == BaseLoad.ready) return;
      setState(() => _load = loadStateFor(e));
    }
  }

  Future<void> _claim(Milestone m) async {
    if (_claiming.contains(m.type)) return;
    setState(() => _claiming.add(m.type));
    try {
      final body = await widget.hub.api.post(
        '/retention/secret-base/milestones/${m.type}/claim',
      );
      if (!mounted) return;
      final name = '${body['item_name'] ?? m.rewardName ?? '보상'}';
      final icon = '${body['item_icon'] ?? m.icon}';
      await _fetch(silent: true);
      if (!mounted) return;
      await _showReward(m, name, icon);
    } on BaseApiException catch (e) {
      if (!mounted) return;
      showV2Snack(context, switch (e.reason) {
        'already_claimed' => '이미 받은 보상이에요.',
        'not_achieved' => '아직 받을 수 없는 보상이에요.',
        _ => '보상을 받지 못했어요. 다시 시도해 주세요.',
      }, tone: V2Tone.err);
      if (e.reason == 'already_claimed') _fetch(silent: true);
    } finally {
      if (mounted) setState(() => _claiming.remove(m.type));
    }
  }

  Future<void> _showReward(Milestone m, String name, String icon) async {
    final partner = widget.hub.couple.partnerName;
    final go = await showV2Sheet<String>(
      context,
      builder: (_) => _RewardReveal(
        icon: icon,
        title: '${m.label} 보상',
        name: name,
        grade: m.rewardGrade,
        footer: '${josa(partner, '와', '과')} 함께 이룬 ${m.label}을 축하해요',
      ),
      actions: [
        Builder(
          builder: (c) => V2Button(
            label: '놀이에서 써 보기',
            onPressed: () => Navigator.pop(c, 'play'),
          ),
        ),
        Builder(
          builder: (c) => V2Button(
            label: '꾸러미에서 보기',
            variant: V2ButtonVariant.soft,
            onPressed: () => Navigator.pop(c, 'shop'),
          ),
        ),
      ],
    );
    if (!mounted) return;
    if (go == 'play') {
      Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => const ArcadeScreen()));
    } else if (go == 'shop') {
      Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => const ShopScreen()));
    }
  }

  Future<void> _pickStartDate() async {
    final store = widget.hub.couple;
    final picked = await showStartDateSheet(
      context,
      initial: store.couple?.startDate,
      footnote: '이미 받은 보상은 그대로예요',
    );
    if (picked == null || !mounted) return;
    try {
      await store.saveStartDate(picked);
      if (mounted) showV2Snack(context, '우리의 첫날을 저장했어요');
    } on BaseApiException {
      if (mounted) {
        showV2Snack(context, '저장하지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
      }
    }
  }

  void _gradeInfo() {
    showV2Sheet<void>(
      context,
      title: '보상 등급이 뭐예요?',
      subtitle: '오래, 꾸준히 함께할수록 더 귀한 보상이 열려요',
      builder: (_) => const _GradeLegend(),
      actions: [
        Builder(
          builder: (c) =>
              V2Button(label: '확인했어요', onPressed: () => Navigator.pop(c)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return baseTabBody(
      context: context,
      load: _load,
      onRetry: _fetch,
      errorTitle: '보상을 불러오지 못했어요',
      ready: _content,
      loading: const Padding(
        padding: EdgeInsets.all(V2Space.page),
        child: V2SkeletonList(count: 4),
      ),
    );
  }

  Widget _content() {
    final p = V2Palette.of(context);
    final total = _items.length;
    final achieved = _items.where((m) => m.achieved).length;
    final claimable = _items.where((m) => m.claimable).toList();
    final partner = widget.hub.couple.partnerName;
    final start = widget.hub.couple.couple?.startDate;
    final inGroup = _items.where((m) => m.group == _group).toList();
    final noProgress = achieved == 0;

    return RefreshIndicator(
      onRefresh: () => _fetch(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: baseListPadding,
        children: [
          _Summary(
            achieved: achieved,
            total: total,
            claimable: claimable.length,
            next: _nextTarget(),
          ),
          if (noProgress) ...[
            const SizedBox(height: V2Space.x4),
            V2Card(
              child: V2EmptyState(
                illustration: const V2SceneIllustration(V2Scene.hearts),
                title: '첫 보상은 동물 말이에요',
                body: '${josa(partner, '와', '과')} 첫 번째 순간을 남기면 바로 받을 수 있어요.',
                actionLabel: '오늘의 순간 남기기',
                onAction: () => openMomentComposer(context),
              ),
            ),
          ],
          if (claimable.isNotEmpty) ...[
            V2Section(
              title: '지금 받을 수 있어요',
              padding: EdgeInsets.zero,
              child: V2List(
                children: [
                  for (final m in claimable)
                    _RewardRow(
                      milestone: m,
                      claiming: _claiming.contains(m.type),
                      onClaim: () => _claim(m),
                      subtitleOverride: '${m.label} · ${m.group.label} 보상',
                    ),
                ],
              ),
            ),
          ],
          V2Section(
            title: '모든 보상',
            actionLabel: '등급이 뭐예요?',
            onAction: _gradeInfo,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: V2Space.x2,
                  runSpacing: V2Space.x2,
                  children: [
                    for (final g in MilestoneGroup.values)
                      V2Chip(
                        label:
                            '${g.label} ${_items.where((m) => m.group == g && m.achieved).length}/${_items.where((m) => m.group == g).length}',
                        selected: _group == g,
                        onTap: () => setState(() => _group = g),
                      ),
                  ],
                ),
                const SizedBox(height: V2Space.x3),
                if (_group == MilestoneGroup.days && start == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: V2Space.x3),
                    child: V2Card(
                      variant: V2CardVariant.soft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '우리의 첫날을 정하면 100일·1주년 보상이 열려요',
                            style: V2Text.bodyStrong,
                          ),
                          const SizedBox(height: V2Space.x3),
                          V2Button(
                            label: '첫날 정하기',
                            size: V2ButtonSize.sm,
                            variant: V2ButtonVariant.soft,
                            onPressed: _pickStartDate,
                          ),
                        ],
                      ),
                    ),
                  ),
                V2List(
                  children: [
                    for (final m in inGroup)
                      _RewardRow(
                        milestone: m,
                        claiming: _claiming.contains(m.type),
                        onClaim: () => _claim(m),
                      ),
                  ],
                ),
                if (_group == MilestoneGroup.days && start != null)
                  Padding(
                    padding: const EdgeInsets.only(top: V2Space.x3),
                    child: Text(
                      '날짜는 기념일 탭의 시작일(${dotDate(start)}) 기준이에요. 시작일을 바꾸면 아직 받지 않은 보상의 날짜만 다시 계산돼요.',
                      style: V2Text.cap.copyWith(color: p.sub),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "50번째 순간 (41/50)" for the closest unfinished count milestone.
  String? _nextTarget() {
    for (final m in _items.where(
      (m) => !m.achieved && m.group != MilestoneGroup.days,
    )) {
      final v = m.value;
      final t = m.target;
      if (v != null && t != null) return '${m.label} ($v/$t)';
    }
    final upcoming =
        _items
            .where((m) => !m.achieved && m.group == MilestoneGroup.days)
            .where((m) => m.achievedAt != null)
            .toList()
          ..sort((a, b) => a.achievedAt!.compareTo(b.achievedAt!));
    if (upcoming.isNotEmpty) {
      final m = upcoming.first;
      return '${m.label} · ${m.achievedAt!.difference(today()).inDays}일 남았어요';
    }
    return null;
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.achieved,
    required this.total,
    required this.claimable,
    required this.next,
  });

  final int achieved;
  final int total;
  final int claimable;
  final String? next;

  @override
  Widget build(BuildContext context) {
    return V2Card(
      gradient: V2Gradients.heroSoft,
      padding: const EdgeInsets.all(V2Space.x5),
      semanticLabel: '받은 보상 $achieved개, 전체 $total개',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$achieved',
                style: V2Text.serif(size: 44, color: V2Colors.rose700),
              ),
              Text(
                ' /$total',
                style: V2Text.head.copyWith(color: V2Colors.sub),
              ),
              const Spacer(),
              if (claimable > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: V2Space.x3,
                    vertical: V2Space.x1,
                  ),
                  decoration: BoxDecoration(
                    color: V2Colors.roseSoft,
                    borderRadius: V2Radius.pillAll,
                  ),
                  child: Text(
                    '받을 보상 $claimable개',
                    style: V2Text.label.copyWith(color: V2Colors.rose700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: V2Space.x3),
          V2ProgressBar(
            value: total == 0 ? 0 : achieved / total,
            semanticLabel: '$total개 중 $achieved개',
            color: V2Colors.rose600,
          ),
          if (next != null) ...[
            const SizedBox(height: V2Space.x3),
            Text(
              '다음 보상까지 · $next',
              style: V2Text.cap.copyWith(color: V2Colors.sub),
            ),
          ],
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.milestone,
    required this.claiming,
    required this.onClaim,
    this.subtitleOverride,
  });

  final Milestone milestone;
  final bool claiming;
  final VoidCallback onClaim;
  final String? subtitleOverride;

  @override
  Widget build(BuildContext context) {
    final m = milestone;
    final Widget trailing;
    if (m.claimable) {
      trailing = V2Button(
        label: '받기',
        size: V2ButtonSize.sm,
        fullWidth: false,
        loading: claiming,
        onPressed: onClaim,
      );
    } else if (m.claimed) {
      trailing = const V2Chip(label: '받았어요', tone: V2Tone.ok);
    } else if (m.rewardGrade != null) {
      trailing = V2Chip(
        label: m.rewardGrade!,
        tone: _gradeTone[m.rewardGrade] ?? V2Tone.neutral,
      );
    } else {
      trailing = const SizedBox.shrink();
    }
    return V2ListTile(
      leading: Text(
        m.icon,
        style: const TextStyle(fontSize: 26),
        semanticsLabel: '',
      ),
      title: m.hasReward && m.claimable ? (m.rewardName ?? m.label) : m.label,
      subtitle: subtitleOverride ?? m.subtitle(),
      trailing: trailing,
      showChevron: false,
    );
  }
}

class _GradeLegend extends StatelessWidget {
  const _GradeLegend();

  static const _rows = [
    ('B', '기본', '시작할 때 받는 가벼운 선물이에요'),
    ('A', '특별', '장소를 쌓거나 기록이 100개에 닿을 때 받아요'),
    ('S', '희귀', '같은 날짜의 추억을 만나거나 기록 200개를 채울 때 받아요'),
    ('SS', '아주 귀함', '100일·200일 같은 큰 기념일에 받아요'),
    ('SSS', '전설', '1주년부터 이어지는 가장 귀한 보상이에요'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: V2Space.x3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  child: V2Chip(label: r.$1, tone: _gradeTone[r.$1]!),
                ),
                const SizedBox(width: V2Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.$2, style: V2Text.bodyStrong),
                      Text(r.$3, style: V2Text.cap),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Text('받은 보상은 놀이의 윷·말·카드에서 쓰고, 상점 꾸러미에서 모아 볼 수 있어요.', style: V2Text.cap),
      ],
    );
  }
}

/// The once-only pop-in shown right after a reward is claimed.
class _RewardReveal extends StatelessWidget {
  const _RewardReveal({
    required this.icon,
    required this.title,
    required this.name,
    required this.grade,
    required this.footer,
  });

  final String icon;
  final String title;
  final String name;
  final String? grade;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final duration = V2Motion.of(context, V2Motion.slow);
    return Semantics(
      liveRegion: true,
      label: '$title, $name을 받았어요',
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: .6, end: 1),
            duration: duration,
            curve: Curves.elasticOut,
            builder: (_, v, child) => Opacity(
              opacity: v.clamp(0, 1),
              child: Transform.scale(scale: v, child: child),
            ),
            child: Container(
              width: 112,
              height: 112,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: V2Gradients.heroSoft,
                shape: BoxShape.circle,
              ),
              child: Text(
                icon,
                style: const TextStyle(fontSize: 56),
                semanticsLabel: '',
              ),
            ),
          ),
          const SizedBox(height: V2Space.x4),
          Text(title, style: V2Text.cap),
          const SizedBox(height: V2Space.x1),
          Text(
            '$name을 받았어요',
            style: V2Text.serif(size: 24),
            textAlign: TextAlign.center,
          ),
          if (grade != null) ...[
            const SizedBox(height: V2Space.x2),
            V2Chip(label: grade!, tone: _gradeTone[grade] ?? V2Tone.neutral),
          ],
          const SizedBox(height: V2Space.x3),
          Text(
            V2Text.keepAll(footer),
            style: V2Text.cap,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: V2Space.x4),
        ],
      ),
    );
  }
}
