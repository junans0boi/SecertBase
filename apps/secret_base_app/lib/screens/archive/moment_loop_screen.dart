import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/auth_service.dart';
import '../../core/main_design.dart';

class MomentLoopScreen extends StatefulWidget {
  const MomentLoopScreen({super.key});

  @override
  State<MomentLoopScreen> createState() => _MomentLoopScreenState();
}

class _MomentLoopScreenState extends State<MomentLoopScreen> {
  final _auth = AuthService();
  final _captionCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  List<Map<String, dynamic>> _posts = [];
  _PickedMomentMedia? _pickedMedia;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _loading = false;
        _error = '로그인 정보가 없어요';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
        '${_auth.baseUrl}/api/setlog',
      ).replace(queryParameters: {'user_id': '$userId'});
      final response = await http.get(uri);
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['ok'] == true) {
        final posts = data['posts'];
        setState(() {
          _posts = posts is List
              ? posts
                    .map((item) => Map<String, dynamic>.from(item as Map))
                    .toList()
              : [];
        });
      } else {
        setState(() => _error = '기록을 불러오지 못했어요');
      }
    } catch (e) {
      setState(() => _error = '네트워크 연결을 확인해주세요');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveMoment() async {
    final userId = _userId;
    if (_saving || userId == null) return;

    final caption = _captionCtrl.text.trim();
    if (caption.isEmpty && _pickedMedia == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('글이나 이미지/영상을 하나 남겨주세요')));
      return;
    }

    setState(() => _saving = true);

    final now = DateTime.now();
    try {
      http.Response response;

      if (_pickedMedia == null) {
        response = await http.post(
          Uri.parse('${_auth.baseUrl}/api/setlog'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'user_code': _auth.user?['UserCode'],
            'media_type': 'text',
            'caption': caption,
            'tags': ['#momentloop'],
            'taken_at': _dateOnly(now),
            'captured_at': _mysqlDateTime(now),
          }),
        );
      } else {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${_auth.baseUrl}/api/setlog'),
        );
        request.fields.addAll({
          'user_id': '$userId',
          'user_code': '${_auth.user?['UserCode'] ?? ''}',
          'caption': caption,
          'tags': jsonEncode(['#momentloop']),
          'taken_at': _dateOnly(now),
          'captured_at': _mysqlDateTime(now),
        });

        final media = _pickedMedia!;
        request.files.add(
          http.MultipartFile.fromBytes(
            'media',
            media.bytes,
            filename: media.name,
          ),
        );

        final streamed = await request.send();
        response = await http.Response.fromStream(streamed);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['ok'] == true) {
        _captionCtrl.clear();
        _pickedMedia = null;
        await _loadPosts();
      } else {
        _showSaveError();
      }
    } catch (_) {
      _showSaveError();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int? get _userId {
    final value = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (value is int) return value;
    return int.tryParse('$value');
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _mysqlDateTime(DateTime value) =>
      '${_dateOnly(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

  void _showSaveError() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('기록 저장에 실패했어요')));
  }

  void _refreshComposer([StateSetter? setSheetState]) {
    if (mounted) setState(() {});
    setSheetState?.call(() {});
  }

  Future<void> _pickMedia([StateSetter? setSheetState]) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'mp4',
        'mov',
        'webm',
      ],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _showMediaError();
      return;
    }

    _pickedMedia = _PickedMomentMedia(
      name: file.name,
      bytes: bytes,
      isVideo: !_isImageName(file.name),
    );
    _refreshComposer(setSheetState);
  }

  Future<void> _captureImage([StateSetter? setSheetState]) async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    _pickedMedia = _PickedMomentMedia(
      name: file.name,
      bytes: bytes,
      isVideo: false,
    );
    _refreshComposer(setSheetState);
  }

  Future<void> _captureVideo([StateSetter? setSheetState]) async {
    final file = await _imagePicker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 4),
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    _pickedMedia = _PickedMomentMedia(
      name: file.name,
      bytes: bytes,
      isVideo: true,
    );
    _refreshComposer(setSheetState);
  }

  void _clearMedia([StateSetter? setSheetState]) {
    _pickedMedia = null;
    _refreshComposer(setSheetState);
  }

  void _showMediaError() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('파일을 읽지 못했어요')));
  }

  @override
  Widget build(BuildContext context) {
    final todayPosts = _todayPosts;
    final myCode = '${_auth.user?['UserCode'] ?? ''}';
    final myCount = todayPosts
        .where((post) => '${post['user_code']}' == myCode)
        .length;
    final partnerCount = todayPosts.length - myCount;
    final mediaCount = todayPosts
        .where((post) => post['media_url'] != null)
        .length;

    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        foregroundColor: kMainInk,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('MomentLoop', style: mainBody(weight: FontWeight.w800)),
      ),
      body: CozyPage(
        child: RefreshIndicator(
          onRefresh: _loadPosts,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              _HeroLoopCard(
                totalCount: todayPosts.length,
                myCount: myCount,
                partnerCount: partnerCount,
                mediaCount: mediaCount,
                onRecord: _showComposer,
                onPlay: todayPosts.isEmpty ? null : () => _openLoop(todayPosts),
              ),
              const SizedBox(height: 12),
              _InlineMomentComposer(
                captionCtrl: _captionCtrl,
                pickedMedia: _pickedMedia,
                saving: _saving,
                onCaptureImage: _captureImage,
                onCaptureVideo: _captureVideo,
                onPickMedia: _pickMedia,
                onClearMedia: _clearMedia,
                onSave: _saveMoment,
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _EmptyState(message: _error!, action: _loadPosts)
              else if (_posts.isEmpty)
                _EmptyState(
                  message: '아직 남긴 순간이 없어요',
                  action: _showComposer,
                  actionLabel: '첫 순간 남기기',
                )
              else ...[
                _TodayRhythm(posts: todayPosts),
                const SizedBox(height: 12),
                _SectionTitle(
                  title: '오늘의 조각',
                  trailing: '${todayPosts.length}개',
                ),
                const SizedBox(height: 8),
                ...todayPosts.map((post) => _MomentCard(post: post)),
                if (_olderPosts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _SectionTitle(
                    title: '지난 루프',
                    trailing: '${_olderPosts.length}개',
                  ),
                  const SizedBox(height: 8),
                  ..._olderPosts.map(
                    (post) => _MomentCard(post: post, compact: true),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _todayPosts {
    final today = _dateOnly(DateTime.now());
    final posts = _posts.where((post) => _dateFromPost(post) == today).toList();
    posts.sort((a, b) => _dateTimeFromPost(a).compareTo(_dateTimeFromPost(b)));
    return posts;
  }

  List<Map<String, dynamic>> get _olderPosts {
    final today = _dateOnly(DateTime.now());
    return _posts.where((post) => _dateFromPost(post) != today).toList();
  }

  String _dateFromPost(Map<String, dynamic> post) {
    final value =
        '${post['taken_at'] ?? post['captured_at'] ?? post['created_at'] ?? ''}';
    if (value.length >= 10) return value.substring(0, 10);
    return '';
  }

  DateTime _dateTimeFromPost(Map<String, dynamic> post) {
    final raw =
        '${post['captured_at'] ?? post['created_at'] ?? post['taken_at'] ?? ''}';
    return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _openLoop(List<Map<String, dynamic>> posts) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MomentLoopPlayerScreen(posts: posts)),
    );
  }

  void _showComposer() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 14,
              ),
              child: MainCard(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('지금 순간', style: mainTitle(size: 24)),
                    const SizedBox(height: 4),
                    Text('보정 없이 글, 사진, 짧은 영상을 남겨요', style: mainBody(size: 13)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _captureImage(setSheetState),
                          icon: const Icon(Icons.photo_camera_rounded),
                          label: const Text('사진 촬영'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _captureVideo(setSheetState),
                          icon: const Icon(Icons.videocam_rounded),
                          label: const Text('4초 영상'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _pickMedia(setSheetState),
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('파일 선택'),
                        ),
                      ],
                    ),
                    if (_pickedMedia != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _PickedMediaPreview(media: _pickedMedia!),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _clearMedia(setSheetState),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: '선택 취소',
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      controller: _captionCtrl,
                      autofocus: _pickedMedia == null,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: '예: 버스 기다리는 중, 커피 식는 중',
                        filled: true,
                        fillColor: kMainBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: kMainLine),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: kMainLine),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                await _saveMoment();
                                if (context.mounted && !_saving) {
                                  Navigator.pop(context);
                                }
                              },
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.bolt_rounded),
                        label: Text(
                          '기록하기',
                          style: mainBody(weight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _HeroLoopCard extends StatelessWidget {
  final int totalCount;
  final int myCount;
  final int partnerCount;
  final int mediaCount;
  final VoidCallback onRecord;
  final VoidCallback? onPlay;

  const _HeroLoopCard({
    required this.totalCount,
    required this.myCount,
    required this.partnerCount,
    required this.mediaCount,
    required this.onRecord,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return MainCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      color: kMainPaper,
      borderColor: kMainRose.withAlpha(90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DoodleBadge(
                color: kMainRose,
                backgroundColor: kMainRoseSoft,
                size: 58,
                child: const Icon(
                  Icons.auto_awesome_motion_rounded,
                  color: kMainRose,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today Loop', style: mainTitle(size: 30)),
                    const SizedBox(height: 2),
                    Text('둘이 남긴 오늘의 날것 같은 조각', style: mainBody(size: 13)),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: onRecord,
                icon: const Icon(Icons.add_rounded),
                tooltip: '순간 기록',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _LoopMetric(label: '전체', value: '$totalCount', color: kMainRose),
              const SizedBox(width: 8),
              _LoopMetric(label: '나', value: '$myCount', color: kMainSky),
              const SizedBox(width: 8),
              _LoopMetric(
                label: '상대',
                value: '$partnerCount',
                color: kMainSage,
              ),
              const SizedBox(width: 8),
              _LoopMetric(
                label: '미디어',
                value: '$mediaCount',
                color: kMainHoney,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                totalCount == 0 ? '오늘의 루프가 비었어요' : '오늘의 루프 보기',
                style: mainBody(color: Colors.white, weight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMomentComposer extends StatelessWidget {
  final TextEditingController captionCtrl;
  final _PickedMomentMedia? pickedMedia;
  final bool saving;
  final VoidCallback onCaptureImage;
  final VoidCallback onCaptureVideo;
  final VoidCallback onPickMedia;
  final VoidCallback onClearMedia;
  final Future<void> Function() onSave;

  const _InlineMomentComposer({
    required this.captionCtrl,
    required this.pickedMedia,
    required this.saving,
    required this.onCaptureImage,
    required this.onCaptureVideo,
    required this.onPickMedia,
    required this.onClearMedia,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return MainCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('순간 남기기', style: mainTitle(size: 21))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: kMainRoseSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pickedMedia == null
                      ? '글 / 사진 / 영상'
                      : pickedMedia!.isVideo
                      ? '영상 선택됨'
                      : '이미지 선택됨',
                  style: mainBody(
                    size: 12,
                    color: kMainRose,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: saving ? null : onCaptureImage,
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('사진'),
              ),
              OutlinedButton.icon(
                onPressed: saving ? null : onCaptureVideo,
                icon: const Icon(Icons.videocam_rounded),
                label: const Text('4초 영상'),
              ),
              OutlinedButton.icon(
                onPressed: saving ? null : onPickMedia,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('파일'),
              ),
            ],
          ),
          if (pickedMedia != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _PickedMediaPreview(media: pickedMedia!)),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: saving ? null : onClearMedia,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: '선택 취소',
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: captionCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '예: 버스 기다리는 중, 커피 식는 중',
              filled: true,
              fillColor: kMainBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: kMainLine),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: kMainLine),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt_rounded),
              label: Text('기록하기', style: mainBody(weight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoopMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _LoopMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(90)),
        ),
        child: Column(
          children: [
            Text(value, style: mainTitle(size: 24, color: kMainInk)),
            Text(label, style: mainBody(size: 11, color: kMainSub, height: 1)),
          ],
        ),
      ),
    );
  }
}

class _TodayRhythm extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  const _TodayRhythm({required this.posts});

  @override
  Widget build(BuildContext context) {
    final hours = List.generate(24, (index) => index);
    final activeHours = posts
        .map(
          (post) => DateTime.tryParse(
            '${post['captured_at'] ?? post['created_at'] ?? ''}',
          )?.hour,
        )
        .whereType<int>()
        .toSet();

    return MainCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      color: kMainPaperSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: '하루 리듬', trailing: '${activeHours.length}시간'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 5,
            runSpacing: 6,
            children: hours.map((hour) {
              final active = activeHours.contains(hour);
              return Container(
                width: 21,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? kMainRose : kMainPaper,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: active ? kMainRose : kMainLine),
                ),
                child: Text(
                  '$hour',
                  style: mainBody(
                    size: 9,
                    color: active ? Colors.white : kMainMuted,
                    weight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: mainTitle(size: 22)),
        const Spacer(),
        if (trailing != null)
          Text(trailing!, style: mainBody(size: 12, color: kMainMuted)),
      ],
    );
  }
}

class MomentLoopPlayerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  const MomentLoopPlayerScreen({super.key, required this.posts});

  @override
  State<MomentLoopPlayerScreen> createState() => _MomentLoopPlayerScreenState();
}

class _MomentLoopPlayerScreenState extends State<MomentLoopPlayerScreen> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posts = widget.posts;
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        foregroundColor: kMainInk,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('오늘의 루프', style: mainBody(weight: FontWeight.w800)),
      ),
      body: CozyPage(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
              child: MainCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                color: kMainRoseSoft,
                borderColor: kMainRose.withAlpha(90),
                child: Row(
                  children: [
                    Text(
                      '${_index + 1}',
                      style: mainTitle(size: 34, color: kMainRose),
                    ),
                    Text(
                      ' / ${posts.length}',
                      style: mainBody(weight: FontWeight.w800),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: posts.isEmpty ? 0 : (_index + 1) / posts.length,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(999),
                        backgroundColor: Colors.white.withAlpha(140),
                        color: kMainRose,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: posts.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(6, 8, 6, 22),
                    child: _LoopSlide(post: posts[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoopSlide extends StatelessWidget {
  final Map<String, dynamic> post;
  const _LoopSlide({required this.post});

  @override
  Widget build(BuildContext context) {
    final caption = '${post['caption'] ?? ''}';
    final name = '${post['UserName'] ?? post['user_code'] ?? '나'}';
    final mediaType = '${post['media_type'] ?? 'text'}';
    final mediaUrl = post['media_url'] == null ? null : '${post['media_url']}';
    final time = _compactTime(
      '${post['captured_at'] ?? post['created_at'] ?? ''}',
    );

    return MainCard(
      padding: const EdgeInsets.all(18),
      borderColor: kMainRose.withAlpha(90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DoodleBadge(
                color: kMainRose,
                backgroundColor: kMainRoseSoft,
                size: 48,
                child: Text(
                  name.isEmpty ? '?' : name.substring(0, 1),
                  style: mainBody(weight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: mainBody(size: 16, weight: FontWeight.w900),
                    ),
                    Text(time, style: mainBody(size: 12, color: kMainMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: mediaUrl == null
                ? Center(
                    child: Text(
                      caption,
                      style: mainTitle(size: 32),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Center(
                    child: _PostMedia(mediaType: mediaType, mediaUrl: mediaUrl),
                  ),
          ),
          if (mediaUrl != null && caption.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(caption, style: mainTitle(size: 24)),
          ],
        ],
      ),
    );
  }

  String _compactTime(String raw) {
    if (raw.length >= 16) return raw.substring(11, 16);
    return raw;
  }
}

class _MomentCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool compact;
  const _MomentCard({required this.post, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final caption = '${post['caption'] ?? ''}';
    final name = '${post['UserName'] ?? post['user_code'] ?? '나'}';
    final capturedAt = '${post['captured_at'] ?? post['created_at'] ?? ''}';
    final mediaType = '${post['media_type'] ?? 'text'}';
    final mediaUrl = post['media_url'] == null ? null : '${post['media_url']}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MainCard(
        padding: EdgeInsets.all(compact ? 13 : 15),
        borderColor: kMainRose.withAlpha(70),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DoodleBadge(
              color: kMainRose,
              backgroundColor: kMainRoseSoft,
              size: compact ? 38 : 44,
              child: Text(
                name.isEmpty ? '?' : name.substring(0, 1),
                style: mainBody(weight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: mainBody(weight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        _compactTime(capturedAt),
                        style: mainBody(size: 11, color: kMainMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (mediaUrl != null) ...[
                    if (compact)
                      _CompactMediaPill(mediaType: mediaType)
                    else
                      _PostMedia(mediaType: mediaType, mediaUrl: mediaUrl),
                    if (caption.isNotEmpty) const SizedBox(height: 8),
                  ],
                  if (caption.isNotEmpty)
                    Text(caption, style: mainBody(size: 15, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compactTime(String raw) {
    if (raw.length >= 16) return raw.substring(11, 16);
    return raw;
  }
}

class _PickedMomentMedia {
  final String name;
  final Uint8List bytes;
  final bool isVideo;

  const _PickedMomentMedia({
    required this.name,
    required this.bytes,
    required this.isVideo,
  });
}

class _CompactMediaPill extends StatelessWidget {
  final String mediaType;
  const _CompactMediaPill({required this.mediaType});

  @override
  Widget build(BuildContext context) {
    final isVideo = mediaType == 'video';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isVideo ? kMainSky : kMainRose).withAlpha(35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (isVideo ? kMainSky : kMainRose).withAlpha(90),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVideo ? Icons.play_circle_rounded : Icons.image_rounded,
            size: 15,
            color: kMainInk,
          ),
          const SizedBox(width: 5),
          Text(
            isVideo ? '영상' : '사진',
            style: mainBody(size: 11, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PickedMediaPreview extends StatelessWidget {
  final _PickedMomentMedia media;
  const _PickedMediaPreview({required this.media});

  @override
  Widget build(BuildContext context) {
    if (!media.isVideo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          media.bytes,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kMainBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMainLine),
      ),
      child: Row(
        children: [
          Icon(media.isVideo ? Icons.videocam_rounded : Icons.image_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              media.name,
              overflow: TextOverflow.ellipsis,
              style: mainBody(weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostMedia extends StatelessWidget {
  final String mediaType;
  final String mediaUrl;
  const _PostMedia({required this.mediaType, required this.mediaUrl});

  @override
  Widget build(BuildContext context) {
    final absoluteUrl = Uri.parse(
      AuthService().baseUrl,
    ).resolve(mediaUrl).toString();
    if (mediaType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          absoluteUrl,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _MediaFallback(label: '이미지를 불러오지 못했어요'),
        ),
      );
    }

    return _VideoPostPlayer(url: absoluteUrl);
  }
}

class _VideoPostPlayer extends StatefulWidget {
  final String url;
  const _VideoPostPlayer({required this.url});

  @override
  State<_VideoPostPlayer> createState() => _VideoPostPlayerState();
}

class _VideoPostPlayerState extends State<_VideoPostPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _error = '영상을 불러오지 못했어요');
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _MediaFallback(label: _error!, icon: Icons.play_disabled_rounded);
    }

    if (!_ready) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          Material(
            color: Colors.black38,
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              icon: Icon(
                _controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaFallback extends StatelessWidget {
  final String label;
  final IconData icon;
  const _MediaFallback({
    required this.label,
    this.icon = Icons.image_not_supported_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: kMainBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMainLine),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: kMainMuted),
          const SizedBox(height: 6),
          Text(label, style: mainBody(size: 13, color: kMainMuted)),
        ],
      ),
    );
  }
}

bool _isImageName(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif');
}

class _EmptyState extends StatelessWidget {
  final String message;
  final VoidCallback action;
  final String actionLabel;
  const _EmptyState({
    required this.message,
    required this.action,
    this.actionLabel = '다시 시도',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Text(
            message,
            style: mainTitle(size: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: action,
            child: Text(actionLabel, style: mainBody(weight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
