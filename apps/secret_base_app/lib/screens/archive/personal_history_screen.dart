import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/auth_service.dart';
import '../../core/main_design.dart';

class PersonalHistoryScreen extends StatefulWidget {
  final http.Client? client;

  const PersonalHistoryScreen({super.key, this.client});

  @override
  State<PersonalHistoryScreen> createState() => _PersonalHistoryScreenState();
}

class _PersonalHistoryScreenState extends State<PersonalHistoryScreen> {
  final _auth = AuthService();
  List<Map<String, dynamic>> _moments = [];
  List<Map<String, dynamic>> _pins = [];
  bool _loading = true;
  String? _error;
  late final http.Client _client;
  late final bool _ownsClient;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${_auth.token}',
  };

  @override
  void initState() {
    super.initState();
    _ownsClient = widget.client == null;
    _client = widget.client ?? http.Client();
    _load();
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await _client.get(
        Uri.parse('${_auth.baseUrl}/api/history'),
        headers: _headers,
      );
      if (!mounted) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const FormatException();
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _moments = (data['moments'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _pins = (data['pins'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });
    } catch (_) {
      if (mounted) setState(() => _error = '개인 보관함을 불러오지 못했어요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String kind, int id) async {
    final response = await _client.delete(
      Uri.parse('${_auth.baseUrl}/api/history/$kind/$id'),
      headers: _headers,
    );
    if (response.statusCode == 200) await _load();
  }

  Future<void> _export() async {
    final response = await _client.get(
      Uri.parse('${_auth.baseUrl}/api/history/export'),
      headers: _headers,
    );
    if (response.statusCode != 200) return;
    await FilePicker.saveFile(
      dialogTitle: '개인 보관함 내보내기',
      fileName: 'secretbase-personal-history.zip',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      bytes: response.bodyBytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        title: const Text('개인 보관함'),
        actions: [
          IconButton(
            tooltip: 'ZIP 내보내기',
            onPressed: _export,
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainRose))
          : _error != null
          ? _errorState()
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                MainCard(
                  color: kMainSageSoft,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: kMainSage),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '나만 보는 개인 기록이에요. 필요하면 ZIP 파일로 내보낼 수 있어요.',
                          style: mainBody(
                            size: 13,
                            color: kMainSub,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('내 MomentLoop', style: mainTitle(size: 22)),
                const SizedBox(height: 8),
                if (_moments.isEmpty) const Text('보관된 기록이 없어요.'),
                ..._moments.map(
                  (moment) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_stories_outlined),
                    title: Text('${moment['caption'] ?? '사진으로 남긴 순간'}'),
                    subtitle: moment['linked_place_name'] == null
                        ? null
                        : Text('${moment['linked_place_name']}'),
                    trailing: IconButton(
                      tooltip: '삭제',
                      onPressed: () => _delete('moments', moment['id'] as int),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('내 지도 핀', style: mainTitle(size: 22)),
                const SizedBox(height: 8),
                if (_pins.isEmpty) const Text('보관된 장소가 없어요.'),
                ..._pins.map(
                  (pin) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.place_outlined),
                    title: Text('${pin['place_name'] ?? '장소'}'),
                    subtitle: Text('${pin['memo'] ?? ''}'),
                    trailing: IconButton(
                      tooltip: '삭제',
                      onPressed: () => _delete('pins', pin['id'] as int),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: MainCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42, color: kMainRose),
              const SizedBox(height: 12),
              Text(_error!, style: mainTitle(size: 18)),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('다시 불러오기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
