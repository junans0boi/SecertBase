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

// ── Screen ────────────────────────────────────────────────────────────────────

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
  late DateTime _weekStart;
  final Set<String> _seenSessionIds = {};

  int? get _userId {
    final value = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (value is int) return value;
    return int.tryParse('$value');
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = _mondayOf(now);
    _loadPosts();
  }

  static DateTime _mondayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  bool get _isCurrentWeek {
    final now = _mondayOf(DateTime.now());
    return _weekStart.isAtSameMomentAs(now);
  }

  List<List<Map<String, dynamic>>> get _groups {
    final groupMap = <String, List<Map<String, dynamic>>>{};
    for (final post in _posts) {
      final sid = '${post['session_id'] ?? ''}'.trim();
      final key = sid.isNotEmpty
          ? sid
          : 'solo_${post['id']}'; // fallback: each old post is its own group
      groupMap.putIfAbsent(key, () => []).add(post);
    }
    final groups = groupMap.values.map((g) {
      g.sort((a, b) => (a['id'] as int? ?? 0).compareTo(b['id'] as int? ?? 0));
      return g;
    }).toList();
    groups.sort((a, b) {
      final da = DateTime.tryParse('${a.first['captured_at'] ?? ''}') ?? DateTime(0);
      final db = DateTime.tryParse('${b.first['captured_at'] ?? ''}') ?? DateTime(0);
      return db.compareTo(da);
    });
    return groups;
  }

  String _sessionKeyOf(List<Map<String, dynamic>> group) {
    final sid = '${group.first['session_id'] ?? ''}'.trim();
    return sid.isNotEmpty ? sid : 'solo_${group.first['id']}';
  }

  Map<String, List<List<Map<String, dynamic>>>> get _groupsByDate {
    final map = <String, List<List<Map<String, dynamic>>>>{};
    for (final group in _groups) {
      final key = _dateKey(group.first['captured_at'] ?? group.first['taken_at']);
      map.putIfAbsent(key, () => []).add(group);
    }
    return map;
  }

  Future<void> _loadPosts() async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) setState(() { _loading = false; _error = '로그인 정보가 없어요'; });
      return;
    }
    if (mounted) setState(() { _loading = true; _error = null; });

    try {
      final uri = Uri.parse('${_auth.baseUrl}/api/setlog')
          .replace(queryParameters: {'user_id': '$userId'});
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
              ? posts.map((item) => Map<String, dynamic>.from(item as Map)).toList()
              : [];
          _posts.sort((a, b) {
            final da = DateTime.tryParse('${a['captured_at'] ?? ''}') ?? DateTime(0);
            final db = DateTime.tryParse('${b['captured_at'] ?? ''}') ?? DateTime(0);
            return db.compareTo(da);
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
        title: const Text('순간 수정'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: '남길 말'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
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
        title: const Text('삭제할까요?'),
        content: const Text('이 순간과 사진을 영구 삭제해요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
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

  String _myNickname() {
    final u = _auth.user;
    return '${u?['Nickname'] ?? u?['nickname'] ?? u?['UserName'] ?? u?['userName'] ?? '나'}';
  }

  void _openStoryViewer(List<List<Map<String, dynamic>>> groups, int startGroupIndex) {
    if (groups.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => _StoryViewer(
          groups: groups,
          startGroupIndex: startGroupIndex,
          auth: _auth,
          myUserId: _userId,
          myNickname: _myNickname(),
          seenSessionIds: _seenSessionIds,
          onSeen: (sessionKey) {
            if (mounted) setState(() => _seenSessionIds.add(sessionKey));
          },
        ),
      ),
    );
  }

  Future<void> _pickWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekStart,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: '주를 선택하세요',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: kMainRose,
            onPrimary: Colors.white,
            surface: kMainPaper,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _weekStart = _mondayOf(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      floatingActionButton: FloatingActionButton(
        onPressed: _startCreatePostFlow,
        backgroundColor: kMainRose,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: kMainSub),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MomentLoop', style: mainTitle(size: 24)),
                        Text('우리 둘의 날짜별 기록', style: mainBody(size: 12, color: kMainMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Story highlights ─────────────────────────────────────────────
            if (_posts.isNotEmpty)
              _HighlightStrip(
                groups: _groups,
                auth: _auth,
                myUserId: _userId,
                seenSessionIds: _seenSessionIds,
                sessionKeyOf: _sessionKeyOf,
                onTap: (idx) => _openStoryViewer(_groups, idx),
              ),

            if (_posts.isNotEmpty) const SizedBox(height: 12),

            // ── Week navigator ───────────────────────────────────────────────
            _WeekNavigator(
              weekStart: _weekStart,
              isCurrentWeek: _isCurrentWeek,
              onPrev: () => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7))),
              onNext: _isCurrentWeek
                  ? null
                  : () => setState(() => _weekStart = _weekStart.add(const Duration(days: 7))),
              onPickWeek: _pickWeek,
            ),

            const SizedBox(height: 4),

            // ── Day list ─────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: kMainRose))
                  : _error != null
                  ? _ErrorState(message: _error!, onRetry: _loadPosts)
                  : RefreshIndicator(
                      color: kMainRose,
                      onRefresh: _loadPosts,
                      child: _buildWeekContent(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekContent() {
    final byDate = _groupsByDate;
    final daysWithGroups = _weekDays
        .where((d) => (byDate[_dateKey(d.toIso8601String())] ?? []).isNotEmpty)
        .toList();

    if (daysWithGroups.isEmpty) {
      return _WeekEmptyState(isCurrentWeek: _isCurrentWeek, onRefresh: _loadPosts);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
      itemCount: daysWithGroups.length,
      itemBuilder: (context, i) {
        final day = daysWithGroups[i];
        final dayGroups = byDate[_dateKey(day.toIso8601String())]!;
        return _DaySection(
          day: day,
          groups: dayGroups,
          auth: _auth,
          myUserId: _userId,
          onTap: (group) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _PostDetailPage(
                group: group,
                auth: _auth,
                myUserId: _userId,
                onEdit: _editPost,
                onDelete: _deletePost,
                onReactionUpdate: (sessionId, reactions) {
                  if (!mounted) return;
                  setState(() {
                    for (final post in _posts) {
                      if ('${post['session_id']}' == sessionId) {
                        post['session_reactions'] = reactions;
                      }
                    }
                  });
                },
              ),
            ));
          },
        );
      },
    );
  }
}

// ── Highlight Strip (Story Circles) ──────────────────────────────────────────

class _HighlightStrip extends StatelessWidget {
  final List<List<Map<String, dynamic>>> groups;
  final AuthService auth;
  final int? myUserId;
  final Set<String> seenSessionIds;
  final String Function(List<Map<String, dynamic>>) sessionKeyOf;
  final ValueChanged<int> onTap;

  const _HighlightStrip({
    required this.groups,
    required this.auth,
    required this.myUserId,
    required this.seenSessionIds,
    required this.sessionKeyOf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: groups.length,
        itemBuilder: (context, i) {
          final group = groups[i];
          final first = group.first;
          final sessionKey = sessionKeyOf(group);
          final seen = seenSessionIds.contains(sessionKey);
          final isMine = '${first['user_id']}' == '$myUserId';
          // Representative thumbnail: first media item in group
          final thumbPost = group.firstWhere(
            (p) => '${p['media_url'] ?? ''}'.trim().isNotEmpty && p['media_type'] != 'text',
            orElse: () => first,
          );
          final mediaUrl = '${thumbPost['media_url'] ?? ''}'.trim();
          final hasMedia = mediaUrl.isNotEmpty && thumbPost['media_type'] != 'text';
          final isVideo = thumbPost['media_type'] == 'video';
          final count = group.length;

          return GestureDetector(
            onTap: () => onTap(i),
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: seen
                              ? null
                              : LinearGradient(
                                  colors: isMine
                                      ? [kMainRose, const Color(0xFFFF9F6A)]
                                      : [kMainSky, const Color(0xFF7EC8E3)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: seen ? Colors.grey.shade300 : null,
                        ),
                        padding: const EdgeInsets.all(2.5),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: kMainBg,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: ClipOval(
                            child: hasMedia && !isVideo
                                ? Image.network(
                                    _mediaUrl(auth.baseUrl, mediaUrl),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => _StoryFallback(isMine: isMine),
                                  )
                                : hasMedia && isVideo
                                ? Container(
                                    color: const Color(0xFF1A1A2E),
                                    child: const Center(
                                      child: Icon(Icons.play_arrow_rounded, color: Colors.white54, size: 22),
                                    ),
                                  )
                                : _StoryFallback(isMine: isMine),
                          ),
                        ),
                      ),
                      if (count > 1)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isMine ? kMainRose : kMainSky,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: kMainBg, width: 1.5),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isMine ? '나' : '상대',
                    style: mainBody(
                      size: 11,
                      color: seen ? kMainMuted : (isMine ? kMainRose : kMainSky),
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StoryFallback extends StatelessWidget {
  final bool isMine;
  const _StoryFallback({required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isMine ? kMainRoseSoft : kMainSkySoft,
      child: Icon(
        Icons.notes_rounded,
        color: isMine ? kMainRose : kMainSky,
        size: 22,
      ),
    );
  }
}

// ── Story Viewer ──────────────────────────────────────────────────────────────

class _StoryViewer extends StatefulWidget {
  final List<List<Map<String, dynamic>>> groups;
  final int startGroupIndex;
  final AuthService auth;
  final int? myUserId;
  final String myNickname;
  final Set<String> seenSessionIds;
  final ValueChanged<String> onSeen;

  const _StoryViewer({
    required this.groups,
    required this.startGroupIndex,
    required this.auth,
    required this.myUserId,
    required this.myNickname,
    required this.seenSessionIds,
    required this.onSeen,
  });

  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer>
    with SingleTickerProviderStateMixin {
  late final PageController _groupPageCtrl;
  late int _groupIdx;
  int _mediaIdx = 0;
  late AnimationController _progress;
  static const _storyDuration = Duration(seconds: 10);

  List<Map<String, dynamic>> get _currentGroup => widget.groups[_groupIdx];
  Map<String, dynamic> get _currentPost => _currentGroup[_mediaIdx];

  @override
  void initState() {
    super.initState();
    _groupIdx = widget.startGroupIndex.clamp(0, widget.groups.length - 1);
    _groupPageCtrl = PageController(initialPage: _groupIdx);
    _progress = AnimationController(vsync: this, duration: _storyDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _advanceMedia();
      })
      ..forward();
    _markSeen();
  }

  @override
  void dispose() {
    _groupPageCtrl.dispose();
    _progress.dispose();
    super.dispose();
  }

  String _sessionKey(List<Map<String, dynamic>> group) {
    final sid = '${group.first['session_id'] ?? ''}'.trim();
    return sid.isNotEmpty ? sid : 'solo_${group.first['id']}';
  }

  void _markSeen() {
    final key = _sessionKey(_currentGroup);
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSeen(key));
  }

  void _restartProgress() {
    _progress
      ..reset()
      ..forward();
  }

  void _advanceMedia() {
    if (_mediaIdx < _currentGroup.length - 1) {
      setState(() => _mediaIdx++);
      _restartProgress();
    } else {
      _goToGroup(_groupIdx + 1);
    }
  }

  void _retreatMedia() {
    if (_mediaIdx > 0) {
      setState(() => _mediaIdx--);
      _restartProgress();
    } else {
      _goToGroup(_groupIdx - 1);
    }
  }

  void _goToGroup(int idx) {
    if (idx < 0 || idx >= widget.groups.length) {
      Navigator.of(context).pop();
      return;
    }
    _groupPageCtrl.jumpToPage(idx);
  }

  void _onGroupPageChanged(int idx) {
    setState(() {
      _groupIdx = idx;
      _mediaIdx = 0;
    });
    _restartProgress();
    _markSeen();
  }

  @override
  Widget build(BuildContext context) {
    final group = _currentGroup;
    final post = _currentPost;
    final isMine = '${post['user_id']}' == '${widget.myUserId}';
    final author = isMine
        ? widget.myNickname
        : '${post['Nickname'] ?? post['nickname'] ?? post['UserName'] ?? '상대'}';
    final caption = '${post['caption'] ?? ''}'.trim();
    final timeAgo = _timeAgo(post['captured_at']);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Outer PageView for group navigation (swipe) ────────────────
          PageView.builder(
            controller: _groupPageCtrl,
            onPageChanged: _onGroupPageChanged,
            itemCount: widget.groups.length,
            itemBuilder: (context, groupIdx) {
              final g = widget.groups[groupIdx];
              final mediaI = groupIdx == _groupIdx ? _mediaIdx : 0;
              final p = g[mediaI.clamp(0, g.length - 1)];
              final mUrl = '${p['media_url'] ?? ''}'.trim();
              final vid = p['media_type'] == 'video';
              final hasMed = mUrl.isNotEmpty && p['media_type'] != 'text';
              final cap = '${p['caption'] ?? ''}'.trim();

              return GestureDetector(
                onTapUp: (details) {
                  if (groupIdx != _groupIdx) return;
                  final x = details.globalPosition.dx;
                  final w = MediaQuery.of(context).size.width;
                  if (x < w / 3) _retreatMedia();
                  else _advanceMedia();
                },
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) > 200) {
                    Navigator.of(context).pop();
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasMed && !vid)
                      Image.network(
                        _mediaUrl(widget.auth.baseUrl, mUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
                      )
                    else if (hasMed && vid)
                      _VideoDetailPlayer(url: _mediaUrl(widget.auth.baseUrl, mUrl))
                    else
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            cap.isEmpty ? '말없이 남긴 순간' : cap,
                            style: const TextStyle(color: Colors.white, fontSize: 22, height: 1.6),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    // top gradient
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment(0, 0.35),
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    // bottom gradient
                    if (cap.isNotEmpty)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: const Alignment(0, 0.5),
                              colors: const [Color(0x99000000), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // ── Progress bars (current group's media) ──────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: List.generate(group.length, (i) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 2.5,
                        child: i < _mediaIdx
                            ? const ColoredBox(color: Colors.white)
                            : i == _mediaIdx
                            ? AnimatedBuilder(
                                animation: _progress,
                                builder: (_, __) => LinearProgressIndicator(
                                  value: _progress.value,
                                  backgroundColor: Colors.white30,
                                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                                  minHeight: 2.5,
                                ),
                              )
                            : const ColoredBox(color: Colors.white30),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // ── Header: author + time + close ──────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMine ? kMainRoseSoft : kMainSkySoft,
                    border: Border.all(color: Colors.white38),
                  ),
                  child: Center(
                    child: Text(
                      author.isEmpty ? '?' : author.characters.first,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isMine ? kMainRose : kMainSky,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      Text(timeAgo, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                ),
              ],
            ),
          ),

          // ── Caption ────────────────────────────────────────────────────
          if (caption.isNotEmpty)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 32,
              left: 20,
              right: 20,
              child: Text(
                caption,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.55,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Week Empty State ──────────────────────────────────────────────────────────

class _WeekEmptyState extends StatelessWidget {
  final bool isCurrentWeek;
  final VoidCallback onRefresh;
  const _WeekEmptyState({required this.isCurrentWeek, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: kMainRoseSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.photo_album_outlined, size: 34, color: kMainRose),
          ),
          const SizedBox(height: 16),
          Text(
            isCurrentWeek ? '이번 주 첫 순간을 남겨보세요' : '이 주에 남긴 순간이 없어요',
            style: mainBody(size: 15, color: kMainSub, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            isCurrentWeek ? '오른쪽 아래 + 버튼으로 추가해요' : '다른 주를 탐색해보세요',
            style: mainBody(size: 13, color: kMainMuted),
          ),
        ],
      ),
    );
  }
}

// ── Week Navigator ────────────────────────────────────────────────────────────

class _WeekNavigator extends StatelessWidget {
  final DateTime weekStart;
  final bool isCurrentWeek;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback onPickWeek;

  const _WeekNavigator({
    required this.weekStart,
    required this.isCurrentWeek,
    required this.onPrev,
    required this.onNext,
    required this.onPickWeek,
  });

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final sameMonth = weekStart.month == weekEnd.month;
    final label = sameMonth
        ? '${weekStart.month}월 ${weekStart.day}일 — ${weekEnd.day}일'
        : '${weekStart.month}월 ${weekStart.day}일 — ${weekEnd.month}월 ${weekEnd.day}일';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: kMainPaper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kMainLine),
        ),
        child: Row(
          children: [
            _NavBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
            Expanded(
              child: GestureDetector(
                onTap: onPickWeek,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: mainBody(size: 14, color: kMainInk, weight: FontWeight.w800),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.calendar_month_outlined, size: 14, color: kMainSub),
                      ],
                    ),
                    if (isCurrentWeek)
                      Text('이번 주', style: mainBody(size: 10, color: kMainRose, weight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            _NavBtn(
              icon: Icons.chevron_right_rounded,
              onTap: onNext,
              disabled: onNext == null,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;
  const _NavBtn({required this.icon, required this.onTap, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: SizedBox(
        width: 44,
        height: 48,
        child: Icon(icon, size: 22, color: disabled ? kMainLine : kMainSub),
      ),
    );
  }
}

// ── Day Section ───────────────────────────────────────────────────────────────

class _DaySection extends StatelessWidget {
  final DateTime day;
  final List<List<Map<String, dynamic>>> groups;
  final AuthService auth;
  final int? myUserId;
  final ValueChanged<List<Map<String, dynamic>>> onTap;

  const _DaySection({
    required this.day,
    required this.groups,
    required this.auth,
    required this.myUserId,
    required this.onTap,
  });

  static const _dayShort = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();

    final dayName = _dayShort[day.weekday - 1];
    final isToday = _dateKey(day.toIso8601String()) == _dateKey(DateTime.now().toIso8601String());
    final totalMedia = groups.fold(0, (sum, g) => sum + g.length);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Row(
              children: [
                Text(
                  '$dayName  ${day.day}',
                  style: mainBody(
                    size: 15,
                    color: isToday ? kMainRose : kMainInk,
                    weight: FontWeight.w900,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: kMainRoseSoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('오늘', style: mainBody(size: 11, color: kMainRose, weight: FontWeight.w800)),
                  ),
                ],
                const Spacer(),
                Text('${groups.length}개 게시글 · $totalMedia장', style: mainBody(size: 12, color: kMainMuted)),
              ],
            ),
          ),
          // ── Horizontal scroll of group cards ──────────────────────────
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final group = groups[i];
                // Representative thumbnail: first media item
                final thumbPost = group.firstWhere(
                  (p) => '${p['media_url'] ?? ''}'.trim().isNotEmpty && p['media_type'] != 'text',
                  orElse: () => group.first,
                );
                final mediaUrl = '${thumbPost['media_url'] ?? ''}'.trim();
                final isVideo = thumbPost['media_type'] == 'video';
                final hasMedia = mediaUrl.isNotEmpty && thumbPost['media_type'] != 'text';
                final caption = '${group.first['caption'] ?? ''}'.trim();
                final count = group.length;
                final isMine = '${group.first['user_id']}' == '$myUserId';

                return GestureDetector(
                  onTap: () => onTap(group),
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: kMainPaperSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasMedia && !isVideo)
                          Image.network(
                            _mediaUrl(auth.baseUrl, mediaUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: kMainMuted),
                          )
                        else if (hasMedia && isVideo) ...[
                          Container(color: const Color(0xFF1A1A2E)),
                          const Center(child: Icon(Icons.play_circle_rounded, color: Colors.white54, size: 36)),
                        ] else
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              caption.isEmpty ? '순간' : caption,
                              style: mainBody(size: 13, color: kMainSub, height: 1.5),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (caption.isNotEmpty && hasMedia)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: const [Color(0x99000000), Colors.transparent],
                                ),
                              ),
                              child: Text(
                                caption,
                                style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.4),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        // Media count badge
                        if (count > 1)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.collections_rounded, color: Colors.white, size: 11),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$count',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Mine indicator dot
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isMine ? kMainRose : kMainSky,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Divider(color: kMainLine.withAlpha(80), height: 1),
          ),
        ],
      ),
    );
  }
}

