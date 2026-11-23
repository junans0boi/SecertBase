import 'package:flutter/material.dart';

import '../../../v2/v2.dart';
import '../data/date_plan_repository.dart';
import '../domain/date_plan.dart';
import 'date_plan_editor_screen.dart';
import 'date_plan_format.dart';

/// 데이트 계획 목록: 다가오는 계획 / 지난 계획.
/// 지난(또는 오늘) 계획은 "다녀왔어요"로 닫고, 연결된 장소가 있으면 애프터글로우로 이어진다.
class DatePlansScreen extends StatefulWidget {
  final DatePlanRepository repository;

  /// 완료 후 애프터글로우로 이어 주는 동작(보통 지도 화면을 연다).
  final Future<void> Function(DatePlanAfterglow afterglow) onOpenAfterglow;
  final DateTime Function() now;

  /// 기념일 날짜(YYYY-MM-DD) → 이름. 같은 날 계획에 함께 표시한다.
  final Map<String, String> anniversaries;

  const DatePlansScreen({
    super.key,
    required this.repository,
    required this.onOpenAfterglow,
    this.now = DateTime.now,
    this.anniversaries = const {},
  });

  @override
  State<DatePlansScreen> createState() => _DatePlansScreenState();
}

class _DatePlansScreenState extends State<DatePlansScreen> {
  List<DatePlan> _upcoming = const [];
  List<DatePlan> _past = const [];
  String? _pastCursor;
  bool _loading = true;
  bool _failed = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final up = await widget.repository.list(upcoming: true);
      final past = await widget.repository.list(upcoming: false);
      if (!mounted) return;
      setState(() {
        _upcoming = up.plans;
        _past = past.plans;
        _pastCursor = past.nextCursor;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _morePast() async {
    final cursor = _pastCursor;
    if (cursor == null) return;
    try {
      final page = await widget.repository.list(
        upcoming: false,
        cursor: cursor,
      );
      if (!mounted) return;
      setState(() {
        _past = [..._past, ...page.plans];
        _pastCursor = page.nextCursor;
      });
    } catch (_) {
      if (mounted) setState(() => _notice = '더 불러오지 못했어요');
    }
  }

  Future<void> _edit(DatePlan plan) async {
    if (plan.completed) return;
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) =>
            DatePlanEditorScreen(repository: widget.repository, plan: plan),
      ),
    );
    if (result != null) _load();
  }

  Future<void> _create() async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => DatePlanEditorScreen(repository: widget.repository),
      ),
    );
    if (result != null) _load();
  }

  Future<void> _complete(DatePlan plan) async {
    try {
      final done = await widget.repository.complete(plan.id);
      if (!mounted) return;
      await _load();
      final afterglow = done.afterglow;
      if (afterglow != null && mounted) {
        await widget.onOpenAfterglow(afterglow);
        if (mounted) _load();
      } else if (mounted) {
        setState(() => _notice = '다녀온 계획으로 남겼어요');
      }
    } on DatePlanException catch (e) {
      if (!mounted) return;
      setState(
        () => _notice = e.reason == 'plan_not_yet'
            ? '아직 이 날이 아니에요'
            : '처리하지 못했어요. 다시 시도해 주세요.',
      );
    }
  }

  Widget _tile(DatePlan plan) {
    final p = V2Palette.of(context);
    final today = widget.now();
    final anniversary = widget.anniversaries[plan.planDate];
    final glow = plan.afterglow;
    final action = plan.canComplete(today)
        ? V2Button(
            key: Key('date_plan_complete_${plan.id}'),
            label: '다녀왔어요',
            size: V2ButtonSize.sm,
            fullWidth: false,
            onPressed: () => _complete(plan),
          )
        : (plan.completed && glow != null)
        ? V2Button(
            key: Key('date_plan_afterglow_${plan.id}'),
            label: glow.needsVisit ? '여운 남기기' : '우리의 여운 보기',
            size: V2ButtonSize.sm,
            variant: V2ButtonVariant.soft,
            fullWidth: false,
            onPressed: () => widget.onOpenAfterglow(glow),
          )
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: V2Space.x2),
      child: V2Card(
        key: Key('date_plan_item_${plan.id}'),
        variant: V2CardVariant.soft,
        onTap: plan.completed ? null : () => _edit(plan),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${datePlanDistance(plan, today)} · ${datePlanWhen(plan)}',
              style: V2Text.cap.copyWith(color: p.primary),
            ),
            const SizedBox(height: 2),
            Text(V2Text.keepAll(plan.title), style: V2Text.bodyStrong),
            if (plan.pinTitle != null)
              Text(plan.pinTitle!, style: V2Text.cap.copyWith(color: p.sub)),
            if (anniversary != null)
              Text(
                '같은 날 · $anniversary',
                key: Key('date_plan_anniversary_${plan.id}'),
                style: V2Text.cap.copyWith(color: p.sub),
              ),
            if (plan.memo != null) ...[
              const SizedBox(height: 2),
              Text(plan.memo!, style: V2Text.cap.copyWith(color: p.sub)),
            ],
            if (action != null) ...[const SizedBox(height: V2Space.x2), action],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      appBar: V2Header(
        title: '데이트 계획',
        actions: [
          V2IconButton(
            key: const Key('date_plan_add'),
            icon: V2Icons.add,
            tooltip: '계획 만들기',
            onPressed: _create,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _failed
            ? Center(
                child: V2Button(
                  label: '다시 불러오기',
                  variant: V2ButtonVariant.soft,
                  fullWidth: false,
                  onPressed: _load,
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(V2Space.page),
                children: [
                  if (_notice != null) ...[
                    Text(
                      _notice!,
                      key: const Key('date_plan_notice'),
                      style: V2Text.cap.copyWith(color: p.sub),
                    ),
                    const SizedBox(height: V2Space.x2),
                  ],
                  Text('다가오는 계획', style: V2Text.head),
                  const SizedBox(height: V2Space.x2),
                  if (_upcoming.isEmpty)
                    Text(
                      '함께 갈 날을 정해 볼까요? 위시 장소에서도 만들 수 있어요',
                      style: V2Text.cap.copyWith(color: p.sub),
                    ),
                  for (final plan in _upcoming) _tile(plan),
                  const SizedBox(height: V2Space.x4),
                  Text('지난 계획', style: V2Text.head),
                  const SizedBox(height: V2Space.x2),
                  if (_past.isEmpty)
                    Text(
                      '다녀온 계획이 여기에 쌓여요',
                      style: V2Text.cap.copyWith(color: p.sub),
                    ),
                  for (final plan in _past) _tile(plan),
                  if (_pastCursor != null)
                    V2Button(
                      label: '더 보기',
                      variant: V2ButtonVariant.text,
                      onPressed: _morePast,
                    ),
                ],
              ),
      ),
    );
  }
}
