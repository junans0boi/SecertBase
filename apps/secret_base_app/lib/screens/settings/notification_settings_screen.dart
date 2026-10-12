import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/http/api_client.dart';
import '../../core/main_design.dart';
import '../../core/main_hero.dart';

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
  Map<String, bool>? _prefs;
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
      setState(() => _prefs = {for (final e in prefs.entries) e.key: e.value == true});
    } catch (_) {
      if (mounted) setState(() => _error = '알림 설정을 불러오지 못했어요.');
    }
  }

  Future<void> _toggle(String key, bool value) async {
    final previous = _prefs![key] ?? true;
    setState(() => _prefs = {..._prefs!, key: value});
    try {
      await _api.putJson('/api/notification-prefs', body: {key: value});
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _prefs = {..._prefs!, key: previous};
        _error = '저장하지 못했어요. 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainCream,
      appBar: AppBar(
        title: Text('알림 설정', style: mainTitle(size: 22)),
        backgroundColor: kMainCream,
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
                    value: _prefs![key] ?? true,
                    onChanged: (v) => _toggle(key, v),
                    activeThumbColor: kMainRose,
                    title: Text(title, style: mainBody(size: 15)),
                    subtitle: Text(subtitle, style: mainBody(size: 12)),
                  ),
              ],
            ),
    );
  }
}