// ── Post Detail Page (tap from day section) ───────────────────────────────────

class _PostDetailPage extends StatefulWidget {
  final List<Map<String, dynamic>> group;
  final AuthService auth;
  final int? myUserId;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(Map<String, dynamic>) onDelete;
  final void Function(String sessionId, List<Map<String, dynamic>> reactions) onReactionUpdate;

  const _PostDetailPage({
    required this.group,
    required this.auth,
    required this.myUserId,
    required this.onEdit,
    required this.onDelete,
    required this.onReactionUpdate,
  });

  @override
  State<_PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<_PostDetailPage> {
  late final PageController _pageCtrl;
  int _current = 0;
  List<Map<String, dynamic>> _reactions = [];
  bool _reacting = false;

  static const _emojiOptions = ['❤️', '😍', '🥰', '😂', '😮'];

  String get _sessionId {
    final sid = '${widget.group.first['session_id'] ?? ''}'.trim();
    return sid.isNotEmpty ? sid : '';
  }

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _loadReactions();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _loadReactions() {
    final raw = widget.group.first['session_reactions'];
    if (raw is List) {
      _reactions = raw.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    }
  }

  String? _myEmoji() {
    final uid = '${widget.myUserId}';
    for (final r in _reactions) {
      if ('${r['user_id']}' == uid) return '${r['emoji']}';
    }
    return null;
  }

  int _emojiCount(String emoji) =>
      _reactions.where((r) => r['emoji'] == emoji).length;

  Future<void> _toggleReaction(String emoji) async {
    if (_sessionId.isEmpty || _reacting) return;
    setState(() => _reacting = true);
    try {
      final response = await http.post(
        Uri.parse('${widget.auth.baseUrl}/api/setlog/reaction'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.auth.token}',
        },
        body: jsonEncode({'session_id': _sessionId, 'emoji': emoji}),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['ok'] == true) {
        final updated = (data['reactions'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        if (!mounted) return;
        setState(() => _reactions = updated);
        widget.onReactionUpdate(_sessionId, updated);
      }
    } catch (_) {
      // silent fail
    } finally {
      if (mounted) setState(() => _reacting = false);
    }
  }

  bool _isMine(Map<String, dynamic> post) =>
      '${post['user_id']}' == '${widget.myUserId}';

  @override
  Widget build(BuildContext context) {
    final post = widget.group[_current];
    final isMine = _isMine(post);
    final caption = '${post['caption'] ?? ''}'.trim();
    final author = _authorName(post, isMine);
    final time = _timeLabel(post['captured_at']);
    final myEmoji = _myEmoji();
    final takenAt = DateTime.tryParse('${post['taken_at'] ?? ''}')?.toLocal();

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: takenAt != null
            ? Text(
                '${takenAt.month}월 ${takenAt.day}일 · ${_dayNameFull(takenAt)}',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              )
            : null,
        centerTitle: true,
        actions: [
          if (isMine)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              onSelected: (value) async {
                final nav = Navigator.of(context);
                if (value == 'edit') {
                  await widget.onEdit(post);
                  if (!mounted) return;
                  setState(() {});
                } else {
                  await widget.onDelete(post);
                  if (!mounted) return;
                  nav.pop();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('수정')),
                PopupMenuItem(value: 'delete', child: Text('삭제')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Media PageView ────────────────────────────────────────────
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.group.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (context, i) {
                final p = widget.group[i];
                final mediaUrl = '${p['media_url'] ?? ''}'.trim();
                final isVideo = p['media_type'] == 'video';
                final hasMedia = mediaUrl.isNotEmpty && p['media_type'] != 'text';

                if (hasMedia && !isVideo) {
                  return InteractiveViewer(
                    child: Image.network(
                      _mediaUrl(widget.auth.baseUrl, mediaUrl),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48),
                      ),
                    ),
                  );
                }
                if (hasMedia && isVideo) {
                  return _VideoDetailPlayer(url: _mediaUrl(widget.auth.baseUrl, mediaUrl));
                }
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      '${p['caption'] ?? ''}'.isEmpty ? '말없이 남긴 순간' : '${p['caption']}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, height: 1.6),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Bottom info + reactions ────────────────────────────────────
          Container(
            color: Colors.black,
            padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page dots
                if (widget.group.length > 1) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.group.length, (i) {
                      return Container(
                        width: i == _current ? 16 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i == _current ? Colors.white : Colors.white30,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                ],

                // Author row
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isMine ? kMainRoseSoft : kMainSkySoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          author.isEmpty ? '?' : author.characters.first,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isMine ? kMainRose : kMainSky),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(author, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(time, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ],
                ),

                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(caption, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.55)),
                ],

                const SizedBox(height: 16),
                // ── Emoji reaction bar ────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _emojiOptions.map((emoji) {
                    final count = _emojiCount(emoji);
                    final isSelected = myEmoji == emoji;
                    return GestureDetector(
                      onTap: () => _toggleReaction(emoji),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? kMainRoseSoft : Colors.white10,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: isSelected ? kMainRose : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(emoji, style: TextStyle(fontSize: isSelected ? 26 : 22)),
                            if (count > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                '$count',
                                style: TextStyle(
                                  color: isSelected ? kMainRose : Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoDetailPlayer extends StatefulWidget {
  final String url;
  const _VideoDetailPlayer({required this.url});

  @override
  State<_VideoDetailPlayer> createState() => _VideoDetailPlayerState();
}

class _VideoDetailPlayerState extends State<_VideoDetailPlayer> {
  late final VideoPlayerController _ctrl;
  bool _ready = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _ctrl.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _ctrl..setLooping(true)..play();
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return GestureDetector(
      onTap: () {
        setState(() => _muted = !_muted);
        _ctrl.setVolume(_muted ? 0 : 1);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(aspectRatio: _ctrl.value.aspectRatio, child: VideoPlayer(_ctrl)),
          Positioned(
            right: 16,
            bottom: 16,
            child: Icon(
              _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error State ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40, color: kMainMuted),
          const SizedBox(height: 12),
          Text(message, style: mainBody(color: kMainSub)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: kMainInk, foregroundColor: Colors.white),
            child: const Text('다시 불러오기'),
          ),
        ],
      ),
    );
  }
}

// ── Create Page ───────────────────────────────────────────────────────────────

class _PickedMomentMedia {
  final String name;
  final Uint8List bytes;
  final bool isVideo;
  _PickedMomentMedia({required this.name, required this.bytes, required this.isVideo});
}

class _SelectedMapLocation {
  final int? id;
  final String name;
  final String? category;
  const _SelectedMapLocation({required this.id, required this.name, this.category});
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

  static const _maxMedia = 10;

  int get _photoCount => _pickedMedia.where((m) => !m.isVideo).length;
  int get _videoCount => _pickedMedia.where((m) => m.isVideo).length;

  int? get _userId {
    final value = widget.auth.user?['UserId'] ?? widget.auth.user?['id'];
    if (value is int) return value;
    return int.tryParse('$value');
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

  Future<void> _showMediaPicker() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: kMainPaper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: kMainLine, borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 16),
              Text('미디어 추가', style: mainTitle(size: 20)),
              const SizedBox(height: 16),
              _MediaPickerRow(
                icon: Icons.image_outlined,
                label: '사진',
                count: _photoCount,
                max: _maxMedia,
                color: kMainSage,
                onTap: _pickedMedia.length < _maxMedia ? () async {
                  Navigator.pop(ctx);
                  await _addPhotos();
                } : null,
              ),
              const SizedBox(height: 10),
              _MediaPickerRow(
                icon: Icons.videocam_outlined,
                label: '영상',
                count: _videoCount,
                max: _maxMedia,
                color: kMainPeach,
                onTap: _pickedMedia.length < _maxMedia ? () async {
                  Navigator.pop(ctx);
                  await _addVideo();
                } : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addPhotos() async {
    final remaining = _maxMedia - _pickedMedia.length;
    if (remaining <= 0) return;
    try {
      final files = await _imagePicker.pickMultiImage(imageQuality: 86, limit: remaining);
      if (files.isEmpty) return;
      final media = <_PickedMomentMedia>[];
      for (final file in files) {
        media.add(_PickedMomentMedia(
          name: file.name,
          bytes: await file.readAsBytes(),
          isVideo: false,
        ));
      }
      if (!mounted) return;
      setState(() => _pickedMedia.addAll(media));
    } catch (_) {
      _toast('사진을 불러오지 못했어요');
    }
  }

  Future<void> _addVideo() async {
    if (_pickedMedia.length >= _maxMedia) return;
    try {
      final file = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 30 * 1024 * 1024) {
        _toast('영상은 30MB 이하만 올릴 수 있어요');
        return;
      }
      if (!mounted) return;
      setState(() => _pickedMedia.add(
        _PickedMomentMedia(name: file.name, bytes: bytes, isVideo: true),
      ));
    } catch (_) {
      _toast('영상을 불러오지 못했어요');
    }
  }

  Future<void> _loadMapPins() async {
    final userId = _userId;
    if (userId == null || _loadingLocations) return;
    setState(() => _loadingLocations = true);
    try {
      final uri = Uri.parse('${widget.auth.baseUrl}/api/map')
          .replace(queryParameters: {'user_id': '$userId'});
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
              ? pins.map((pin) => Map<String, dynamic>.from(pin as Map)).toList()
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
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const MapScreen(closeAsModal: true),
        ),
      );
      if (!mounted) return;
      await _loadMapPins();
      if (!mounted) return;
      await _pickLocation();
      return;
    }
    final location = picked.location;
    if (location != null) setState(() => _selectedLocation = location);
  }

  Future<int?> _ensureMapPinId({
    required _SelectedMapLocation location,
    required String caption,
    required DateTime now,
  }) async {
    if (!location.isNew) return location.id;
    final userId = _userId;
    final userCode = widget.auth.user?['UserCode'] ?? widget.auth.user?['userCode'];
    if (userId == null || userCode == null) return null;
    final response = await http.post(
      Uri.parse('${widget.auth.baseUrl}/api/map'),
      headers: {
        'Content-Type': 'application/json',
        if (widget.auth.token != null) 'Authorization': 'Bearer ${widget.auth.token}',
      },
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
    if (caption.isEmpty) { _toast('오늘 남기고 싶은 장면을 적어주세요'); return; }
    setState(() => _saving = true);
    final now = DateTime.now();
    // All media in this upload share the same session_id
    final sessionId = '${now.millisecondsSinceEpoch}';

    try {
      final location = _selectedLocation;
      final mapPinId = location == null
          ? null
          : await _ensureMapPinId(location: location, caption: caption, now: now);
      if (location != null && mapPinId == null) {
        _toast('비밀지도 위치를 연결하지 못했어요');
        return;
      }

      final mediaItems = _pickedMedia.isEmpty
          ? <_PickedMomentMedia?>[null]
          : _pickedMedia.map<_PickedMomentMedia?>((m) => m).toList();

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
          'session_id': sessionId,
          if (mapPinId != null) 'map_pin_id': '$mapPinId',
        });
        if (media != null) {
          request.files.add(http.MultipartFile.fromBytes(
            'media', media.bytes,
            filename: media.name,
            contentType: MediaType.parse(_mimeFor(media.name, media.isVideo)),
          ));
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

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: mainBody(color: Colors.white))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalMedia = _pickedMedia.length;
    final canAddMore = totalMedia < _maxMedia;

    return Scaffold(
      backgroundColor: kMainPaper,
      appBar: AppBar(
        backgroundColor: kMainPaper,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          icon: const Icon(Icons.close_rounded),
          color: kMainInk,
        ),
        centerTitle: true,
        title: Text('새 순간', style: mainBody(size: 17, weight: FontWeight.w900)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveMoment,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('공유', style: mainBody(color: kMainRose, weight: FontWeight.w900, size: 16)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            // ── Media grid ────────────────────────────────────────────────
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: kMainPaperSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kMainLine),
                ),
                clipBehavior: Clip.antiAlias,
                child: totalMedia == 0
                    // Empty: full-area + button
                    ? GestureDetector(
                        onTap: canAddMore ? _showMediaPicker : null,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: kMainPaper,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: kMainLine),
                              ),
                              child: const Icon(Icons.add_rounded, size: 32, color: kMainSub),
                            ),
                            const SizedBox(height: 12),
                            Text('사진 또는 영상 추가', style: mainBody(color: kMainSub, size: 14)),
                            const SizedBox(height: 4),
                            Text(
                              '사진·영상 합산 최대 10개',
                              style: mainBody(color: kMainMuted, size: 12),
                            ),
                          ],
                        ),
                      )
                    // Has items: 3-col grid + optional + tile
                    : GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(4),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: totalMedia + (canAddMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == totalMedia) {
                            return GestureDetector(
                              onTap: _showMediaPicker,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: kMainPaper,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: kMainLine),
                                ),
                                child: const Icon(Icons.add_rounded, color: kMainSub),
                              ),
                            );
                          }
                          final media = _pickedMedia[i];
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: media.isVideo
                                    ? Container(
                                        color: const Color(0xFF1A1A2E),
                                        child: const Center(
                                          child: Icon(Icons.videocam_rounded, color: Colors.white54, size: 28),
                                        ),
                                      )
                                    : Image.memory(media.bytes, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setState(() => _pickedMedia.removeAt(i)),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Caption ───────────────────────────────────────────────────
            TextField(
              controller: _captionCtrl,
              minLines: 4,
              maxLines: 8,
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
                contentPadding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 12),

            // ── Location ──────────────────────────────────────────────────
            _LocationAddButton(
              location: _selectedLocation,
              loading: _loadingLocations,
              onTap: _saving ? null : _pickLocation,
              onClear: _saving ? null : () => setState(() => _selectedLocation = null),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPickerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final int max;
  final Color color;
  final VoidCallback? onTap;

  const _MediaPickerRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.max,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final full = count >= max;
    return GestureDetector(
      onTap: full ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: full ? kMainPaperSoft : color.withAlpha(18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: full ? kMainLine : color.withAlpha(60)),
        ),
        child: Row(
          children: [
            Icon(icon, color: full ? kMainMuted : color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: mainBody(
                  size: 15,
                  color: full ? kMainMuted : kMainInk,
                  weight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$count / $max',
              style: mainBody(size: 13, color: full ? kMainMuted : color, weight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Icon(
              full ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
              color: full ? kMainSage : color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Location widgets (unchanged) ──────────────────────────────────────────────

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
                    style: mainBody(size: 15, color: kMainInk, weight: FontWeight.w800),
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
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else if (selected != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: kMainMuted,
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
  State<_MapLocationPickerSheet> createState() => _MapLocationPickerSheetState();
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
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
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
              width: 40, height: 4,
              decoration: BoxDecoration(color: kMainLine, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const SizedBox(height: 18),
          Text('비밀지도 위치', style: mainTitle(size: 22)),
          const SizedBox(height: 6),
          Text('이미 등록한 위치를 검색하거나 비밀지도에서 새로 추가하세요.',
              style: mainBody(size: 13, color: kMainMuted)),
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
                            onPressed: () { _searchCtrl.clear(); setState(() {}); },
                            icon: const Icon(Icons.close_rounded),
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
                onPressed: () => Navigator.pop(context, const _MapLocationPickerResult.openMap()),
                icon: const Icon(Icons.add_location_alt_outlined),
                tooltip: '비밀지도에서 추가',
                style: IconButton.styleFrom(
                  backgroundColor: kMainInk,
                  foregroundColor: Colors.white,
                  fixedSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                          const Icon(Icons.map_outlined, color: kMainMuted, size: 34),
                          const SizedBox(height: 10),
                          Text(
                            widget.pins.isEmpty ? '비밀지도에 저장된 위치가 없어요' : '검색 결과가 없어요',
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
                      return InkWell(
                        onTap: () => Navigator.pop(
                          context,
                          _MapLocationPickerResult.location(
                            _SelectedMapLocation(id: id, name: name, category: category),
                          ),
                        ),
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
                                selected ? Icons.radio_button_checked_rounded : Icons.place_outlined,
                                color: selected ? kMainRose : kMainInk,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: mainBody(size: 15, color: kMainInk, weight: FontWeight.w900)),
                                    Text(category, style: mainBody(size: 12, color: kMainMuted)),
                                  ],
                                ),
                              ),
                            ],
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

// ── Helpers ───────────────────────────────────────────────────────────────────

String _dateKey(dynamic value) {
  final date = value is DateTime ? value : DateTime.tryParse('${value ?? ''}')?.toLocal();
  if (date == null) return '';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _authorName(Map<String, dynamic> post, bool isMine) {
  if (isMine) return '나';
  return '${post['Nickname'] ?? post['nickname'] ?? post['UserName'] ?? post['userName'] ?? '상대'}';
}

String _timeLabel(dynamic value) {
  final date = DateTime.tryParse('${value ?? ''}')?.toLocal();
  if (date == null) return '';
  final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
  final ampm = date.hour >= 12 ? '오후' : '오전';
  return '$ampm $hour:${date.minute.toString().padLeft(2, '0')}';
}

String _dayNameFull(DateTime d) {
  const names = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
  return names[d.weekday - 1];
}

String _mediaUrl(String baseUrl, String mediaUrl) {
  if (mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://')) return mediaUrl;
  return '$baseUrl$mediaUrl';
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _mysqlDateTime(DateTime value) =>
    '${_dateOnly(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

String _timeAgo(dynamic value) {
  final date = DateTime.tryParse('${value ?? ''}')?.toLocal();
  if (date == null) return '';
  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 60) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return '${date.month}월 ${date.day}일';
}

String _mimeFor(String name, bool isVideo) {
  final ext = name.split('.').last.toLowerCase();
  const map = {
    'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
    'gif': 'image/gif', 'webp': 'image/webp',
    'mp4': 'video/mp4', 'mov': 'video/quicktime', 'm4v': 'video/mp4',
  };
  return map[ext] ?? (isVideo ? 'video/mp4' : 'image/jpeg');
}
