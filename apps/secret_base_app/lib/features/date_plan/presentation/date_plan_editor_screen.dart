import 'package:flutter/material.dart';

import '../../../v2/v2.dart';
import '../data/date_plan_repository.dart';
import '../domain/date_plan.dart';
import 'date_plan_format.dart';

const datePlanTitleMax = 80;
const datePlanMemoMax = 500;

/// 데이트 계획 만들기·고치기. 결과로 저장된 [DatePlan](삭제하면 null이 아닌 [deleted])을 돌려준다.
class DatePlanEditorScreen extends StatefulWidget {
  final DatePlanRepository repository;

  /// 있으면 고치기 모드.
  final DatePlan? plan;

  /// 위시 지도 핀에서 시작할 때의 연결 정보.
  final int? pinId;
  final String? pinTitle;
  final DateTime? initialDate;

  const DatePlanEditorScreen({
    super.key,
    required this.repository,
    this.plan,
    this.pinId,
    this.pinTitle,
    this.initialDate,
  });

  @override
  State<DatePlanEditorScreen> createState() => _DatePlanEditorScreenState();
}

class _DatePlanEditorScreenState extends State<DatePlanEditorScreen> {
  late final _title = TextEditingController(
    text: widget.plan?.title ?? (widget.pinTitle ?? ''),
  );
  late final _memo = TextEditingController(text: widget.plan?.memo ?? '');
  late DateTime _date =
      widget.plan?.date ??
      widget.initialDate ??
      DateTime.now().add(const Duration(days: 1));
  late String? _time = widget.plan?.planTime;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.plan != null;
  String? get _pinTitle => widget.plan?.pinTitle ?? widget.pinTitle;

  @override
  void dispose() {
    _title.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked == null) return;
    setState(
      () => _time =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
    );
  }

  String _message(DatePlanException e) => switch (e.reason) {
    'plan_completed' => '다녀온 계획은 고칠 수 없어요',
    'plan_date_in_past' => '지난 날짜로는 만들 수 없어요',
    'map_pin_not_found' => '연결한 장소를 찾지 못했어요',
    _ => '저장하지 못했어요. 다시 시도해 주세요.',
  };

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '제목을 적어 주세요');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final memo = _memo.text.trim();
      final plan = _editing
          ? await widget.repository.update(
              widget.plan!.id,
              planDate: ymd(_date),
              planTime: _time,
              clearTime: _time == null,
              title: title,
              memo: memo,
            )
          : await widget.repository.create(
              planDate: ymd(_date),
              planTime: _time,
              title: title,
              memo: memo.isEmpty ? null : memo,
              pinId: widget.pinId,
            );
      if (mounted) Navigator.of(context).pop(plan);
    } on DatePlanException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _message(e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '저장하지 못했어요. 다시 시도해 주세요.';
        });
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 계획을 지울까요?'),
        content: const Text('두 사람 모두에게서 사라져요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            key: const Key('date_plan_delete_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.repository.remove(widget.plan!.id);
      if (mounted) Navigator.of(context).pop(datePlanDeleted);
    } on DatePlanException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.reason == 'plan_author_required'
              ? '계획을 만든 사람만 지울 수 있어요'
              : '지우지 못했어요. 다시 시도해 주세요.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      appBar: V2Header(title: _editing ? '계획 고치기' : '이 날 가요'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(V2Space.page),
          children: [
            if (_pinTitle != null) ...[
              Row(
                children: [
                  Icon(V2Icons.location, size: 18, color: p.primary),
                  const SizedBox(width: V2Space.x1),
                  Expanded(
                    child: Text(
                      _pinTitle!,
                      key: const Key('date_plan_pin'),
                      style: V2Text.bodyStrong.copyWith(color: p.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: V2Space.x3),
            ],
            V2TextField(
              key: const Key('date_plan_title'),
              label: '제목',
              controller: _title,
              maxLength: datePlanTitleMax,
            ),
            const SizedBox(height: V2Space.x3),
            Row(
              children: [
                Expanded(
                  child: V2Button(
                    key: const Key('date_plan_pick_date'),
                    label: datePlanWhen(
                      DatePlan(id: 0, planDate: ymd(_date), title: ''),
                    ),
                    icon: V2Icons.calendar,
                    variant: V2ButtonVariant.soft,
                    onPressed: _pickDate,
                  ),
                ),
                const SizedBox(width: V2Space.x2),
                Expanded(
                  child: V2Button(
                    key: const Key('date_plan_pick_time'),
                    label: _time ?? '시각 정하기',
                    variant: V2ButtonVariant.soft,
                    onPressed: _pickTime,
                  ),
                ),
              ],
            ),
            if (_time != null)
              V2Button(
                key: const Key('date_plan_clear_time'),
                label: '시각 빼기',
                variant: V2ButtonVariant.text,
                fullWidth: false,
                onPressed: () => setState(() => _time = null),
              ),
            const SizedBox(height: V2Space.x3),
            V2TextField(
              key: const Key('date_plan_memo'),
              label: '메모',
              controller: _memo,
              maxLines: 3,
              maxLength: datePlanMemoMax,
            ),
            if (_error != null) ...[
              const SizedBox(height: V2Space.x2),
              Text(
                _error!,
                key: const Key('date_plan_error'),
                style: V2Text.cap.copyWith(color: p.sub),
              ),
            ],
            const SizedBox(height: V2Space.x4),
            V2Button(
              key: const Key('date_plan_save'),
              label: '저장',
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
            if (_editing && widget.plan!.mine) ...[
              const SizedBox(height: V2Space.x2),
              V2Button(
                key: const Key('date_plan_delete'),
                label: '계획 지우기',
                variant: V2ButtonVariant.danger,
                onPressed: _delete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 삭제했다는 신호(편집 화면이 pop 할 때 돌려준다).
const Object datePlanDeleted = _Deleted();

class _Deleted {
  const _Deleted();
}
