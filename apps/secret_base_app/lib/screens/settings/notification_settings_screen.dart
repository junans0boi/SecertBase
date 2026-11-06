import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/http/api_client.dart';
import '../../v2/v2.dart';
import 'permission_probe.dart';
import 'settings_common.dart';

/// Server defaults (services/realtime-server notifications/preferences.js).
const kNotificationPrefDefaults = <String, Object>{
  'partner_moment': true,
  'today_loop': true,
  'game_invite': true,
  'quiet_hours_enabled': true,
  'quiet_start': '22:00',
  'quiet_end': '08:00',
  'reveal_hour': 21,
};

/// `서윤` → `서윤이`, `민지` → `민지가` (subject particle).
String withSubjectParticle(String name) {
  if (name.isEmpty) return name;
  final code = name.runes.last;
  if (code < 0xAC00 || code > 0xD7A3) return '$name이';
  return (code - 0xAC00) % 28 == 0 ? '$name가' : '$name이';
}

/// One-line summary for the 더보기 row ("켜짐 · 방해금지 밤 10:00 – 아침 8:00").
String notificationSummary(Map<String, dynamic> prefs) {
  final anyOn = ['partner_moment', 'today_loop', 'game_invite']
      .any((k) => prefs[k] == true);
  if (!anyOn) return '모든 알림을 껐어요';
  if (prefs['quiet_hours_enabled'] == true) {
    return '켜짐 · 방해금지 ${koreanClock('${prefs['quiet_start']}')} – '
        '${koreanClock('${prefs['quiet_end']}')}';
  }
  return '켜짐';
}

class NotificationSettingsScreen extends StatefulWidget {
  final ApiClient? apiClient;
  final PermissionProbe permissionProbe;

  const NotificationSettingsScreen({
    super.key,
    this.apiClient,
    this.permissionProbe = const DevicePermissionProbe(),
  });

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late final ApiClient _api = widget.apiClient ?? AuthService().apiClient;
  Map<String, dynamic>? _prefs;
  bool _loadFailed = false;
  bool _saving = false;
  String? _error;
  OsPermission _os = OsPermission.unknown;

  @override
  void initState() {
    super.initState();
    _load();
    _readOs();
  }

  Future<void> _readOs() async {
    final state = await widget.permissionProbe.notification();
    if (mounted) setState(() => _os = state);
  }

