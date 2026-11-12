import 'package:flutter/material.dart';

import '../../../v2/v2.dart';
import 'moment_format.dart';

/// Short reason shown next to a record's date ("사진 찍은 날", "오늘", …).
String momentDateReason(DateTime date, {DateTime? photoDate, DateTime? now}) {
  final d = dateOnly(date);
  final today = dateOnly(now ?? DateTime.now());
  if (photoDate != null && dateOnly(photoDate) == d && d != today) {
    return '사진 찍은 날';
  }
  final diff = today.difference(d).inDays;
  return switch (diff) {
    0 => '오늘',
    1 => '어제',
    2 => '그저께',
    _ => '${d.month}월 ${d.day}일',
  };
}

/// "11월 9일 · 사진 찍은 날"
String momentDateChipLabel(
  DateTime date, {
  DateTime? photoDate,
  DateTime? now,
}) {
  final reason = momentDateReason(date, photoDate: photoDate, now: now);
  final md = '${date.month}월 ${date.day}일';
  return reason == md ? md : '$md · $reason';
}

/// Which day a record belongs to: quick picks plus a calendar. Never a
/// future day.
Future<DateTime?> showMomentDateSheet(
  BuildContext context, {
  required DateTime current,
  DateTime? photoDate,
}) {
  final today = dateOnly(DateTime.now());
  final options = <({String label, DateTime date})>[
    (label: '오늘', date: today),
    (label: '어제', date: today.subtract(const Duration(days: 1))),
    (label: '그저께', date: today.subtract(const Duration(days: 2))),
  ];
  final photo = photoDate == null ? null : dateOnly(photoDate);
  if (photo != null &&
      !photo.isAfter(today) &&
      options.every((o) => o.date != photo)) {
    options.add((label: '사진 찍은 날', date: photo));
  }
  return showV2Sheet<DateTime>(
    context,
    title: '어느 날의 기록인가요?',
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        V2List(
          children: [
            for (final o in options)
              V2ListTile(
                key: Key('moment_date_${dayKey(o.date)}'),
                icon: V2Icons.calendar,
                title: o.label,
                subtitle: '${o.date.month}월 ${o.date.day}일',
                showChevron: false,
                trailing: o.date == dateOnly(current)
                    ? Icon(V2Icons.ok, color: V2Colors.rose600)
                    : null,
                onTap: () => Navigator.pop(ctx, o.date),
              ),
          ],
        ),
        const SizedBox(height: V2Space.x3),
        V2Button(
          key: const Key('moment_date_other'),
          label: '다른 날 고르기',
          icon: V2Icons.calendar,
          variant: V2ButtonVariant.soft,
          onPressed: () async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: dateOnly(current).isAfter(today)
                  ? today
                  : dateOnly(current),
              firstDate: DateTime(2020),
              lastDate: today,
              helpText: '기록 날짜',
              cancelText: '취소',
              confirmText: '확인',
            );
            if (picked != null && ctx.mounted) {
              Navigator.pop(ctx, dateOnly(picked));
            }
          },
        ),
      ],
    ),
  );
}
