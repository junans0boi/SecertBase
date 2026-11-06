import 'dart:async';

import 'package:flutter/material.dart';

import '../../v2/v2.dart';
import '../home/home_format.dart';
import '../home/start_date_sheet.dart';
import 'base_api.dart';
import 'base_common.dart';

/// One upcoming / past entry of the 기념일 list.
class AnniversaryEntry {
  AnniversaryEntry({
    this.id,
    required this.label,
    required this.date,
    required this.shown,
    required this.yearly,
    required this.auto,
  });

  final int? id;
  final String label;

  /// The stored date (first occurrence for yearly ones).
  final DateTime date;

  /// The day it falls on next (yearly) or the stored day (one-off).
  final DateTime shown;
  final bool yearly;
  final bool auto;

  int get daysUntil => shown.difference(today()).inDays;
  bool get past => daysUntil < 0;

  String get detail {
    final base = auto
        ? '${dotDate(shown)} ${weekdayName(shown)}'
        : yearly
        ? '${weekdayName(shown)} · 매년'
        : '${dotDate(shown)} ${weekdayName(shown)} · 한 번';
    return base;
  }
}

/// Merges server anniversaries with the automatic 100일·1주년 milestones,
/// upcoming first (nearest day first), past ones last.
({List<AnniversaryEntry> upcoming, List<AnniversaryEntry> past}) buildEntries(
  List<Map<String, dynamic>> raw,
  DateTime? start,
) {
  final list = <AnniversaryEntry>[];
  for (final a in raw) {
    final date = parseDay('${a['date']}');
    if (date == null) continue;
    final yearly = a['repeat_yearly'] == true;
    list.add(
      AnniversaryEntry(
        id: a['id'] is int ? a['id'] as int : int.tryParse('${a['id']}'),
        label: '${a['label']}',
        date: date,
        shown: yearly ? nextYearly(date) : date,
        yearly: yearly,
        auto: false,
      ),
    );
  }
  if (start != null) {
    for (final m in autoMilestones(start)) {
      list.add(
        AnniversaryEntry(
          label: m.label,
          date: m.date,
          shown: m.date,
          yearly: false,
          auto: true,
        ),
      );
    }
  }
  final upcoming = list.where((e) => !e.past).toList()
    ..sort((a, b) => a.shown.compareTo(b.shown));
  final past = list.where((e) => e.past).toList()
    ..sort((a, b) => b.shown.compareTo(a.shown));
  return (upcoming: upcoming, past: past);
}

/// 기념일 탭: 우리의 첫날, 다가오는 기념일, 지난 기념일.
class BaseAnniversariesTab extends StatefulWidget {
  const BaseAnniversariesTab({super.key, required this.hub});

  final BaseHub hub;

  @override
  State<BaseAnniversariesTab> createState() => _BaseAnniversariesTabState();
}

class _BaseAnniversariesTabState extends State<BaseAnniversariesTab> {
  BaseLoad _load = BaseLoad.loading;
  List<Map<String, dynamic>> _raw = [];
  bool _showPast = false;
  final Map<int, Timer> _pendingDeletes = {};
  final Map<int, Future<void> Function()> _commits = {};

  @override
  void initState() {
    super.initState();
    widget.hub.couple.addListener(_onCouple);
    _fetch();
  }

  @override
  void dispose() {
    widget.hub.couple.removeListener(_onCouple);
    // Leaving the screen commits deletions that were still waiting for undo.
    for (final timer in _pendingDeletes.values) {
      timer.cancel();
    }
    for (final commit in _commits.values) {
      unawaited(commit());
    }
    super.dispose();
  }

  void _onCouple() {
    if (mounted) setState(() {});
  }

