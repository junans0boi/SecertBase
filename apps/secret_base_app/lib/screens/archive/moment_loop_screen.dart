import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;

  int? get _userId {
    final value = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (value is int) return value;
    return int.tryParse('$value');
  }

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '로그인 정보가 없어요';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final uri = Uri.parse(
        '${_auth.baseUrl}/api/setlog',
      ).replace(queryParameters: {'user_id': '$userId'});
      final response = await http.get(uri);
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['ok'] == true) {
        final posts = data['posts'];
        if (!mounted) return;
        setState(() {
          _posts = posts is List
              ? posts
                    .map((item) => Map<String, dynamic>.from(item as Map))
                    .toList()
              : [];
          _posts.sort((a, b) {
            final dateA =
                DateTime.tryParse('${a['captured_at'] ?? ''}') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final dateB =
                DateTime.tryParse('${b['captured_at'] ?? ''}') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA);
          });
        });
      } else {
        if (mounted) setState(() => _error = '기록을 불러오지 못했어요');
      }
    } catch (_) {
      if (mounted) setState(() => _error = '네트워크 연결을 확인해주세요');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreatePostSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateMomentSheet(
        auth: _auth,
        onPostCreated: () {
          Navigator.pop(ctx);
          _loadPosts();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupPostsByDay(_posts);

    return Scaffold(
      backgroundColor: kMainBg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kMainRose))
            : _error != null
            ? _MomentStateMessage(
                icon: Icons.cloud_off_outlined,
                title: _error!,
                actionLabel: '다시 불러오기',
                onAction: _loadPosts,
              )
            : RefreshIndicator(
                color: kMainRose,
                onRefresh: _loadPosts,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _MomentHeader(
                        postCount: _posts.length,
                        photoCount: _posts
                            .where((post) => post['media_type'] == 'image')
                            .length,
                        videoCount: _posts
                            .where((post) => post['media_type'] == 'video')
                            .length,
                        onCreate: _showCreatePostSheet,
                      ),
                    ),
                    if (_posts.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _MomentStateMessage(
                          icon: Icons.auto_stories_outlined,
                          title: '아직 남긴 순간이 없어요',
                          body: '사진 한 장이나 짧은 문장으로 오늘의 분위기를 남겨보세요.',
                          actionLabel: '첫 순간 남기기',
                          onAction: _showCreatePostSheet,
                        ),
                      )
                    else
                      ...grouped.entries.expand(
                        (entry) => [
                          SliverToBoxAdapter(
                            child: _DayDivider(label: entry.key),
                          ),
                          SliverList.separated(
                            itemCount: entry.value.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final post = entry.value[index];
                              return _MomentCard(
                                post: post,
                                auth: _auth,
                                isMine: _isMine(post),
                              );
                            },
                          ),
                        ],
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 96)),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePostSheet,
        backgroundColor: kMainInk,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  bool _isMine(Map<String, dynamic> post) {
    final postUserId = post['user_id'];
    return '$postUserId' == '$_userId';
  }
}

class _MomentHeader extends StatelessWidget {
  final int postCount;
  final int photoCount;
  final int videoCount;
  final VoidCallback onCreate;

