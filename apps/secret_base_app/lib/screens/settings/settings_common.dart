import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../v2/v2.dart';

/// Shared helpers for the 더보기 (settings) screens.
///
/// Every page under 더보기 is pushed on the root navigator so the bottom tab
/// bar hides while the user is focused on one task (mockup: "하위 화면에는
/// 하단 탭을 숨겨").
Future<T?> pushMorePage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

/// The user's display name (닉네임 우선).
String myDisplayName(Map<String, dynamic>? user) {
  for (final key in ['Nickname', 'nickname', 'UserName', 'userName']) {
    final v = '${user?[key] ?? ''}'.trim();
    if (v.isNotEmpty && v != 'null') return v;
  }
  return '나';
}

/// The partner's name, or null when not paired / unknown.
String? partnerDisplayName(Map<String, dynamic>? user) {
  final v = '${user?['PartnerName'] ?? ''}'.trim();
  return v.isEmpty || v == 'null' ? null : v;
}

bool isPaired(Map<String, dynamic>? user) {
  final code = user?['PartnerCode'];
  return code != null && '$code'.trim().isNotEmpty && '$code' != 'null';
}

/// Google 로그인 계정인지(비밀번호가 없는 계정).
bool isGoogleAccount(Map<String, dynamic>? user) {
  final provider = '${user?['AuthProvider'] ?? user?['authProvider'] ?? ''}';
  return provider == 'google';
}

/// 탈퇴할 때 비밀번호가 필요한 계정인지(서버 `password_required`와 같은 기준).
bool needsPasswordToDelete(Map<String, dynamic>? user) {
  final provider =
      '${user?['AuthProvider'] ?? user?['authProvider'] ?? 'password'}';
  return provider == 'password' || provider == 'null' || provider.isEmpty;
}

/// `2025년 9월 21일`.
String koreanDate(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';

/// `9월 21일`.
String koreanMonthDay(DateTime d) => '${d.month}월 ${d.day}일';

/// `2025-09-21` → DateTime (local date only), or null.
DateTime? parseDateOnly(Object? raw) {
  final text = '${raw ?? ''}'.trim();
  if (text.isEmpty || text == 'null') return null;
  return DateTime.tryParse(text.split('T').first);
}

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// `23:00` → `밤 11:00`, `07:30` → `아침 7:30`.
String koreanClock(String hhmm) {
  final parts = hhmm.split(':');
  final h = int.tryParse(parts.first) ?? 0;
  final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  final period = switch (h) {
    < 5 => '새벽',
    < 11 => '아침',
    < 13 => '낮',
    < 18 => '오후',
    < 21 => '저녁',
    _ => '밤',
  };
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$period $h12:${m.toString().padLeft(2, '0')}';
}

/// `52300` → `52,300`.
String groupedNumber(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// Logs out and drops every pushed 더보기 page so the login screen shows.
Future<void> logoutToStart(BuildContext context, {VoidCallback? before}) async {
  final nav = Navigator.of(context);
  before?.call();
  nav.popUntil((r) => r.isFirst);
  await AuthService().logout();
}

/// A labelled key/value row inside a [V2Card] (앱 정보, 동의 내역).
class MoreInfoRow extends StatelessWidget {
  const MoreInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Semantics(
      container: true,
      label: '$label: $value',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(label, style: V2Text.body.copyWith(color: p.sub)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: V2Text.bodyStrong.copyWith(color: p.ink),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grouped container for [MoreInfoRow]s (same chrome as [V2List]).
class MoreInfoGroup extends StatelessWidget {
  const MoreInfoGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => V2List(children: children);
}

/// Red-tinted "위험 구역" box for logout/탈퇴/연결 해제.
class MoreDangerZone extends StatelessWidget {
  const MoreDangerZone({
    super.key,
    required this.title,
    required this.message,
    required this.child,
  });

  final String title;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final t = V2ToneColors.of(V2Tone.err);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.dark ? p.errSoft : t.soft,
        borderRadius: V2Radius.cardAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(V2Icons.warn, size: 20, color: t.text),
              const SizedBox(width: 8),
              Text(title, style: V2Text.bodyStrong.copyWith(color: t.text)),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: V2Text.cap.copyWith(color: t.text)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Step indicator chip for multi-step flows ("1/2").
class MoreStepChip extends StatelessWidget {
  const MoreStepChip({super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$total단계 중 $step단계',
    excludeSemantics: true,
    child: V2Chip(label: '$step/$total'),
  );
}