  Future<void> _fetch({bool silent = false}) async {
    if (!silent) setState(() => _load = BaseLoad.loading);
    try {
      final body = await widget.hub.api.get('/anniversaries');
      final list = body['anniversaries'];
      if (!mounted) return;
      setState(() {
        _raw = list is List
            ? [for (final a in list.whereType<Map>()) Map<String, dynamic>.from(a)]
            : [];
        _load = BaseLoad.ready;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent && _load == BaseLoad.ready) return;
      setState(() => _load = loadStateFor(e));
    }
  }

  Future<void> _editStartDate() async {
    final store = widget.hub.couple;
    final picked = await showStartDateSheet(
      context,
      initial: store.couple?.startDate,
      title: '우리의 첫날',
      subtitle: '날짜를 바꾸면 D-day와 100일·1주년이 다시 계산돼요. 이미 받은 보상은 그대로예요.',
      footnote: '언제든 다시 바꿀 수 있어요',
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

  Future<void> _openForm([AnniversaryEntry? existing]) async {
    final result = await showV2Sheet<_FormOutcome>(
      context,
      title: existing == null ? '기념일 추가' : '기념일 수정',
      builder: (_) => _AnniversaryForm(
        existing: existing,
        onSubmit: (label, date, yearly) async {
          try {
            final body = {
              'label': label,
              'date': isoDay(date),
              'repeat_yearly': yearly,
            };
            if (existing == null) {
              await widget.hub.api.post('/anniversaries', body);
            } else {
              await widget.hub.api.patch('/anniversaries/${existing.id}', body);
            }
            return true;
          } on BaseApiException {
            return false;
          }
        },
      ),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case _FormOutcome.saved:
        showV2Snack(context, existing == null ? '기념일을 추가했어요' : '기념일을 고쳤어요');
        _fetch(silent: true);
      case _FormOutcome.delete:
        await _confirmDelete(existing!);
    }
  }

  Future<void> _confirmDelete(AnniversaryEntry entry) async {
    final ok = await showV2Confirm(
      context,
      title: '‘${entry.label}’을 삭제할까요?',
      message: '삭제하면 우리 둘의 기념일 목록에서 사라져요.',
      confirmLabel: '삭제하기',
      destructive: true,
    );
    if (ok && mounted) _deleteWithUndo(entry);
  }

  /// Removes the row now, tells the server after 5 seconds unless undone.
  void _deleteWithUndo(AnniversaryEntry entry) {
    final id = entry.id;
    if (id == null) return;
    final snapshot = Map<String, dynamic>.from(
      _raw.firstWhere((a) => '${a['id']}' == '$id'),
    );
    setState(() => _raw.removeWhere((a) => '${a['id']}' == '$id'));
    Future<void> commit() async {
      _pendingDeletes.remove(id)?.cancel();
      _commits.remove(id);
      try {
        await widget.hub.api.delete('/anniversaries/$id');
      } on BaseApiException {
        if (mounted) {
          setState(() => _raw.add(snapshot));
          showV2Snack(context, '삭제하지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
        }
      }
    }

    _commits[id] = commit;
    _pendingDeletes[id] = Timer(const Duration(seconds: 5), commit);
    showV2Snack(
      context,
      '‘${entry.label}’을 삭제했어요',
      actionLabel: '실행 취소',
      onAction: () {
        _pendingDeletes.remove(id)?.cancel();
        _commits.remove(id);
        if (mounted) setState(() => _raw.add(snapshot));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return baseTabBody(
      context: context,
      load: _load,
      onRetry: _fetch,
      errorTitle: '기념일을 불러오지 못했어요',
      errorBody: '잠시 후 다시 시도해 주세요.',
      ready: _content,
      loading: const Padding(
        padding: EdgeInsets.all(V2Space.page),
        child: V2SkeletonList(count: 4),
      ),
    );
  }

  Widget _content() {
    final start = widget.hub.couple.couple?.startDate;
    final entries = buildEntries(_raw, start);
    final manualCount = _raw.length;
    if (start == null && manualCount == 0) {
      return V2EmptyState(
        illustration: const V2SceneIllustration(V2Scene.calendar),
        title: '아직 등록된 기념일이 없어요',
        body: '첫날을 정하면 100일·1주년이 자동으로 채워져요.\n생일이나 여행 날짜도 직접 추가할 수 있어요.',
        actionLabel: '우리의 첫날 정하기',
        onAction: _editStartDate,
        secondaryLabel: '기념일 직접 추가',
        onSecondary: () => _openForm(),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _fetch(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: baseListPadding,
        children: [
          _StartDateCard(start: start, onEdit: _editStartDate),
          V2Section(
            title: '다가오는 기념일',
            actionLabel: '추가',
            onAction: () => _openForm(),
            padding: EdgeInsets.zero,
            child: entries.upcoming.isEmpty
                ? V2Card(
                    variant: V2CardVariant.soft,
                    child: Text(
                      '다가오는 기념일이 없어요. 새 기념일을 추가해 보세요.',
                      style: V2Text.cap,
                    ),
                  )
                : V2List(
                    children: [
                      for (final e in entries.upcoming)
                        _AnniversaryRow(
                          key: ValueKey('${e.auto}-${e.id}-${e.label}'),
                          entry: e,
                          onTap: e.auto ? null : () => _openForm(e),
                          onDismissed: e.auto ? null : () => _deleteWithUndo(e),
                          onConfirmDismiss: null,
                        ),
                    ],
                  ),
          ),
          if (entries.past.isNotEmpty) ...[
            const SizedBox(height: V2Space.x2),
            V2Button(
              label: _showPast
                  ? '지난 기념일 접기'
                  : '지난 기념일 ${entries.past.length}개',
              variant: V2ButtonVariant.text,
              onPressed: () => setState(() => _showPast = !_showPast),
            ),
            if (_showPast)
              V2List(
                children: [
                  for (final e in entries.past)
                    _AnniversaryRow(
                      key: ValueKey('past-${e.auto}-${e.id}-${e.label}'),
                      entry: e,
                      onTap: e.auto ? null : () => _openForm(e),
                      onDismissed: null,
                      onConfirmDismiss: null,
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _StartDateCard extends StatelessWidget {
  const _StartDateCard({required this.start, required this.onEdit});

  final DateTime? start;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return V2Card(
      variant: V2CardVariant.soft,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('우리의 첫날', style: V2Text.cap),
                const SizedBox(height: V2Space.x1),
                Text(
                  start == null
                      ? '아직 정하지 않았어요'
                      : dotDateWithWeekday(start!),
                  style: V2Text.head,
                ),
              ],
            ),
          ),
          if (start != null)
            Padding(
              padding: const EdgeInsets.only(right: V2Space.x2),
              child: Text(
                'D+${dPlus(start!)}',
                style: V2Text.serif(size: 24, color: p.primary),
              ),
            ),
          V2IconButton(icon: V2Icons.edit, tooltip: '첫날 바꾸기', onPressed: onEdit),
        ],
      ),
    );
  }
}

class _AnniversaryRow extends StatelessWidget {
  const _AnniversaryRow({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDismissed,
    required this.onConfirmDismiss,
  });

  final AnniversaryEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onDismissed;
  final Future<bool> Function()? onConfirmDismiss;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final e = entry;
    final d = e.daysUntil;
    final row = InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: V2Space.x4,
            vertical: V2Space.x3,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Column(
                  children: [
                    Text('${e.shown.month}월', style: V2Text.label.copyWith(color: p.sub)),
                    Text('${e.shown.day}', style: V2Text.serif(size: 22)),
                  ],
                ),
              ),
              const SizedBox(width: V2Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            e.label,
                            style: V2Text.bodyStrong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (e.auto) ...[
                          const SizedBox(width: V2Space.x2),
                          const V2Chip(label: '자동', tone: V2Tone.sky),
                        ],
                      ],
                    ),
                    Text(e.detail, style: V2Text.cap),
                  ],
                ),
              ),
              V2Chip(
                label: dDayLabel(d),
                tone: d == 0 ? V2Tone.rose : V2Tone.neutral,
              ),
            ],
          ),
        ),
      ),
    );
    final label =
        '${e.label}, ${e.detail}, ${d == 0
            ? '오늘'
            : d > 0
            ? '$d일 남음'
            : '${-d}일 지남'}';
    final semantic = Semantics(
      label: label,
      button: onTap != null,
      onTap: onTap,
      child: ExcludeSemantics(child: row),
    );
    if (onDismissed == null) return semantic;
    return Dismissible(
      key: ValueKey('dismiss-${e.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: V2Space.x5),
        color: V2Colors.errSoft,
        child: const Icon(V2Icons.delete, color: V2Colors.errText),
      ),
      confirmDismiss: onConfirmDismiss == null
          ? null
          : (_) => onConfirmDismiss!(),
      onDismissed: (_) => onDismissed!(),
      child: semantic,
    );
  }
}

