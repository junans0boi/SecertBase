import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../v2/v2.dart';
import 'home_format.dart';

/// Opens the "우리의 첫날" sheet (home 시작일 시트 / 기념일 시작일 편집).
/// Returns the picked day, or null when dismissed. The caller saves it.
Future<DateTime?> showStartDateSheet(
  BuildContext context, {
  DateTime? initial,
  String title = '우리의 첫날은 언제인가요?',
  String subtitle = 'D-day와 100일·1주년 기념일이 이 날을 기준으로 계산돼요',
  String footnote = '기념일에서 언제든 바꿀 수 있어요',
}) {
  final now = today();
  final picked = ValueNotifier<DateTime>(
    initial == null || initial.isAfter(now) ? now : dayOf(initial),
  );
  return showV2Sheet<DateTime>(
    context,
    title: title,
    subtitle: subtitle,
    builder: (_) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KoreanDateWheel(
          initial: picked.value,
          first: DateTime(1970),
          last: now,
          onChanged: (d) => picked.value = d,
        ),
        const SizedBox(height: V2Space.x3),
        ValueListenableBuilder<DateTime>(
          valueListenable: picked,
          builder: (context, day, _) => _StartPreview(start: day),
        ),
      ],
    ),
    actions: [
      Builder(
        builder: (sheetContext) => V2Button(
          label: '저장하기',
          onPressed: () => Navigator.pop(sheetContext, picked.value),
        ),
      ),
      Text(
        V2Text.keepAll(footnote),
        textAlign: TextAlign.center,
        style: V2Text.cap,
      ),
    ],
  ).whenComplete(picked.dispose);
}

class _StartPreview extends StatelessWidget {
  const _StartPreview({required this.start});
  final DateTime start;

  @override
  Widget build(BuildContext context) {
    final next = nextAutoMilestone(start);
    final text = StringBuffer('오늘 기준 D+${dPlus(start)}');
    if (next != null) {
      text.write(' · ${next.label}은 ${dotDate(next.date)}예요');
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Space.x4,
        vertical: V2Space.x3,
      ),
      decoration: BoxDecoration(
        color: V2Colors.roseSoft,
        borderRadius: V2Radius.ctlAll,
      ),
      child: Text(
        text.toString(),
        textAlign: TextAlign.center,
        style: V2Text.cap.copyWith(
          color: V2Colors.rose700,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Year / month / day wheels with Korean labels (2025년 · 9월 · 21일).
/// The app has no Material localizations, so the stock date pickers would
/// show English; this keeps the picker Korean and accessible (each wheel is
/// an adjustable semantics node).
class KoreanDateWheel extends StatefulWidget {
  const KoreanDateWheel({
    super.key,
    required this.initial,
    required this.first,
    required this.last,
    required this.onChanged,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final ValueChanged<DateTime> onChanged;

  @override
  State<KoreanDateWheel> createState() => _KoreanDateWheelState();
}

class _KoreanDateWheelState extends State<KoreanDateWheel> {
  static const _itemExtent = 44.0;
  late int _year;
  late int _month;
  late int _day;
  late final FixedExtentScrollController _yearCtl;
  late final FixedExtentScrollController _monthCtl;
  late final FixedExtentScrollController _dayCtl;

  @override
  void initState() {
    super.initState();
    final d = _clamp(widget.initial);
    _year = d.year;
    _month = d.month;
    _day = d.day;
    _yearCtl = FixedExtentScrollController(
      initialItem: _year - widget.first.year,
    );
    _monthCtl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtl = FixedExtentScrollController(initialItem: _day - 1);
  }

  @override
  void dispose() {
    _yearCtl.dispose();
    _monthCtl.dispose();
    _dayCtl.dispose();
    super.dispose();
  }

  DateTime _clamp(DateTime d) {
    if (d.isBefore(widget.first)) return dayOf(widget.first);
    if (d.isAfter(widget.last)) return dayOf(widget.last);
    return dayOf(d);
  }

  int _daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

  void _emit() {
    final maxDay = _daysIn(_year, _month);
    if (_day > maxDay) {
      _day = maxDay;
      if (_dayCtl.hasClients) _dayCtl.jumpToItem(_day - 1);
    }
    final clamped = _clamp(DateTime(_year, _month, _day));
    if (clamped != DateTime(_year, _month, _day)) {
      _year = clamped.year;
      _month = clamped.month;
      _day = clamped.day;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_yearCtl.hasClients) _yearCtl.jumpToItem(_year - widget.first.year);
        if (_monthCtl.hasClients) _monthCtl.jumpToItem(_month - 1);
        if (_dayCtl.hasClients) _dayCtl.jumpToItem(_day - 1);
      });
    }
    setState(() {});
    widget.onChanged(DateTime(_year, _month, _day));
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final years = widget.last.year - widget.first.year + 1;
    return SizedBox(
      height: _itemExtent * 5,
      child: Stack(
        children: [
          Center(
            child: Container(
              height: _itemExtent,
              decoration: BoxDecoration(
                color: p.soft,
                borderRadius: V2Radius.ctlAll,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: _wheel(
                  label: '연도',
                  controller: _yearCtl,
                  count: years,
                  text: (i) => '${widget.first.year + i}년',
                  selected: _year - widget.first.year,
                  onSelected: (i) {
                    _year = widget.first.year + i;
                    _emit();
                  },
                ),
              ),
              Expanded(
                flex: 3,
                child: _wheel(
                  label: '월',
                  controller: _monthCtl,
                  count: 12,
                  text: (i) => '${i + 1}월',
                  selected: _month - 1,
                  onSelected: (i) {
                    _month = i + 1;
                    _emit();
                  },
                ),
              ),
              Expanded(
                flex: 3,
                child: _wheel(
                  label: '일',
                  controller: _dayCtl,
                  count: _daysIn(_year, _month),
                  text: (i) => '${i + 1}일',
                  selected: _day - 1,
                  onSelected: (i) {
                    _day = i + 1;
                    _emit();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wheel({
    required String label,
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int) text,
    required int selected,
    required ValueChanged<int> onSelected,
  }) {
    final p = V2Palette.of(context);
    void step(int delta) {
      final next = math.max(0, math.min(count - 1, selected + delta));
      if (next == selected) return;
      controller.jumpToItem(next);
      onSelected(next);
    }

    return Semantics(
      label: label,
      value: text(selected),
      increasedValue: text(math.min(count - 1, selected + 1)),
      decreasedValue: text(math.max(0, selected - 1)),
      onIncrease: () => step(1),
      onDecrease: () => step(-1),
      child: ExcludeSemantics(
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: _itemExtent,
          physics: const FixedExtentScrollPhysics(),
          diameterRatio: 1.6,
          perspective: 0.003,
          onSelectedItemChanged: onSelected,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: count,
            builder: (context, i) => Center(
              child: Text(
                text(i),
                style: i == selected
                    ? V2Text.bodyStrong.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w700,
                      )
                    : V2Text.body.copyWith(color: p.muted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
