import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/auth_service.dart';
import '../../core/main_design.dart';
import 'map_screen.dart';

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
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${_auth.token}'},
      );
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

  Future<void> _startCreatePostFlow() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CreateMomentPage(auth: _auth, initialMedia: const []),
      ),
    );
    if (created == true) _loadPosts();
  }

  Future<void> _editPost(Map<String, dynamic> post) async {
    final controller = TextEditingController(text: '${post['caption'] ?? ''}');
    final caption = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('MomentLoop 수정'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: '남길 말'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (caption == null || caption.isEmpty) return;
    final response = await http.patch(
      Uri.parse('${_auth.baseUrl}/api/setlog/${post['id']}'),
      headers: {
        'Authorization': 'Bearer ${_auth.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'caption': caption}),
    );
    if (response.statusCode == 200) await _loadPosts();
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('MomentLoop 삭제'),
        content: const Text('이 기록과 첨부한 사진을 영구 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final response = await http.delete(
      Uri.parse('${_auth.baseUrl}/api/setlog/${post['id']}'),
      headers: {'Authorization': 'Bearer ${_auth.token}'},
    );
    if (response.statusCode == 200) await _loadPosts();
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
                        onCreate: _startCreatePostFlow,
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
                          onAction: _startCreatePostFlow,
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
                                onEdit: () => _editPost(post),
                                onDelete: () => _deletePost(post),
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
        onPressed: _startCreatePostFlow,
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
              IconButton.filled(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
                style: IconButton.styleFrom(
                  backgroundColor: kMainPaper,
                  foregroundColor: kMainInk,
                  fixedSize: const Size(42, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: kMainLine),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MomentCard({
    required this.post,
    required this.auth,
    required this.isMine,
    required this.onEdit,
    required this.onDelete,
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
                  if (isMine)
                    PopupMenuButton<String>(
                      tooltip: '기록 관리',
                      onSelected: (value) =>
                          value == 'edit' ? onEdit() : onDelete(),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('수정')),
                        PopupMenuItem(value: 'delete', child: Text('삭제')),
                      ],
                    ),
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

class _SelectedMapLocation {
  final int? id;
  final String name;
  final String? category;

  const _SelectedMapLocation({
    required this.id,
    required this.name,
    this.category,
  });

  bool get isNew => id == null;
}

class _MapLocationPickerResult {
  final _SelectedMapLocation? location;
  final bool openMap;

  const _MapLocationPickerResult.location(this.location) : openMap = false;
  const _MapLocationPickerResult.openMap() : location = null, openMap = true;
}

class _CreateMomentPage extends StatefulWidget {
  final AuthService auth;
  final List<_PickedMomentMedia> initialMedia;

  const _CreateMomentPage({required this.auth, required this.initialMedia});

  @override
  State<_CreateMomentPage> createState() => _CreateMomentPageState();
}

class _CreateMomentPageState extends State<_CreateMomentPage> {
  final _captionCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  late final List<_PickedMomentMedia> _pickedMedia;
  List<Map<String, dynamic>> _mapPins = [];
  _SelectedMapLocation? _selectedLocation;
  bool _saving = false;
  bool _loadingLocations = false;

  int? get _userId {
    final value = widget.auth.user?['UserId'] ?? widget.auth.user?['id'];
    if (value is int) return value;
    return int.tryParse('$value');
  }

  Map<String, String> _jsonHeaders({bool includeAuth = false}) {
    return {
      'Content-Type': 'application/json',
      if (includeAuth && widget.auth.token != null)
        'Authorization': 'Bearer ${widget.auth.token}',
    };
  }

  @override
  void initState() {
    super.initState();
    _pickedMedia = List<_PickedMomentMedia>.of(widget.initialMedia);
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    try {
      final files = await _imagePicker.pickMultiImage(imageQuality: 86);
      if (files.isEmpty) return;

      final media = <_PickedMomentMedia>[];
      for (final file in files) {
        media.add(
          _PickedMomentMedia(
            name: file.name,
            bytes: await file.readAsBytes(),
            isVideo: false,
          ),
        );
      }

      if (!mounted) return;
      setState(() => _pickedMedia.addAll(media));
    } catch (_) {
      _toast('사진을 불러오지 못했어요');
    }
  }

  Future<void> _loadMapPins() async {
    final userId = _userId;
    if (userId == null || _loadingLocations) return;

    setState(() => _loadingLocations = true);
    try {
      final uri = Uri.parse(
        '${widget.auth.baseUrl}/api/map',
      ).replace(queryParameters: {'user_id': '$userId'});
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.auth.token}'},
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['ok'] == true) {
        final pins = data['pins'];
        if (!mounted) return;
        setState(() {
          _mapPins = pins is List
              ? pins
                    .map((pin) => Map<String, dynamic>.from(pin as Map))
                    .toList()
              : [];
        });
      }
    } catch (_) {
      _toast('비밀지도 위치를 불러오지 못했어요');
    } finally {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  Future<void> _pickLocation() async {
    await _loadMapPins();
    if (!mounted) return;

    final picked = await showModalBottomSheet<_MapLocationPickerResult?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MapLocationPickerSheet(
        pins: _mapPins,
        selected: _selectedLocation,
        loading: _loadingLocations,
      ),
    );

    if (!mounted || picked == null) return;
    if (picked.openMap) {
      await _openSecretMapForLocationAdd();
      if (!mounted) return;
      await _loadMapPins();
      if (!mounted) return;
      await _pickLocation();
      return;
    }

    final location = picked.location;
    if (location != null) {
      setState(() => _selectedLocation = location);
    }
  }

  Future<void> _openSecretMapForLocationAdd() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const MapScreen(closeAsModal: true),
      ),
    );
  }

  Future<int?> _ensureMapPinId({
    required _SelectedMapLocation location,
    required String caption,
    required DateTime now,
  }) async {
    if (!location.isNew) return location.id;

    final userId = _userId;
    final userCode =
        widget.auth.user?['UserCode'] ?? widget.auth.user?['userCode'];
    if (userId == null || userCode == null) return null;

    final response = await http.post(
      Uri.parse('${widget.auth.baseUrl}/api/map'),
      headers: _jsonHeaders(includeAuth: true),
      body: jsonEncode({
        'place_name': location.name,
        'category': location.category ?? 'MomentLoop',
        'rating': null,
        'visit_date': _dateOnly(now),
        'memo': caption,
        'created_by': userCode,
        'user_id': userId,
        'latitude': 0,
        'longitude': 0,
        'status': 'visited',
        'emotion_tags': <String>[],
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['ok'] != true) return null;
    return int.tryParse('${data['id']}');
  }

  Future<void> _saveMoment() async {
    final userId = _userId;
    if (_saving || userId == null) return;

    final caption = _captionCtrl.text.trim();
    if (caption.isEmpty) {
      _toast('오늘 남기고 싶은 장면을 적어주세요');
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();

    try {
      final location = _selectedLocation;
      final mapPinId = location == null
          ? null
          : await _ensureMapPinId(
              location: location,
              caption: caption,
              now: now,
            );
      if (location != null && mapPinId == null) {
        _toast('비밀지도 위치를 연결하지 못했어요');
        return;
      }

      final mediaItems = _pickedMedia.isEmpty
          ? <_PickedMomentMedia?>[null]
          : _pickedMedia.map<_PickedMomentMedia?>((media) => media).toList();
      for (final media in mediaItems) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${widget.auth.baseUrl}/api/setlog'),
        );
        request.headers['Authorization'] = 'Bearer ${widget.auth.token}';
        request.fields.addAll({
          'caption': caption,
          'tags': jsonEncode(['#momentloop']),
          'taken_at': _dateOnly(now),
          'captured_at': _mysqlDateTime(now),
          if (mapPinId != null) 'map_pin_id': '$mapPinId',
        });
        if (media != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'media',
              media.bytes,
              filename: media.name,
              contentType: MediaType.parse(_mimeFor(media.name, media.isVideo)),
            ),
          );
        }
        final response = await http.Response.fromStream(await request.send());
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (response.statusCode != 201 || data['ok'] != true) {
          _toast('저장하지 못했어요');
          return;
        }
      }

      if (mounted) Navigator.pop(context, true);
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
    return Scaffold(
      backgroundColor: kMainPaper,
      appBar: AppBar(
        backgroundColor: kMainPaper,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: kMainInk,
          tooltip: '뒤로가기',
        ),
        centerTitle: true,
        title: Text(
          '새 게시물',
          style: mainBody(size: 17, weight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                children: [
                  _PickedMediaStrip(
                    media: _pickedMedia,
                    onAdd: _saving ? null : _addPhotos,
                    onRemove: _saving
                        ? null
                        : (index) =>
                              setState(() => _pickedMedia.removeAt(index)),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _captionCtrl,
                    minLines: 5,
                    maxLines: 10,
                    textInputAction: TextInputAction.newline,
                    style: mainBody(size: 16, color: kMainInk, height: 1.55),
                    decoration: InputDecoration(
                      hintText: '오늘 남기고 싶은 장면을 적어주세요',
                      hintStyle: mainBody(size: 16, color: kMainMuted),
                      filled: true,
                      fillColor: kMainPaperSoft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(18),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _LocationAddButton(
                    location: _selectedLocation,
                    loading: _loadingLocations,
                    onTap: _saving ? null : _pickLocation,
                    onClear: _saving
                        ? null
                        : () => setState(() => _selectedLocation = null),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                10,
                18,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _saveMoment,
                  style: FilledButton.styleFrom(
                    backgroundColor: kMainInk,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          '공유하기',
                          style: mainBody(
                            color: Colors.white,
                            size: 16,
                            weight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickedMediaStrip extends StatelessWidget {
  final List<_PickedMomentMedia> media;
  final VoidCallback? onAdd;
  final ValueChanged<int>? onRemove;

  const _PickedMediaStrip({
    required this.media,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 152,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == media.length) {
            return _AddPhotoTile(onTap: onAdd);
          }

          return _PickedPhotoTile(
            media: media[index],
            label: '#${index + 1}',
            onRemove: onRemove == null ? null : () => onRemove!(index),
          );
        },
      ),
    );
  }
}

class _PickedPhotoTile extends StatelessWidget {
  final _PickedMomentMedia media;
  final String label;
  final VoidCallback? onRemove;

  const _PickedPhotoTile({
    required this.media,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 138,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: kMainPaperSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kMainLine),
              ),
              child: Image.memory(media.bytes, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(135),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                label,
                style: mainBody(
                  size: 12,
                  color: Colors.white,
                  weight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Positioned(
            top: 7,
            right: 7,
            child: IconButton.filled(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 16),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withAlpha(125),
                foregroundColor: Colors.white,
                fixedSize: const Size(30, 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddPhotoTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 138,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: kMainInk,
          backgroundColor: kMainPaperSoft,
          side: const BorderSide(color: kMainLine),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_photo_alternate_outlined, size: 30),
            const SizedBox(height: 8),
            Text('사진 추가', style: mainBody(size: 13, weight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _LocationAddButton extends StatelessWidget {
  final _SelectedMapLocation? location;
  final bool loading;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const _LocationAddButton({
    required this.location,
    required this.loading,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final selected = location;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: kMainPaperSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kMainLine),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, color: kMainInk, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected?.name ?? '위치 추가',
                    style: mainBody(
                      size: 15,
                      color: kMainInk,
                      weight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (selected != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      selected.isNew ? '비밀지도에 새 위치로 저장돼요' : '비밀지도와 연결돼요',
                      style: mainBody(size: 12, color: kMainMuted),
                    ),
                  ],
                ],
              ),
            ),
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (selected != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: kMainMuted,
                tooltip: '위치 제거',
                style: IconButton.styleFrom(
                  fixedSize: const Size(34, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: kMainMuted),
          ],
        ),
      ),
    );
  }
}

class _MapLocationPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> pins;
  final _SelectedMapLocation? selected;
  final bool loading;

  const _MapLocationPickerSheet({
    required this.pins,
    required this.selected,
    required this.loading,
  });

  @override
  State<_MapLocationPickerSheet> createState() =>
      _MapLocationPickerSheetState();
}

class _MapLocationPickerSheetState extends State<_MapLocationPickerSheet> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredPins {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return widget.pins;
    return widget.pins.where((pin) {
      final name = '${pin['place_name'] ?? ''}'.toLowerCase();
      final category = '${pin['category'] ?? ''}'.toLowerCase();
      return name.contains(query) || category.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final pins = _filteredPins;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: kMainPaper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(18, 12, 18, bottom + 18),
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
          Text('비밀지도 위치', style: mainTitle(size: 22)),
          const SizedBox(height: 6),
          Text(
            '이미 등록한 위치를 검색하거나 비밀지도에서 새로 추가하세요.',
            style: mainBody(size: 13, color: kMainMuted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  style: mainBody(size: 15, color: kMainInk),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '등록한 위치 검색',
                    hintStyle: mainBody(size: 14, color: kMainMuted),
                    filled: true,
                    fillColor: kMainPaperSoft,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                            tooltip: '검색 지우기',
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: () => Navigator.pop(
                  context,
                  const _MapLocationPickerResult.openMap(),
                ),
                icon: const Icon(Icons.add_location_alt_outlined),
                tooltip: '비밀지도에서 추가',
                style: IconButton.styleFrom(
                  backgroundColor: kMainInk,
                  foregroundColor: Colors.white,
                  fixedSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Flexible(
            child: widget.loading
                ? const Center(child: CircularProgressIndicator())
                : pins.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.map_outlined,
                            color: kMainMuted,
                            size: 34,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.pins.isEmpty
                                ? '비밀지도에 저장된 위치가 없어요'
                                : '검색 결과가 없어요',
                            style: mainBody(size: 14, color: kMainMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: pins.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final pin = pins[index];
                      final id = int.tryParse('${pin['id']}');
                      final name = '${pin['place_name'] ?? '이름 없는 위치'}';
                      final category = '${pin['category'] ?? '비밀지도'}';
                      final selected = widget.selected?.id == id;

                      return _MapLocationTile(
                        name: name,
                        category: category,
                        selected: selected,
                        onTap: () => Navigator.pop(
                          context,
                          _MapLocationPickerResult.location(
                            _SelectedMapLocation(
                              id: id,
                              name: name,
                              category: category,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MapLocationTile extends StatelessWidget {
  final String name;
  final String category;
  final bool selected;
  final VoidCallback onTap;

  const _MapLocationTile({
    required this.name,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? kMainRoseSoft : kMainPaperSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? kMainRose : kMainLine),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.place_outlined,
              color: selected ? kMainRose : kMainInk,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: mainBody(
                      size: 15,
                      color: kMainInk,
                      weight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category,
                    style: mainBody(size: 12, color: kMainMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
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
