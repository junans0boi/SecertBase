import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/http/api_client.dart';
import '../../core/main_design.dart';

const _items = <(String, String, String)>[
  ('partner_moment', '상대방 기록', '상대방이 새 기록을 남기면 알려드려요'),
  ('today_loop', '오늘의 루프 공개', '오늘의 루프가 공개되면 알려드려요'),
  ('game_invite', '게임 초대', '상대방이 게임에 초대하면 알려드려요'),
];

class NotificationSettingsScreen extends StatefulWidget {
  final ApiClient? apiClient;

  const NotificationSettingsScreen({super.key, this.apiClient});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late final ApiClient _api = widget.apiClient ?? AuthService().apiClient;
  Map<String, dynamic>? _prefs;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await _api.getJson('/api/notification-prefs') as Map;
      final prefs = Map<String, dynamic>.from(json['prefs'] as Map);
      if (!mounted) return;
      setState(
        () => _prefs = {
          'partner_moment': true,
          'today_loop': true,
          'game_invite': true,
          'quiet_hours_enabled': true,
          'quiet_start': '22:00',
          'quiet_end': '08:00',
          'reveal_hour': 21,
          ...prefs,
        },
      );
    } catch (_) {
      if (mounted) setState(() => _error = '알림 설정을 불러오지 못했어요.');
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
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
      confirmText: '확인',
      cancelText: '취소',
    );
    if (time == null || !mounted) return;
    await _save(
      key,
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _pickRevealHour() async {
    final hour = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('오늘의 루프 공개 시각'),
        children: [
          for (var hour = 0; hour < 24; hour++)
            SimpleDialogOption(
              key: ValueKey('reveal_option_$hour'),
              onPressed: () => Navigator.pop(context, hour),
              child: Text('${hour.toString().padLeft(2, '0')}:00'),
            ),
        ],
      ),
    );
    if (hour != null && mounted) await _save('reveal_hour', hour);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        title: Text('알림 설정', style: mainTitle(size: 22)),
        backgroundColor: kMainBg,
        elevation: 0,
      ),
      body: _prefs == null
          ? Center(
              child: _error != null
                  ? Text(_error!, style: mainBody(size: 14))
                  : const CircularProgressIndicator(color: kMainRose),
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: mainBody(size: 13)),
                  ),
                for (final (key, title, subtitle) in _items)
                  SwitchListTile(
                    key: ValueKey('pref_$key'),
                    value: _prefs![key] == true,
                    onChanged: _saving ? null : (v) => _save(key, v),
                    activeThumbColor: kMainRose,
                    title: Text(title, style: mainBody(size: 15)),
                    subtitle: Text(subtitle, style: mainBody(size: 12)),
                  ),
                SwitchListTile(
                  key: const ValueKey('pref_quiet_hours_enabled'),
                  title: Text('방해금지 시간', style: mainBody(size: 15)),
                  value: _prefs!['quiet_hours_enabled'] == true,
                  activeThumbColor: kMainRose,
                  onChanged: _saving
                      ? null
                      : (v) => _save('quiet_hours_enabled', v),
                ),
                for (final (key, title) in const [
                  ('quiet_start', '시작 시각'),
                  ('quiet_end', '종료 시각'),
                ])
                  ListTile(
                    key: ValueKey('pref_$key'),
                    title: Text(title),
                    trailing: Text('${_prefs![key]}'),
                    enabled: !_saving && _prefs!['quiet_hours_enabled'] == true,
                    onTap: () => _pickTime(key),
                  ),
                ListTile(
                  key: const ValueKey('pref_reveal_hour'),
                  title: const Text('오늘의 루프 공개 시각'),
                  trailing: Text(
                    '${(_prefs!['reveal_hour'] as int).toString().padLeft(2, '0')}:00',
                  ),
                  enabled: !_saving,
                  onTap: _pickRevealHour,
                ),
                if (_saving) const LinearProgressIndicator(color: kMainRose),
              ],
            ),
    );
  }
}