  const _MomentHeader({
    required this.postCount,
    required this.photoCount,
    required this.videoCount,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MomentLoop', style: mainTitle(size: 30)),
                    const SizedBox(height: 4),
                    Text(
                      '둘만 남겨두고 싶은 장면들',
                      style: mainBody(size: 13, color: kMainMuted),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: onCreate,
                icon: const Icon(Icons.edit_rounded, size: 19),
                style: IconButton.styleFrom(
                  backgroundColor: kMainInk,
                  foregroundColor: Colors.white,
                  fixedSize: const Size(42, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kMainPaper,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kMainLine.withAlpha(140)),
            ),
            child: Row(
              children: [
                _Metric(label: 'moments', value: '$postCount'),
                _Metric(label: 'photos', value: '$photoCount'),
                _Metric(label: 'videos', value: '$videoCount'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: mainBody(size: 20, color: kMainInk, weight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: mainBody(
              size: 11,
              color: kMainMuted,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  final String label;

  const _DayDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Text(
        label,
        style: mainBody(size: 13, color: kMainInk, weight: FontWeight.w900),
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final AuthService auth;
  final bool isMine;

  const _MomentCard({
    required this.post,
    required this.auth,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final caption = '${post['caption'] ?? ''}'.trim();
    final mediaUrl = '${post['media_url'] ?? ''}'.trim();
    final mediaType = '${post['media_type'] ?? 'text'}';
    final author = _authorName(post, isMine);
    final time = _timeLabel(post['captured_at']);
    final hasMedia = mediaType != 'text' && mediaUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: kMainPaper,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kMainLine.withAlpha(150)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withAlpha(10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
              child: Row(
                children: [
                  _AuthorMark(isMine: isMine, name: author),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          author,
                          style: mainBody(
                            size: 13,
                            color: kMainInk,
                            weight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          time,
                          style: mainBody(size: 11, color: kMainMuted),
                        ),
                      ],
                    ),
                  ),
                  _TypePill(mediaType: mediaType),
                ],
              ),
            ),
            if (hasMedia)
              _MomentMedia(
                url: _mediaUrl(auth.baseUrl, mediaUrl),
                mediaType: mediaType,
              )
            else
              _TextMoment(caption: caption),
            if (caption.isNotEmpty && hasMedia)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 16),
                child: Text(
                  caption,
                  style: mainBody(size: 14, color: kMainInk, height: 1.55),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AuthorMark extends StatelessWidget {
  final bool isMine;
  final String name;

  const _AuthorMark({required this.isMine, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isMine ? kMainRoseSoft : kMainSkySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name.characters.first,
          style: mainBody(
            size: 16,
            color: isMine ? kMainRose : kMainSky,
            weight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String mediaType;

  const _TypePill({required this.mediaType});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (mediaType) {
      'image' => ('photo', Icons.image_outlined, kMainSage),
      'video' => ('video', Icons.play_circle_outline_rounded, kMainPeach),
      _ => ('note', Icons.notes_rounded, kMainLilac),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: mainBody(size: 10.5, color: color, weight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _TextMoment extends StatelessWidget {
  final String caption;

  const _TextMoment({required this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: kMainPaperSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        caption.isEmpty ? '말없이 남긴 순간' : caption,
        style: mainBody(size: 16, color: kMainInk, height: 1.55),
      ),
    );
  }
}

class _MomentMedia extends StatelessWidget {
  final String url;
  final String mediaType;

  const _MomentMedia({required this.url, required this.mediaType});

  @override
  Widget build(BuildContext context) {
    if (mediaType == 'video') return _VideoPostPlayer(url: url);

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: kMainPaperSoft,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, color: kMainMuted),
          ),
        ),
      ),
    );
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
          _controller
            ..setLooping(true)
            ..play();
        })
        .catchError((_) {
          if (mounted) setState(() => _error = '영상을 불러오지 못했어요');
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
      return Container(
        height: 180,
        color: kMainPaperSoft,
        child: Center(
          child: Text(_error!, style: mainBody(color: kMainMuted)),
        ),
      );
    }

    if (!_ready) {
      return Container(
        height: 220,
        color: const Color(0xFF171721),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying
              ? _controller.pause()
              : _controller.play();
        });
      },
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            if (!_controller.value.isPlaying)
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(120),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MomentStateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String actionLabel;
  final VoidCallback onAction;

  const _MomentStateMessage({
    required this.icon,
    required this.title,
    this.body,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: kMainMuted),
            const SizedBox(height: 16),
            Text(
              title,
              style: mainTitle(size: 22),
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                style: mainBody(size: 13, color: kMainMuted),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: kMainInk,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                actionLabel,
                style: mainBody(color: Colors.white, weight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickedMomentMedia {
  final String name;
  final Uint8List bytes;
  final bool isVideo;

  _PickedMomentMedia({
    required this.name,
    required this.bytes,
    required this.isVideo,
  });
}

class _CreateMomentSheet extends StatefulWidget {
  final AuthService auth;
  final VoidCallback onPostCreated;

  const _CreateMomentSheet({required this.auth, required this.onPostCreated});

  @override
  State<_CreateMomentSheet> createState() => _CreateMomentSheetState();
}

class _CreateMomentSheetState extends State<_CreateMomentSheet> {
  final _captionCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  _PickedMomentMedia? _pickedMedia;
  bool _saving = false;

  int? get _userId {
    final value = widget.auth.user?['UserId'] ?? widget.auth.user?['id'];
    if (value is int) return value;
    return int.tryParse('$value');
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(bool isVideo) async {
    try {
      final file = isVideo
          ? await _imagePicker.pickVideo(source: ImageSource.gallery)
          : await _imagePicker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 86,
            );

      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedMedia = _PickedMomentMedia(
          name: file.name,
          bytes: bytes,
          isVideo: isVideo,
        );
      });
    } catch (_) {
      _toast('파일을 불러오지 못했어요');
    }
  }

  Future<void> _saveMoment() async {
    final userId = _userId;
    if (_saving || userId == null) return;

    final caption = _captionCtrl.text.trim();
    if (caption.isEmpty && _pickedMedia == null) {
      _toast('사진이나 글을 입력해주세요');
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();

    try {
      http.Response response;

      if (_pickedMedia == null) {
        response = await http.post(
          Uri.parse('${widget.auth.baseUrl}/api/setlog'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'user_code': widget.auth.user?['UserCode'],
            'media_type': 'text',
            'caption': caption,
            'tags': ['#momentloop'],
            'taken_at': _dateOnly(now),
            'captured_at': _mysqlDateTime(now),
          }),
        );
      } else {
        final media = _pickedMedia!;
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${widget.auth.baseUrl}/api/setlog'),
        );
        request.fields.addAll({
          'user_id': '$userId',
          'user_code': '${widget.auth.user?['UserCode'] ?? ''}',
          'caption': caption,
          'tags': jsonEncode(['#momentloop']),
          'taken_at': _dateOnly(now),
          'captured_at': _mysqlDateTime(now),
        });
        request.files.add(
          http.MultipartFile.fromBytes(
            'media',
            media.bytes,
            filename: media.name,
            contentType: MediaType.parse(_mimeFor(media.name, media.isVideo)),
          ),
        );
        response = await http.Response.fromStream(await request.send());
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['ok'] == true) {
        widget.onPostCreated();
      } else {
        _toast('저장하지 못했어요');
      }
    } catch (_) {
      _toast('네트워크 연결을 확인해주세요');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: mainBody(color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: kMainPaper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kMainLine,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text('순간 남기기', style: mainTitle(size: 24))),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text('닫기', style: mainBody(color: kMainMuted)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _captionCtrl,
              minLines: 4,
              maxLines: 8,
              style: mainBody(size: 15, color: kMainInk, height: 1.5),
              decoration: InputDecoration(
                hintText: '오늘 남기고 싶은 장면을 적어주세요',
                hintStyle: mainBody(size: 15, color: kMainMuted),
                filled: true,
                fillColor: kMainPaperSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            if (_pickedMedia != null) ...[
              const SizedBox(height: 14),
              _PickedPreview(
                media: _pickedMedia!,
                onRemove: () => setState(() => _pickedMedia = null),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                _SheetToolButton(
                  icon: Icons.image_outlined,
                  label: '사진',
                  onTap: () => _pickMedia(false),
                ),
                const SizedBox(width: 8),
                _SheetToolButton(
                  icon: Icons.play_circle_outline_rounded,
                  label: '영상',
                  onTap: () => _pickMedia(true),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _saveMoment,
                  style: FilledButton.styleFrom(
                    backgroundColor: kMainInk,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          '저장',
                          style: mainBody(
                            color: Colors.white,
                            weight: FontWeight.w900,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PickedPreview extends StatelessWidget {
  final _PickedMomentMedia media;
  final VoidCallback onRemove;

  const _PickedPreview({required this.media, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 180,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: kMainPaperSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kMainLine),
          ),
          child: media.isVideo
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_circle_outline_rounded,
                        color: kMainPeach,
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        media.name,
                        style: mainBody(size: 12, color: kMainMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )
              : Image.memory(media.bytes, fit: BoxFit.cover),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton.filled(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 16),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withAlpha(120),
              foregroundColor: Colors.white,
              fixedSize: const Size(32, 32),
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: kMainInk,
        backgroundColor: kMainPaperSoft,
        side: const BorderSide(color: kMainLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

Map<String, List<Map<String, dynamic>>> _groupPostsByDay(
  List<Map<String, dynamic>> posts,
) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final post in posts) {
    final label = _dayLabel(post['captured_at'] ?? post['taken_at']);
    grouped.putIfAbsent(label, () => []).add(post);
  }
  return grouped;
}

String _authorName(Map<String, dynamic> post, bool isMine) {
  if (isMine) return '나';
  return '${post['Nickname'] ?? post['nickname'] ?? post['UserName'] ?? post['userName'] ?? '상대'}';
}

String _dayLabel(dynamic value) {
  final date = DateTime.tryParse('${value ?? ''}')?.toLocal();
  if (date == null) return '날짜 없는 순간';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;

  if (diff == 0) return '오늘';
  if (diff == 1) return '어제';
  return '${date.month}월 ${date.day}일';
}

String _timeLabel(dynamic value) {
  final date = DateTime.tryParse('${value ?? ''}')?.toLocal();
  if (date == null) return '';

  final hour = date.hour > 12
      ? date.hour - 12
      : (date.hour == 0 ? 12 : date.hour);
  final ampm = date.hour >= 12 ? '오후' : '오전';
  final minute = date.minute.toString().padLeft(2, '0');
  return '$ampm $hour:$minute';
}

String _mediaUrl(String baseUrl, String mediaUrl) {
  if (mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://')) {
    return mediaUrl;
  }
  return '$baseUrl$mediaUrl';
}

String _dateOnly(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _mysqlDateTime(DateTime value) {
  return '${_dateOnly(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
}

String _mimeFor(String name, bool isVideo) {
  final ext = name.split('.').last.toLowerCase();
  const mimeMap = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'm4v': 'video/mp4',
  };
  return mimeMap[ext] ?? (isVideo ? 'video/mp4' : 'image/jpeg');
}
