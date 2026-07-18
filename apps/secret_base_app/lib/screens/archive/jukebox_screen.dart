import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/auth_service.dart';
import '../../core/main_design.dart';

class JukeboxScreen extends StatefulWidget {
  const JukeboxScreen({super.key});

  @override
  State<JukeboxScreen> createState() => _JukeboxScreenState();
}

class _JukeboxScreenState extends State<JukeboxScreen> {
  final _auth = AuthService();
  List<Map<String, dynamic>> _tracks = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('${_auth.baseUrl}/api/jukebox'));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] == true) {
        setState(() {
          _tracks =
              (data['tracks'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _showUploadDialog() {
    final titleCtrl = TextEditingController();
    final artistCtrl = TextEditingController();
    ({Uint8List bytes, String name})? pickedFile;

    void pickFile(StateSetter setDlg) {
      if (!kIsWeb) return;
      final input = html.FileUploadInputElement()..accept = 'audio/*';
      input.click();
      input.onChange.listen((_) {
        final file = input.files?.first;
        if (file == null) return;
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        reader.onLoad.listen((_) {
          // ignore: avoid_dynamic_calls
          final jsBuffer = reader.result as dynamic;
          final bytes = Uint8List.view(jsBuffer as ByteBuffer);
          setDlg(() => pickedFile = (bytes: bytes, name: file.name));
        });
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: kMainPaper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('트랙 추가', style: mainTitle(size: 22)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(titleCtrl, '곡 이름', '예: 우리의 노래'),
                const SizedBox(height: 10),
                _field(artistCtrl, '아티스트 (선택)', '예: 윤하'),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => pickFile(setDlg),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kMainPaperSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: pickedFile != null ? kMainSage : kMainLine,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          pickedFile != null
                              ? Icons.audio_file
                              : Icons.upload_file,
                          color: pickedFile != null ? kMainSage : kMainMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pickedFile?.name ?? '오디오 파일 선택',
                            style: mainBody(
                              size: 13,
                              color: pickedFile != null ? kMainInk : kMainMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('취소', style: mainBody(size: 14, color: kMainMuted)),
            ),
            FilledButton(
              onPressed: pickedFile == null || titleCtrl.text.trim().isEmpty
                  ? null
                  : () async {
                      final f = pickedFile!;
                      Navigator.pop(ctx);
                      await _upload(
                        bytes: f.bytes,
                        fileName: f.name,
                        title: titleCtrl.text.trim(),
                        artist: artistCtrl.text.trim(),
                      );
                    },
              style: FilledButton.styleFrom(
                backgroundColor: kMainPeach,
                foregroundColor: Colors.white,
                disabledBackgroundColor: kMainLine,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '업로드',
                style: mainBody(
                  size: 14,
                  color: Colors.white,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextField _field(TextEditingController ctrl, String label, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: kMainPaperSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        labelStyle: mainBody(size: 12, color: kMainMuted),
        hintStyle: mainBody(size: 13, color: kMainMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      style: mainBody(size: 14, color: kMainInk),
    );
  }

  Future<void> _upload({
    required Uint8List bytes,
    required String fileName,
    required String title,
    required String artist,
  }) async {
    setState(() => _uploading = true);
    final userCode =
        _auth.user?['UserCode'] ?? _auth.user?['userCode'] ?? 'unknown';
    final uri = Uri.parse('${_auth.baseUrl}/api/jukebox');
    final request = http.MultipartRequest('POST', uri)
      ..fields['title'] = title
      ..fields['uploaded_by'] = userCode
      ..files.add(
        http.MultipartFile.fromBytes('audio', bytes, filename: fileName),
      );
    if (artist.isNotEmpty) request.fields['artist'] = artist;
    try {
      final response = await request.send();
      if (response.statusCode == 200) await _load();
    } catch (_) {}
    if (mounted) setState(() => _uploading = false);
  }

  void _playTrack(String url) {
    final fullUrl = url.startsWith('http') ? url : '${_auth.baseUrl}$url';
    if (kIsWeb) html.window.open(fullUrl, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        foregroundColor: kMainInk,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '🎵 주크박스',
          style: mainBody(size: 17, color: kMainInk, weight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploading ? null : _showUploadDialog,
        backgroundColor: kMainPeach,
        foregroundColor: Colors.white,
        child: _uploading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add),
      ),
      body: CozyPage(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                color: kMainPeach,
                child: _tracks.isEmpty ? _empty() : _list(),
              ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎵', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('아직 트랙이 없어요', style: mainTitle(size: 22)),
          const SizedBox(height: 6),
          Text('우리만의 플레이리스트를 만들어요', style: mainBody(size: 13)),
        ],
      ),
    );
  }

  Widget _list() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
      itemCount: _tracks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _trackCard(_tracks[i]),
    );
  }

  Widget _trackCard(Map<String, dynamic> track) {
    final fileUrl = track['file_url'] as String?;
    final durSec = (track['duration_sec'] as num?)?.toInt();
    final durStr = durSec != null
        ? '${durSec ~/ 60}:${(durSec % 60).toString().padLeft(2, '0')}'
        : null;

    return MainCard(
      child: Row(
        children: [
          DoodleBadge(
            color: kMainPeach,
            backgroundColor: kMainPeachSoft,
            size: 52,
            child: const Text('🎵', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track['title'] ?? '제목 없음',
                  style: mainBody(
                    size: 15,
                    color: kMainInk,
                    weight: FontWeight.w700,
                  ),
                ),
                if ((track['artist'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    track['artist'],
                    style: mainBody(size: 12, color: kMainMuted),
                  ),
                ],
                if (durStr != null) ...[
                  const SizedBox(height: 2),
                  Text(durStr, style: mainBody(size: 11, color: kMainMuted)),
                ],
              ],
            ),
          ),
          if (fileUrl != null)
            IconButton(
              onPressed: () => _playTrack(fileUrl),
              icon: const Icon(Icons.play_circle_filled_rounded),
              iconSize: 36,
              color: kMainPeach,
            ),
        ],
      ),
    );
  }
}
