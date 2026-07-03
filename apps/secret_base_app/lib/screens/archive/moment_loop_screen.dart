import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/auth_service.dart';
import '../../core/main_design.dart';

// ──────────────────────────────────────────────────────────────────────────────
// MomentLoop Screen (Couple Timeline Style)
// ──────────────────────────────────────────────────────────────────────────────

class MomentLoopScreen extends StatefulWidget {
  const MomentLoopScreen({super.key});

  @override
  State<MomentLoopScreen> createState() => _MomentLoopScreenState();
}

class _MomentLoopScreenState extends State<MomentLoopScreen> with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;

  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fabAnimation = CurvedAnimation(parent: _fabController, curve: Curves.easeOutBack);
    _fabController.forward();
    _loadPosts();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  int? get _userId {
    final value = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (value is int) return value;
    return int.tryParse('$value');
  }

  Future<void> _loadPosts() async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) setState(() { _loading = false; _error = '로그인 정보가 없어요'; });
      return;
    }

    if (mounted) setState(() { _loading = true; _error = null; });

    try {
      final uri = Uri.parse('${_auth.baseUrl}/api/setlog').replace(queryParameters: {'user_id': '$userId'});
      final response = await http.get(uri);
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['ok'] == true) {
        final posts = data['posts'];
        if (mounted) {
          setState(() {
            _posts = posts is List ? posts.map((item) => Map<String, dynamic>.from(item as Map)).toList() : [];
            // Sort by captured_at descending
            _posts.sort((a, b) {
              final dateA = DateTime.tryParse(a['captured_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
              final dateB = DateTime.tryParse(b['captured_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
              return dateB.compareTo(dateA); // newest first
            });
          });
        }
      } else {
        if (mounted) setState(() => _error = '기록을 불러오지 못했어요');
      }
    } catch (e) {
      if (mounted) setState(() => _error = '네트워크 연결을 확인해주세요');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreatePostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreatePostSheet(
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
    return Scaffold(
      backgroundColor: kMainBg, // 따뜻한 베이지 배경
      appBar: AppBar(
        backgroundColor: kMainBg,
        elevation: 0,
        centerTitle: true,
        title: Text('우리의 타임라인', style: mainTitle(size: 20, color: kMainInk)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainRose))
          : _error != null
              ? Center(child: Text(_error!, style: mainBody(color: kMainMuted)))
              : _posts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timeline_rounded, size: 64, color: kMainLine),
                          const SizedBox(height: 16),
                          Text('아직 기록이 없어요.', style: mainTitle(size: 18)),
                          const SizedBox(height: 8),
                          Text('오늘의 첫 순간을 기록해보세요!', style: mainBody(size: 14, color: kMainSub)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: kMainRose,
                      onRefresh: _loadPosts,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 20, bottom: 80),
                        itemCount: _posts.length,
                        itemBuilder: (ctx, i) {
                          final post = _posts[i];
                          final isMe = post['user_id'] == _userId;
                          // If last item, don't draw the line below
                          final isLast = i == _posts.length - 1;
                          
                          // Check if date changed from previous item to show Date Header
                          bool showDateHeader = false;
                          String currentDateStr = '';
                          if (post['captured_at'] != null) {
                            final date = DateTime.tryParse(post['captured_at'])?.toLocal();
                            if (date != null) {
                              currentDateStr = '${date.year}년 ${date.month}월 ${date.day}일';
                              if (i == 0) {
                                showDateHeader = true;
                              } else {
                                final prevDate = DateTime.tryParse(_posts[i - 1]['captured_at'])?.toLocal();
                                if (prevDate != null) {
                                  final prevDateStr = '${prevDate.year}년 ${prevDate.month}월 ${prevDate.day}일';
                                  if (currentDateStr != prevDateStr) showDateHeader = true;
                                }
                              }
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showDateHeader)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: kMainLine.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(currentDateStr, style: mainBody(size: 12, color: kMainInk, weight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                              _TimelineItem(
                                post: post,
                                isMe: isMe,
                                isLast: isLast,
                                auth: _auth,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: _showCreatePostSheet,
          backgroundColor: kMainRose,
          elevation: 4,
          icon: const Icon(Icons.edit_calendar_rounded, color: Colors.white),
          label: Text('기록하기', style: mainBody(size: 15, color: Colors.white, weight: FontWeight.bold)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Timeline Item Widget
// ──────────────────────────────────────────────────────────────────────────────

class _TimelineItem extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isMe;
  final bool isLast;
  final AuthService auth;

  const _TimelineItem({
    required this.post,
    required this.isMe,
    required this.isLast,
    required this.auth,
  });

  @override
  State<_TimelineItem> createState() => _TimelineItemState();
}

class _TimelineItemState extends State<_TimelineItem> {
  bool _showCommentInput = false;
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.post['caption'] as String? ?? '';
    final mediaUrl = widget.post['media_url'] as String?;
    final mediaType = widget.post['media_type'] as String? ?? 'text';
    final userNick = widget.post['nickname'] as String? ?? '유저';
    
    // Parse time
    String timeStr = '';
    if (widget.post['captured_at'] != null) {
      final date = DateTime.tryParse(widget.post['captured_at'])?.toLocal();
      if (date != null) {
        final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
        final ampm = date.hour >= 12 ? '오후' : '오전';
        final minute = date.minute.toString().padLeft(2, '0');
        timeStr = '$ampm $hour:$minute';
      }
    }

    // 커플 테마 색상 (나는 핑크 계열, 상대는 블루/그린 계열)
    final bubbleColor = widget.isMe ? kMainRoseSoft : const Color(0xFFE8F0F2);
    final dotColor = widget.isMe ? kMainRose : const Color(0xFF6B9AC4);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left side (Timeline line and dot)
          SizedBox(
            width: 60,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!widget.isLast)
                  Positioned(
                    top: 24,
                    bottom: 0,
                    child: Container(width: 2, color: kMainLine),
                  ),
                Positioned(
                  top: 16,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: kMainBg, width: 3),
                      boxShadow: [BoxShadow(color: dotColor.withValues(alpha: 0.4), blurRadius: 4)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Right side (Content)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 20, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time and Author
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Text(timeStr, style: mainBody(size: 12, color: kMainMuted, weight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text(userNick, style: mainBody(size: 13, color: kMainInk, weight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  
                  // Content Bubble
                  Container(
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(2),
                        topRight: const Radius.circular(16),
                        bottomLeft: const Radius.circular(16),
                        bottomRight: const Radius.circular(16),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (mediaType != 'text' && mediaUrl != null && mediaUrl.isNotEmpty)
                          _MediaContent(mediaUrl: '${widget.auth.baseUrl}$mediaUrl', mediaType: mediaType),
                        
                        if (caption.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(caption, style: mainBody(size: 14, color: kMainInk, height: 1.5)),
                          ),
                      ],
                    ),
                  ),

                  // Comment Button / Action
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _showCommentInput = !_showCommentInput),
                        child: Row(
                          children: [
                            const Icon(Icons.reply_rounded, size: 16, color: kMainMuted),
                            const SizedBox(width: 4),
                            Text('답글 달기', style: mainBody(size: 12, color: kMainMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Comment Input
                  if (_showCommentInput)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: kMainLine),
                              ),
                              child: TextField(
                                controller: _commentCtrl,
                                style: mainBody(size: 13),
                                decoration: InputDecoration(
                                  hintText: '메시지를 입력하세요...',
                                  hintStyle: mainBody(size: 13, color: kMainMuted),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              if (_commentCtrl.text.isNotEmpty) {
                                // 임시 UI 피드백 (실제 댓글 API 연동 시 수정)
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('답글이 달렸습니다! (준비 중)')));
                                setState(() {
                                  _showCommentInput = false;
                                  _commentCtrl.clear();
                                });
                              }
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(color: kMainRose, shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Media Content (Same as before)
// ──────────────────────────────────────────────────────────────────────────────

class _MediaContent extends StatelessWidget {
  final String mediaUrl;
  final String mediaType;

  const _MediaContent({required this.mediaUrl, required this.mediaType});

  @override
  Widget build(BuildContext context) {
    if (mediaType == 'image') {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 300),
        child: Image.network(
          mediaUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 150,
            color: kMainPaper,
            child: const Center(child: Icon(Icons.broken_image_rounded, color: kMainMuted)),
          ),
        ),
      );
    }
    return _VideoPostPlayer(url: mediaUrl);
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
    _controller.initialize().then((_) {
      if (mounted) setState(() => _ready = true);
      _controller.play();
      _controller.setLooping(true);
    }).catchError((_) {
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
        height: 150,
        color: kMainPaper,
        child: Center(child: Text(_error!, style: mainBody(color: kMainMuted))),
      );
    }
    if (!_ready) {
      return Container(
        height: 200,
        color: Colors.black12,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying ? _controller.pause() : _controller.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          if (!_controller.value.isPlaying)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Create Post Bottom Sheet
// ──────────────────────────────────────────────────────────────────────────────

class _PickedMomentMedia {
  final String name;
  final Uint8List bytes;
  _PickedMomentMedia({required this.name, required this.bytes});
}

class _CreatePostSheet extends StatefulWidget {
  final AuthService auth;
  final VoidCallback onPostCreated;

  const _CreatePostSheet({required this.auth, required this.onPostCreated});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _captionCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  _PickedMomentMedia? _pickedMedia;
  bool _saving = false;

  int? get _userId {
    final value = widget.auth.user?['UserId'] ?? widget.auth.user?['id'];
    if (value is int) return value;
    return int.tryParse('$value');
  }

  Future<void> _pickMedia(bool isVideo) async {
    try {
      final XFile? file = isVideo 
          ? await _imagePicker.pickVideo(source: ImageSource.gallery)
          : await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);

      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _pickedMedia = _PickedMomentMedia(name: file.name, bytes: bytes);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveMoment() async {
    final userId = _userId;
    if (_saving || userId == null) return;

    final caption = _captionCtrl.text.trim();
    if (caption.isEmpty && _pickedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사진이나 글을 입력해주세요!')));
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();

    String dateOnly(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    String mysqlDateTime(DateTime value) => '${dateOnly(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

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
            'taken_at': dateOnly(now),
            'captured_at': mysqlDateTime(now),
          }),
        );
      } else {
        final request = http.MultipartRequest('POST', Uri.parse('${widget.auth.baseUrl}/api/setlog'));
        request.fields.addAll({
          'user_id': '$userId',
          'user_code': '${widget.auth.user?['UserCode'] ?? ''}',
          'caption': caption,
          'tags': jsonEncode(['#momentloop']),
          'taken_at': dateOnly(now),
          'captured_at': mysqlDateTime(now),
        });

        final media = _pickedMedia!;
        final ext = media.name.split('.').last.toLowerCase();
        
        const mimeMap = {
          'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'gif': 'image/gif',
          'mp4': 'video/mp4', 'mov': 'video/quicktime',
        };
        final mime = mimeMap[ext] ?? 'image/jpeg';

        request.files.add(http.MultipartFile.fromBytes('media', media.bytes, filename: media.name, contentType: MediaType.parse(mime)));

        final streamed = await request.send();
        response = await http.Response.fromStream(streamed);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['ok'] == true) {
        widget.onPostCreated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('업로드에 실패했어요')));
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('네트워크 오류가 발생했습니다')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('취소', style: mainBody(size: 16, color: kMainInk)),
                ),
                Text('지금 이 순간 기록', style: mainTitle(size: 16, color: kMainInk)),
                TextButton(
                  onPressed: _saving ? null : _saveMoment,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('저장', style: mainBody(size: 16, color: kMainRose, weight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: kMainRoseSoft,
                  child: const Icon(Icons.person, color: kMainRose, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _captionCtrl,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: '지금 무슨 일이 있었나요?',
                      hintStyle: mainBody(size: 14, color: kMainMuted),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_pickedMedia != null)
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: kMainPaper,
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: MemoryImage(_pickedMedia!.bytes),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _pickedMedia = null),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Media Select Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_library_outlined, color: Colors.green),
                  onPressed: () => _pickMedia(false),
                  tooltip: '사진 첨부',
                ),
                IconButton(
                  icon: const Icon(Icons.videocam_outlined, color: Colors.redAccent),
                  onPressed: () => _pickMedia(true),
                  tooltip: '동영상 첨부',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
