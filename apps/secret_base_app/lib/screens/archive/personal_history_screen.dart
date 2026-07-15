import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/auth_service.dart';
import '../../core/main_design.dart';

class PersonalHistoryScreen extends StatefulWidget {
  const PersonalHistoryScreen({super.key});

  @override
  State<PersonalHistoryScreen> createState() => _PersonalHistoryScreenState();
}

class _PersonalHistoryScreenState extends State<PersonalHistoryScreen> {
  final _auth = AuthService();
  List<Map<String, dynamic>> _moments = [];
  List<Map<String, dynamic>> _pins = [];
  bool _loading = true;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${_auth.token}',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final response = await http.get(
      Uri.parse('${_auth.baseUrl}/api/history'),
      headers: _headers,
    );
    if (!mounted) return;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    setState(() {
      _loading = false;
      _moments = (data['moments'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      _pins = (data['pins'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });
  }

  Future<void> _delete(String kind, int id) async {
    final response = await http.delete(
      Uri.parse('${_auth.baseUrl}/api/history/$kind/$id'),
      headers: _headers,
    );
    if (response.statusCode == 200) await _load();
  }

  Future<void> _export() async {
    final response = await http.get(
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
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
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
}