enum _FormOutcome { saved, delete }

class _AnniversaryForm extends StatefulWidget {
  const _AnniversaryForm({required this.existing, required this.onSubmit});

  final AnniversaryEntry? existing;
  final Future<bool> Function(String label, DateTime date, bool yearly)
  onSubmit;

  @override
  State<_AnniversaryForm> createState() => _AnniversaryFormState();
}

class _AnniversaryFormState extends State<_AnniversaryForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.label ?? '',
  );
  late DateTime _date = widget.existing?.date ?? today();
  late bool _yearly = widget.existing?.yearly ?? true;
  bool _saving = false;
  bool _failed = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    final ok = await widget.onSubmit(_name.text.trim(), _date, _yearly);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, _FormOutcome.saved);
    } else {
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        V2TextField(
          label: '이름',
          hint: '예: 서윤 생일, 첫 여행',
          controller: _name,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: V2Space.x4),
        Text('날짜', style: V2Text.label),
        const SizedBox(height: V2Space.x1),
        Text(longDateWithWeekday(_date), style: V2Text.bodyStrong),
        KoreanDateWheel(
          initial: _date,
          first: DateTime(1970),
          last: DateTime(2100, 12, 31),
          onChanged: (d) => setState(() => _date = d),
        ),
        V2List(
          children: [
            V2ListTile(
              icon: V2Icons.refresh,
              title: '매년 반복',
              subtitle: '생일·기념일처럼 해마다 챙겨요',
              showChevron: false,
              trailing: V2Toggle(
                value: _yearly,
                onChanged: (v) => setState(() => _yearly = v),
                semanticLabel: '매년 반복',
              ),
            ),
          ],
        ),
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(top: V2Space.x3),
            child: Text(
              '저장하지 못했어요. 다시 시도해 주세요.',
              style: V2Text.cap.copyWith(color: V2Colors.errText),
            ),
          ),
        const SizedBox(height: V2Space.x4),
        V2Button(
          label: '저장하기',
          loading: _saving,
          onPressed: _valid && !_saving ? _save : null,
        ),
        if (widget.existing != null)
          V2Button(
            label: '이 기념일 삭제',
            variant: V2ButtonVariant.dangerSoft,
            onPressed: _saving
                ? null
                : () => Navigator.pop(context, _FormOutcome.delete),
          ),
      ],
    );
  }
}
