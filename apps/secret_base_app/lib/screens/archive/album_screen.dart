import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth_service.dart';
import '../../core/main_design.dart';
import 'premium_screen.dart';

// ──────────────────────────────────────────────────────────────────────────────
// 우리 앨범 (폴더 목록 화면)
// ──────────────────────────────────────────────────────────────────────────────

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final _auth = AuthService();
  List<dynamic> _folders = [];
  bool _loading = true;
  bool _isPremium = false;
  int _folderLimit = 15;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  int? get _userId {
    final value = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (value is int) return value;
    return int.tryParse('$value');
  }

  Future<void> _loadFolders() async {
    final uid = _userId;
    if (uid == null) {
      setState(() { _loading = false; _error = '로그인 정보가 없어요'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final response = await http.get(
        Uri.parse('${_auth.baseUrl}/api/album/folders?user_id=$uid'),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['ok'] == true) {
        setState(() {
          _folders = data['folders'] ?? [];
          _isPremium = data['is_premium'] == true;
          _folderLimit = (data['folder_limit'] as num?)?.toInt() ?? 15;
        });
      } else {
        setState(() => _error = '폴더를 불러오지 못했어요');
      }
    } catch (_) {
      setState(() => _error = '네트워크 연결 상태를 확인해주세요');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createFolder(String title, String? desc) async {
    final uid = _userId;
    if (uid == null || title.trim().isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse('${_auth.baseUrl}/api/album/folders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': uid, 'title': title.trim(), 'description': desc?.trim()}),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (response.statusCode == 200 && data['ok'] == true) {
        _loadFolders();
      } else {
        final reason = data['reason'];
        if (reason == 'folder_limit_exceeded') {
          _showPremiumDialog(data['message'] ?? '폴더 생성 한도를 초과했습니다.');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('앨범 폴더를 만들지 못했어요')));
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('네트워크 오류가 발생했습니다')));
    }
  }

  Future<void> _deleteFolder(int folderId) async {
    try {
      final response = await http.delete(Uri.parse('${_auth.baseUrl}/api/album/folders/$folderId'));
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (response.statusCode == 200 && data['ok'] == true) {
        _loadFolders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('폴더 삭제에 실패했습니다')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('네트워크 오류가 발생했습니다')));
    }
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kMainPaper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('새 추억 폴더 만들기', style: mainTitle(size: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              maxLength: 20,
              decoration: InputDecoration(
                hintText: '폴더 이름 (예: 오이도 여행 🐚)',
                hintStyle: mainBody(size: 13, color: kMainMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kMainRose, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              maxLength: 60,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: '한 줄 설명 (선택)',
                hintStyle: mainBody(size: 12, color: kMainMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kMainRose, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('취소', style: mainBody(color: kMainMuted))),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _createFolder(titleCtrl.text, descCtrl.text);
            },
            style: FilledButton.styleFrom(
              backgroundColor: kMainRose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('만들기', style: mainBody(color: Colors.white, weight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPremiumDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kMainPaper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          const Text('👑', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Text('비밀기지 Premium', style: mainTitle(size: 18, color: kMainInk)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: mainBody(size: 14, color: kMainInk, weight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Premium으로 업그레이드하면:\n• 폴더 최대 100개\n• 폴더당 각자 50장\n• 2K 고화질 원본 보관',
              style: mainBody(size: 12, color: kMainSub)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: kMainRoseSoft, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('월간 플랜', style: mainBody(size: 12, color: kMainRose, weight: FontWeight.bold)),
                  Text('₩1,900 / 월', style: mainBody(size: 13, color: kMainInk, weight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('연간 플랜 (17% 할인)', style: mainBody(size: 12, color: const Color(0xFFB8860B), weight: FontWeight.bold)),
                  Text('₩19,000 / 년', style: mainBody(size: 13, color: kMainInk, weight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('나중에', style: mainBody(color: kMainMuted))),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
            },
            style: FilledButton.styleFrom(
              backgroundColor: kMainRose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('구독하기 👑', style: mainBody(color: Colors.white, weight: FontWeight.bold)),
          ),
        ],
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
        title: Text('우리 앨범 📸', style: mainTitle(size: 22)),
        actions: [
          if (_isPremium)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('👑 Premium', style: mainBody(size: 11, color: Colors.white, weight: FontWeight.bold)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: kMainInk),
            onPressed: _loadFolders,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainRose))
          : _error != null
              ? Center(child: Text(_error!, style: mainBody(color: kMainSub)))
              : RefreshIndicator(
                  color: kMainRose,
                  onRefresh: _loadFolders,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_folders.length} / $_folderLimit 폴더',
                                style: mainBody(size: 13, color: kMainSub),
                              ),
                              if (!_isPremium)
                                GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen())).then((_) => _loadFolders()),
                                  child: Text('👑 업그레이드', style: mainBody(size: 12, color: kMainRose, weight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                          child: LinearProgressIndicator(
                            value: _folderLimit > 0 ? (_folders.length / _folderLimit).clamp(0.0, 1.0) : 0,
                            backgroundColor: kMainRoseSoft,
                            color: _folders.length >= _folderLimit ? Colors.red : kMainRose,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      _folders.isEmpty
                          ? SliverFillRemaining(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('📂', style: TextStyle(fontSize: 64)),
                                    const SizedBox(height: 16),
                                    Text('아직 추억 폴더가 없어요', style: mainTitle(size: 18, color: kMainInk)),
                                    const SizedBox(height: 8),
                                    Text('첫 번째 추억 폴더를 만들어 보세요!', style: mainBody(size: 14, color: kMainSub)),
                                  ],
                                ),
                              ),
                            )
                          : SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (ctx, i) {
                                    final folder = _folders[i];
                                    return _FolderCard(
                                      folder: folder,
                                      baseUrl: _auth.baseUrl,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AlbumFolderDetailScreen(
                                              folderId: folder['id'],
                                              folderTitle: folder['title'] ?? '추억 폴더',
                                              isPremium: _isPremium,
                                            ),
                                          ),
                                        ).then((_) => _loadFolders());
                                      },
                                      onDelete: () => showDialog(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          backgroundColor: kMainPaper,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          title: Text('폴더 삭제', style: mainTitle(size: 18)),
                                          content: Text('"${folder['title']}" 폴더와 안에 있는 사진이 모두 삭제됩니다.', style: mainBody()),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c), child: Text('취소', style: mainBody(color: kMainMuted))),
                                            TextButton(
                                              onPressed: () { _deleteFolder(folder['id']); Navigator.pop(c); },
                                              child: const Text('삭제', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  childCount: _folders.length,
                                ),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 0.85,
                                ),
                              ),
                            ),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: kMainRose,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('새 폴더', style: mainBody(color: Colors.white, weight: FontWeight.bold)),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 폴더 카드 위젯
// ──────────────────────────────────────────────────────────────────────────────

class _FolderCard extends StatelessWidget {
  final Map<String, dynamic> folder;
  final String baseUrl;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _FolderCard({
    required this.folder,
    required this.baseUrl,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = folder['cover_url'];
    final hasDescription = folder['description'] != null && (folder['description'] as String).isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: MainCard(
        padding: EdgeInsets.zero,
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: coverUrl != null
                    ? Image.network(
                        '$baseUrl$coverUrl',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _emptyFolderCover(),
                      )
                    : _emptyFolderCover(),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    folder['title'] ?? '추억 폴더',
                    style: mainBody(size: 14, color: kMainInk, weight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasDescription) ...[
                    const SizedBox(height: 2),
                    Text(
                      folder['description'],
                      style: mainBody(size: 11, color: kMainMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyFolderCover() {
    return Container(
      color: kMainRoseSoft,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📂', style: TextStyle(fontSize: 42)),
            const SizedBox(height: 8),
            Text('우리 추억 페이지', style: mainBody(size: 11, color: kMainRose)),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 폴더 상세 화면 (폴라로이드 벽 테마)
// ──────────────────────────────────────────────────────────────────────────────

class AlbumFolderDetailScreen extends StatefulWidget {
  final int folderId;
  final String folderTitle;
  final bool isPremium;

  const AlbumFolderDetailScreen({
    super.key,
    required this.folderId,
    required this.folderTitle,
    this.isPremium = false,
  });

  @override
  State<AlbumFolderDetailScreen> createState() => _AlbumFolderDetailScreenState();
}

class _AlbumFolderDetailScreenState extends State<AlbumFolderDetailScreen> {
  final _auth = AuthService();
  final _imagePicker = ImagePicker();
  List<dynamic> _photos = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  int? get _userId {
    final value = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (value is int) return value;
    return int.tryParse('$value');
  }

  int get _photoLimit => widget.isPremium ? 50 : 10;

  Future<void> _loadPhotos() async {
    setState(() => _loading = true);
    try {
      final response = await http.get(
        Uri.parse('${_auth.baseUrl}/api/album/photos?folder_id=${widget.folderId}'),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['ok'] == true) {
        setState(() { _photos = data['photos'] ?? []; });
      }
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _uploadPhoto() async {
    final uid = _userId;
    final myCode = _auth.user?['UserCode'];
    if (uid == null || myCode == null || _uploading) return;

    // 클라이언트 선제 한도 체크
    final myCount = _photos.where((p) => p['user_id'] == uid).length;
    if (myCount >= _photoLimit) {
      _showPremiumDialog('한 폴더에 각자 최대 $_photoLimit장의 사진만 넣을 수 있어요!');
      return;
    }

    // 캡션 입력 다이얼로그
    String? caption;
    final captionCtrl = TextEditingController();
    final captionConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kMainPaper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('사진 추가', style: mainTitle(size: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: captionCtrl,
              maxLength: 80,
              decoration: InputDecoration(
                hintText: '이 사진에 한마디! (선택)',
                hintStyle: mainBody(size: 13, color: kMainMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kMainRose, width: 1.5),
                ),
              ),
            ),
            if (widget.isPremium)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Text('👑', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text('2K 고화질로 저장됩니다', style: mainBody(size: 11, color: const Color(0xFFB8860B))),
                ]),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('취소', style: mainBody(color: kMainMuted))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: kMainRose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('사진 고르기', style: mainBody(color: Colors.white, weight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (captionConfirmed != true) return;
    caption = captionCtrl.text.trim().isEmpty ? null : captionCtrl.text.trim();

    // Premium = 2K(2048px), 일반 = 1080px 압축
    final quality = widget.isPremium ? 90 : 70;
    final maxDim = widget.isPremium ? 2048.0 : 1080.0;

    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxDim,
      maxHeight: maxDim,
      imageQuality: quality,
    );
    if (pickedFile == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await pickedFile.readAsBytes();
      final request = http.MultipartRequest('POST', Uri.parse('${_auth.baseUrl}/api/album/photos'));
      request.fields.addAll({
        'folder_id': '${widget.folderId}',
        'user_id': '$uid',
        'user_code': myCode,
        if (caption != null) 'caption': caption,
      });

      final ext = pickedFile.name.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      request.files.add(http.MultipartFile.fromBytes('media', bytes, filename: pickedFile.name, contentType: MediaType.parse(mime)));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      if (!mounted) return;
      if (response.statusCode == 200 && data['ok'] == true) {
        await _loadPhotos();
      } else {
        final reason = data['reason'];
        if (reason == 'limit_exceeded') {
          _showPremiumDialog(data['message'] ?? '사진 등록 한도를 초과했습니다.');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사진 업로드에 실패했습니다.')));
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사진 업로드 중 네트워크 오류가 발생했습니다')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deletePhoto(int id) async {
    try {
      final response = await http.delete(Uri.parse('${_auth.baseUrl}/api/album/photos/$id'));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['ok'] == true) _loadPhotos();
    } catch (_) {}
  }

  Future<void> _setCover(String photoUrl) async {
    try {
      final path = photoUrl.replaceFirst(_auth.baseUrl, '');
      final response = await http.patch(
        Uri.parse('${_auth.baseUrl}/api/album/folders/${widget.folderId}/set-cover'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'photo_url': path}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['ok'] == true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이 사진을 폴더 커버로 설정했어요! 📸')));
      }
    } catch (_) {}
  }

  Future<void> _downloadPhoto(String photoUrl) async {
    final uri = Uri.parse(photoUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _downloadAll() async {
    final uri = Uri.parse('${_auth.baseUrl}/api/album/folders/${widget.folderId}/download-all');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showPremiumDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kMainPaper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          const Text('👑', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Text('비밀기지 Premium', style: mainTitle(size: 18, color: kMainInk)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: mainBody(size: 14, color: kMainInk, weight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Premium으로 업그레이드하면:\n• 폴더당 각자 50장\n• 2K 고화질 원본 보관\n• 폴더 최대 100개',
              style: mainBody(size: 12, color: kMainSub)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: kMainRoseSoft, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('월 구독료', style: mainBody(size: 12, color: kMainRose, weight: FontWeight.bold)),
                  Text('₩1,900 / 월', style: mainBody(size: 13, color: kMainInk, weight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('나중에', style: mainBody(color: kMainMuted))),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
            },
            style: FilledButton.styleFrom(
              backgroundColor: kMainRose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('구독하기 👑', style: mainBody(color: Colors.white, weight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _userId;
    final partnerNick = _auth.user?['PartnerNickname'] ?? '상대방';
    final myNick = _auth.user?['Nickname'] ?? '나';

    final myPhotos = _photos.where((p) => p['user_id'] == myUid).toList();
    final partnerPhotos = _photos.where((p) => p['user_id'] != myUid).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF6B4C3B), // 나무 보드 느낌
      appBar: AppBar(
        backgroundColor: const Color(0xFF5A3D2B),
        elevation: 0,
        title: Text(widget.folderTitle, style: mainTitle(size: 20, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.isPremium)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('👑 HD', style: mainBody(size: 10, color: Colors.white, weight: FontWeight.bold)),
            ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: '일괄 다운로드',
            onPressed: _photos.isEmpty ? null : _downloadAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                // 업로드 현황 바
                Container(
                  color: const Color(0xFF5A3D2B),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$myNick ${myPhotos.length}/$_photoLimit장', style: mainBody(size: 11, color: Colors.white70)),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: (myPhotos.length / _photoLimit).clamp(0.0, 1.0),
                              backgroundColor: Colors.white24,
                              color: Colors.white,
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$partnerNick ${partnerPhotos.length}/$_photoLimit장', style: mainBody(size: 11, color: Colors.white70)),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: (partnerPhotos.length / _photoLimit).clamp(0.0, 1.0),
                              backgroundColor: Colors.white24,
                              color: kMainRose,
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 폴라로이드 사진 벽
                Expanded(
                  child: _photos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🖼️', style: TextStyle(fontSize: 60)),
                              const SizedBox(height: 16),
                              Text('아직 사진이 없어요\n첫 번째 추억을 올려보세요!',
                                style: mainBody(size: 16, color: Colors.white70),
                                textAlign: TextAlign.center),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: _photos.length,
                          itemBuilder: (ctx, i) {
                            final photo = _photos[i];
                            final isMine = photo['user_id'] == myUid;
                            final isPremiumQuality = photo['is_premium_quality'] == 1;
                            return _PolaroidCard(
                              photoUrl: '${_auth.baseUrl}${photo['photo_url']}',
                              caption: photo['caption'],
                              isMine: isMine,
                              isPremiumQuality: isPremiumQuality,
                              onDelete: isMine ? () => _deletePhoto(photo['id']) : null,
                              onSetCover: () => _setCover('${_auth.baseUrl}${photo['photo_url']}'),
                              onDownload: () => _downloadPhoto('${_auth.baseUrl}${photo['photo_url']}'),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: _uploading
          ? FloatingActionButton.extended(
              onPressed: null,
              backgroundColor: kMainRose,
              icon: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              label: Text('업로드 중...', style: mainBody(color: Colors.white)),
            )
          : FloatingActionButton.extended(
              onPressed: _uploadPhoto,
              backgroundColor: kMainRose,
              icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
              label: Text('사진 추가', style: mainBody(color: Colors.white, weight: FontWeight.bold)),
            ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 폴라로이드 카드 위젯
// ──────────────────────────────────────────────────────────────────────────────

class _PolaroidCard extends StatelessWidget {
  final String photoUrl;
  final String? caption;
  final bool isMine;
  final bool isPremiumQuality;
  final VoidCallback? onDelete;
  final VoidCallback? onSetCover;
  final VoidCallback? onDownload;

  const _PolaroidCard({
    required this.photoUrl,
    required this.isMine,
    this.caption,
    this.isPremiumQuality = false,
    this.onDelete,
    this.onSetCover,
    this.onDownload,
  });

  void _showActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: kMainPaper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: kMainMuted, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            if (onSetCover != null)
              ListTile(
                leading: const Icon(Icons.image_rounded, color: kMainInk),
                title: Text('폴더 커버로 설정', style: mainBody(size: 15, color: kMainInk, weight: FontWeight.bold)),
                onTap: () { Navigator.pop(ctx); onSetCover!(); },
              ),
            if (onDownload != null)
              ListTile(
                leading: const Icon(Icons.download_rounded, color: kMainInk),
                title: Text('사진 다운로드', style: mainBody(size: 15, color: kMainInk, weight: FontWeight.bold)),
                onTap: () { Navigator.pop(ctx); onDownload!(); },
              ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: Text('사진 삭제', style: mainBody(size: 15, color: Colors.red, weight: FontWeight.bold)),
                onTap: () { 
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: kMainPaper,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('사진 삭제', style: mainTitle(size: 16)),
                      content: Text('이 사진을 삭제할까요?', style: mainBody()),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c), child: Text('취소', style: mainBody(color: kMainMuted))),
                        TextButton(
                          onPressed: () { Navigator.pop(c); onDelete!(); },
                          child: const Text('삭제', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 약간의 랜덤한 기울기로 폴라로이드 느낌
    final tilt = isMine ? -0.04 : 0.03;

    return Transform.rotate(
      angle: tilt,
      child: GestureDetector(
        onTap: () => _showActionMenu(context),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(2, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 나무 핀
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: -7),
                  decoration: BoxDecoration(
                    color: isMine ? const Color(0xFF8B4513) : const Color(0xFF4A90D9),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 3)],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: kMainRoseSoft,
                        child: const Center(child: Icon(Icons.broken_image_rounded, color: kMainMuted)),
                      ),
                    ),
                  ),
                ),
              ),
              // 캡션 + 화질 배지
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caption != null && caption!.isNotEmpty)
                      Text(
                        caption!,
                        style: const TextStyle(
                          fontFamily: 'Gaegu',
                          fontSize: 11,
                          color: Color(0xFF3D3D3D),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        isMine ? '나의 추억 💕' : '우리의 추억 💕',
                        style: const TextStyle(fontFamily: 'Gaegu', fontSize: 11, color: Color(0xFF9E9E9E)),
                      ),
                    if (isPremiumQuality)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            const Text('✨', style: TextStyle(fontSize: 9)),
                            const SizedBox(width: 2),
                            Text('2K HD', style: mainBody(size: 9, color: const Color(0xFFB8860B))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