  Future<void> _load() async {
    setState(() {
      _loadFailed = false;
      _prefs = null;
    });
    try {
      final json = await _api.getJson('/api/notification-prefs') as Map;
      final prefs = Map<String, dynamic>.from(json['prefs'] as Map);
      if (!mounted) return;
      setState(() => _prefs = {...kNotificationPrefDefaults, ...prefs});
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _save(String key, Object value) async {
    if (!mounted || _saving) return;
    final previous = _prefs![key];
    setState(() {
      _saving = true;
      _error = null;
      _prefs = {..._prefs!, key: value};
    });
    try {
      final response = await _api.putJson(
        '/api/notification-prefs',
        body: {key: value},
      );
      if (!mounted) return;
      if (response is Map && response['prefs'] is Map) {
        setState(
          () => _prefs = {
            ..._prefs!,
            ...Map<String, dynamic>.from(response['prefs'] as Map),
          },
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _prefs = {..._prefs!, key: previous};
        _error = '저장하지 못했어요. 다시 시도해 주세요.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime(String key) async {
    if (_saving) return;
    final parts = '${_prefs![key]}'.split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 22,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
      helpText: key == 'quiet_start' ? '방해금지 시작' : '방해금지 종료',
      confirmText: '확인',
      cancelText: '취소',
      builder: (ctx, child) => V2Theme(child: child!),
    );
    if (time == null || !mounted) return;
    await _save(
      key,
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _pickRevealHour() async {
    if (_saving) return;
    final current = (_prefs!['reveal_hour'] as num?)?.toInt() ?? 21;
    final hour = await showV2Sheet<int>(
      context,
      title: '오늘의 기록 공개 시각',
      subtitle: '이 시각에 둘의 오늘 기록이 함께 열려요',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var h = 0; h < 24; h++)
            V2ListTile(
              key: ValueKey('reveal_option_$h'),
              title: koreanClock('${h.toString().padLeft(2, '0')}:00'),
              trailing: h == current
                  ? Icon(V2Icons.check, color: V2Palette.of(ctx).primary)
                  : null,
              showChevron: false,
              onTap: () => Navigator.of(ctx).pop(h),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
    if (hour != null && mounted) await _save('reveal_hour', hour);
  }

  Future<void> _openOsSettings() async {
    final opened = await widget.permissionProbe.openSettings();
    if (!opened && mounted) {
      showV2Snack(context, '휴대폰 설정 → 비밀기지 → 알림에서 켜 주세요');
    }
  }

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Scaffold(
        appBar: const V2Header(title: '알림'),
        body: _loadFailed
            ? V2ErrorState(
                title: '설정을 불러오지 못했어요',
                body: '연결 상태를 확인하고 다시 시도해 주세요.\n바꾼 내용은 저장되지 않았어요.',
                onRetry: _load,
              )
            : _prefs == null
            ? const _NotificationSkeleton()
            : _content(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final prefs = _prefs!;
    final partner = partnerDisplayName(AuthService().user) ?? '파트너';
    final quietOn = prefs['quiet_hours_enabled'] == true;
    final revealHour = (prefs['reveal_hour'] as num?)?.toInt() ?? 21;
    final probe = widget.permissionProbe;
    final items = <(String, String, String, V2Tone, IconData)>[
      (
        'partner_moment',
        '$partner의 새 기록',
        '${withSubjectParticle(partner)} 기록을 남기면 알려 드려요',
        V2Tone.rose,
        V2Icons.record,
      ),
      (
        'today_loop',
        '오늘의 기록 공개',
        '둘의 오늘 기록이 열리면 알려 드려요',
        V2Tone.lilac,
        V2Icons.sparkle,
      ),
      (
        'game_invite',
        '놀이 초대',
        '${withSubjectParticle(partner)} 놀이에 초대하면 알려 드려요',
        V2Tone.sky,
        V2Icons.play,
      ),
    ];

    Widget toggle(String key, String label, {bool enabled = true}) => V2Toggle(
      key: ValueKey('pref_$key'),
      value: prefs[key] == true,
      semanticLabel: label,
      onChanged: _saving || !enabled ? null : (v) => _save(key, v),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        if (_os == OsPermission.denied)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: V2Banner(
              tone: V2BannerTone.warn,
              icon: V2Icons.bellOff,
              title: probe.canOpenSettings
                  ? '휴대폰에서 알림이 꺼져 있어요'
                  : '브라우저에서 알림이 꺼져 있어요',
              message: probe.canOpenSettings
                  ? '아래 설정을 바꿔도 알림이 오지 않아요. 휴대폰 설정에서 켜 주세요.'
                  : '아래 설정을 바꿔도 알림이 오지 않아요. 주소창 왼쪽의 자물쇠 아이콘에서 알림을 허용해 주세요.',
              actionLabel: probe.canOpenSettings ? '휴대폰 설정 열기' : null,
              onAction: probe.canOpenSettings ? _openOsSettings : null,
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: V2Banner(tone: V2BannerTone.err, message: _error!),
          ),
        V2Section(
          title: '받고 싶은 알림',
          child: V2List(
            children: [
              for (final (key, title, subtitle, tone, icon) in items)
                V2ListTile(
                  icon: icon,
                  tone: tone,
                  title: title,
                  subtitle: subtitle,
                  trailing: toggle(key, title),
                ),
            ],
          ),
        ),
        V2Section(
          title: '오늘의 기록',
          child: V2List(
            children: [
              V2ListTile(
                key: const ValueKey('pref_reveal_hour'),
                icon: V2Icons.calendar,
                tone: V2Tone.peach,
                title: '공개 시각',
                subtitle: '이 시각에 둘의 오늘 기록이 함께 열려요',
                trailing: Text(
                  koreanClock('${revealHour.toString().padLeft(2, '0')}:00'),
                  style: V2Text.bodyStrong.copyWith(
                    color: V2Palette.of(context).sub,
                  ),
                ),
                showChevron: true,
                onTap: _saving ? null : _pickRevealHour,
              ),
            ],
          ),
        ),
        V2Section(
          title: '방해금지',
          child: V2List(
            children: [
              V2ListTile(
                icon: V2Icons.bellOff,
                tone: V2Tone.sage,
                title: '방해금지 시간',
                subtitle: '이 시간에는 알림을 보내지 않아요',
                trailing: toggle('quiet_hours_enabled', '방해금지 시간'),
              ),
              for (final (key, title) in const [
                ('quiet_start', '시작'),
                ('quiet_end', '종료'),
              ])
                V2ListTile(
                  key: ValueKey('pref_$key'),
                  title: title,
                  trailing: Text(
                    koreanClock('${prefs[key]}'),
                    style: V2Text.bodyStrong.copyWith(
                      color: quietOn
                          ? V2Palette.of(context).ink
                          : V2Palette.of(context).muted,
                    ),
                  ),
                  showChevron: quietOn,
                  onTap: _saving || !quietOn ? null : () => _pickTime(key),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: Text(
            '방해금지 중에 생긴 소식은 알림 없이 앱 안에만 쌓여요. 오늘의 기록 공개 알림은 끝나는 시간 뒤에 보내 드려요.',
            style: V2Text.cap,
          ),
        ),
        if (_saving)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: LinearProgressIndicator(minHeight: 3),
          ),
      ],
    );
  }
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) => const SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        V2Shimmer(
          semanticLabel: '알림 설정을 불러오는 중',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              V2SkeletonLine(width: 120),
              SizedBox(height: 12),
              V2SkeletonBox(height: 200, radius: 20),
              SizedBox(height: 28),
              V2SkeletonLine(width: 80),
              SizedBox(height: 12),
              V2SkeletonBox(height: 150, radius: 20),
            ],
          ),
        ),
      ],
    ),
  );
}
