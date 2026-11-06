import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/auth_service.dart';
import '../../v2/v2.dart';

/// Saves the exported ZIP. Returns the saved path, or null when the user
/// cancelled (on web the browser downloads it and null is also returned).
typedef PersonalHistorySaver =
    Future<String?> Function(String fileName, Uint8List bytes);

enum _Failure { none, offline, locked, server }

enum _ExportStatus { idle, running, done, failed, cancelled }

/// 개인 보관함: records I made before connecting (or after a connection ended).
/// They are private to me - the partner never sees them. While connected the
/// server closes the vault (409); the screen explains that instead of
/// showing an error.
class PersonalHistoryScreen extends StatefulWidget {
  final http.Client? client;

  /// Where "첫 기록 남기기" in the empty state goes. Hidden when null.
  final VoidCallback? onCreateRecord;

  /// Overrides the ZIP save dialog (tests).
  final PersonalHistorySaver? saver;

  const PersonalHistoryScreen({
    super.key,
    this.client,
    this.onCreateRecord,
    this.saver,
  });

  @override
  State<PersonalHistoryScreen> createState() => _PersonalHistoryScreenState();
}

class _PersonalHistoryScreenState extends State<PersonalHistoryScreen> {
  final _auth = AuthService();
  List<Map<String, dynamic>> _moments = [];
  List<Map<String, dynamic>> _pins = [];
  bool _loading = true;
  _Failure _failure = _Failure.none;
  _ExportStatus _export = _ExportStatus.idle;
  final Set<String> _deleting = {};
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

  bool _isOffline(Object error) =>
      error is http.ClientException || error is TimeoutException;

  /// [silent] keeps the list on screen (after a delete).
  Future<void> _load({bool silent = false}) async {
    if (mounted && !silent) {
      setState(() {
        _loading = true;
        _failure = _Failure.none;
      });
    }
    try {
      final response = await _client.get(
        Uri.parse('${_auth.baseUrl}/api/history'),
        headers: _headers,
      );
      if (!mounted) return;
      if (response.statusCode == 409) {
        setState(() => _failure = _Failure.locked);
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const FormatException();
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _failure = _Failure.none;
        _moments = (data['moments'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _pins = (data['pins'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      if (silent) {
        showV2Snack(
          context,
          '목록을 새로 불러오지 못했어요. 아래로 당겨 다시 시도해 주세요.',
          tone: V2Tone.err,
        );
      } else {
        setState(
          () =>
              _failure = _isOffline(error) ? _Failure.offline : _Failure.server,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _id(Map<String, dynamic> item) {
    final raw = item['id'];
    return raw is int ? raw : int.tryParse('$raw');
  }

  Future<void> _confirmDelete(String kind, Map<String, dynamic> item) async {
    final id = _id(item);
    if (id == null) return;
    final isMoment = kind == 'moments';
    final hasFile =
        isMoment &&
        (item['media_type'] == 'image' || item['media_type'] == 'video') &&
        item['media_url'] != null;
    final ok = await showV2ConfirmDestructiveSheet(
      context,
      title: isMoment ? '이 기록을 지울까요?' : '이 장소를 지울까요?',
      message: isMoment ? _momentTitle(item) : '${item['place_name'] ?? '장소'}',
      consequences: isMoment
          ? [
              hasFile
                  ? (item['media_type'] == 'video'
                        ? '영상 파일까지 함께 지워져요'
                        : '사진 파일까지 함께 지워져요')
                  : '남긴 글이 지워져요',
              '지운 기록은 되돌릴 수 없어요',
            ]
          : ['내 장소 목록에서 사라져요', '지운 장소는 되돌릴 수 없어요'],
      confirmLabel: '지우기',
    );
    if (!ok || !mounted) return;
    await _delete(kind, id, isMoment ? '기록을' : '장소를');
  }

  Future<void> _delete(String kind, int id, String object) async {
    final key = '$kind/$id';
    setState(() => _deleting.add(key));
    var message = '';
    var failed = false;
    try {
      final response = await _client.delete(
        Uri.parse('${_auth.baseUrl}/api/history/$kind/$id'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        message = '$object 지웠어요';
      } else if (response.statusCode == 404) {
        message = '이미 지워졌어요';
      } else if (response.statusCode == 409) {
        failed = true;
        message = '연결 중에는 보관함을 바꿀 수 없어요';
      } else {
        failed = true;
        message = '$object 지우지 못했어요. 다시 시도해 주세요.';
      }
    } catch (error) {
      failed = true;
      message = _isOffline(error)
          ? '인터넷 연결을 확인한 뒤 다시 시도해 주세요.'
          : '$object 지우지 못했어요. 다시 시도해 주세요.';
    }
    if (!mounted) return;
    setState(() => _deleting.remove(key));
    if (failed) {
      showV2Snack(
        context,
        message,
        tone: V2Tone.err,
        actionLabel: '다시 시도',
        onAction: () => _delete(kind, id, object),
      );
      return;
    }
    showV2Snack(context, message, tone: V2Tone.ok);
    await _load(silent: true);
  }

  Future<String?> _save(Uint8List bytes) {
    const fileName = 'secretbase-personal-history.zip';
    final saver = widget.saver;
    if (saver != null) return saver(fileName, bytes);
    return FilePicker.saveFile(
      dialogTitle: '개인 보관함 내보내기',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      bytes: bytes,
    );
  }

  Future<void> _exportAll() async {
    if (_export == _ExportStatus.running) return;
    setState(() => _export = _ExportStatus.running);
    try {
      final response = await _client.get(
        Uri.parse('${_auth.baseUrl}/api/history/export'),
        headers: _headers,
      );
      if (response.statusCode != 200) throw const FormatException();
      final path = await _save(response.bodyBytes);
      if (!mounted) return;
      // Web downloads silently (null path); elsewhere null means cancelled.
      setState(
        () => _export = (path == null && !kIsWeb)
            ? _ExportStatus.cancelled
            : _ExportStatus.done,
      );
    } catch (_) {
      if (mounted) setState(() => _export = _ExportStatus.failed);
    }
  }

  String _momentTitle(Map<String, dynamic> moment) {
    final caption = '${moment['caption'] ?? ''}'.trim();
    if (caption.isNotEmpty) return caption;
    return switch (moment['media_type']) {
      'video' => '영상으로 남긴 순간',
      'text' => '글로 남긴 순간',
      _ => '사진으로 남긴 순간',
    };
  }

  String? _dateLabel(Map<String, dynamic> item) {
    for (final key in const ['captured_at', 'taken_at', 'visit_date']) {
      final parsed = DateTime.tryParse('${item[key] ?? ''}');
      if (parsed != null) {
        final local = parsed.isUtc ? parsed.toLocal() : parsed;
        return '${local.year}년 ${local.month}월 ${local.day}일';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Builder(
        builder: (context) {
          final busy = _export == _ExportStatus.running;
          return Scaffold(
            appBar: V2Header(
              title: '개인 보관함',
              actions: [
                V2IconButton(
                  icon: V2Icons.download,
                  tooltip: 'ZIP 파일로 내보내기',
                  onPressed: busy || _failure != _Failure.none || _loading
                      ? null
                      : _exportAll,
                ),
              ],
            ),
            body: SafeArea(child: _body(context)),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(V2Space.page),
        child: V2SkeletonList(count: 4),
      );
    }
    switch (_failure) {
      case _Failure.offline:
        return V2ErrorState.offline(retryLabel: '다시 불러오기', onRetry: _load);
      case _Failure.server:
        return V2ErrorState(
          title: '개인 보관함을 불러오지 못했어요',
          retryLabel: '다시 불러오기',
          onRetry: _load,
        );
      case _Failure.locked:
        return const V2EmptyState(
          icon: V2Icons.lock,
          title: '지금은 닫혀 있어요',
          body:
              '상대와 연결된 동안에는 개인 보관함을 열 수 없어요. '
              '기록은 지워지지 않고, 연결이 끝나면 다시 볼 수 있어요.',
        );
      case _Failure.none:
        break;
    }

    final empty = _moments.isEmpty && _pins.isEmpty;
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          V2Space.page,
          V2Space.x2,
          V2Space.page,
          V2Space.x8,
        ),
        children: [
          _guide(context),
          _exportStatus(),
          if (empty)
            _empty()
          else ...[
            V2Section(
              title: '내 기록',
              child: _moments.isEmpty
                  ? const _EmptyLine('보관된 기록이 없어요.')
                  : V2List(
                      children: [
                        for (final moment in _moments) _momentTile(moment),
                      ],
                    ),
            ),
            V2Section(
              title: '내 장소',
              child: _pins.isEmpty
                  ? const _EmptyLine('보관된 장소가 없어요.')
                  : V2List(children: [for (final pin in _pins) _pinTile(pin)]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _guide(BuildContext context) {
    final p = V2Palette.of(context);
    return V2Card(
      variant: V2CardVariant.soft,
      padding: const EdgeInsets.all(V2Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const V2Art(icon: V2Icons.lock, size: 48, tone: V2Tone.sage),
              const SizedBox(width: V2Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '나만 볼 수 있는 보관함이에요',
                      style: V2Text.bodyStrong.copyWith(color: p.ink),
                    ),
                    const SizedBox(height: V2Space.x1),
                    Text(
                      '연결하기 전이나 연결이 끝난 뒤에 내가 남긴 기록이 모여요. '
                      '상대에게는 보이지 않아요.',
                      style: V2Text.cap.copyWith(color: p.sub),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: V2Space.x3),
          Text(
            '상대와 연결하는 동안에는 보관함이 잠기고, 기록은 지워지지 않아요. '
            'ZIP 파일로 내려받아 따로 보관할 수도 있어요.',
            style: V2Text.cap.copyWith(color: p.sub),
          ),
          if (!(_moments.isEmpty && _pins.isEmpty)) ...[
            const SizedBox(height: V2Space.x3),
            V2Button(
              label: 'ZIP으로 내보내기',
              icon: V2Icons.download,
              variant: V2ButtonVariant.soft,
              size: V2ButtonSize.sm,
              loading: _export == _ExportStatus.running,
              onPressed: _exportAll,
            ),
          ],
        ],
      ),
    );
  }

  Widget _exportStatus() {
    switch (_export) {
      case _ExportStatus.idle:
      case _ExportStatus.cancelled:
        return const SizedBox.shrink();
      case _ExportStatus.running:
        return Padding(
          padding: const EdgeInsets.only(top: V2Space.x3),
          child: Semantics(
            liveRegion: true,
            child: const V2Banner(
              tone: V2BannerTone.info,
              title: '내보내는 중이에요',
              message: '사진과 영상이 많으면 시간이 걸려요. 잠시만 기다려 주세요.',
            ),
          ),
        );
      case _ExportStatus.done:
        return Padding(
          padding: const EdgeInsets.only(top: V2Space.x3),
          child: V2Banner(
            tone: V2BannerTone.ok,
            title: '내보냈어요',
            message: kIsWeb
                ? '다운로드 폴더에서 ZIP 파일을 확인해 주세요.'
                : '선택한 위치에 ZIP 파일을 저장했어요.',
            onDismiss: () => setState(() => _export = _ExportStatus.idle),
          ),
        );
      case _ExportStatus.failed:
        return Padding(
          padding: const EdgeInsets.only(top: V2Space.x3),
          child: V2Banner(
            tone: V2BannerTone.err,
            title: '내보내지 못했어요',
            message: '연결 상태를 확인한 뒤 다시 시도해 주세요.',
            actionLabel: '다시 시도',
            onAction: _exportAll,
          ),
        );
    }
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.only(top: V2Space.x6),
      child: V2EmptyState(
        illustration: const V2SceneIllustration(V2Scene.letter),
        title: '보관된 기록이 없어요',
        body:
            '연결하기 전에 남긴 기록과 장소가 있으면 여기에 모여요. '
            '나만 볼 수 있어서 편하게 남겨도 돼요.',
        actionLabel: widget.onCreateRecord == null ? null : '첫 기록 남기기',
        onAction: widget.onCreateRecord,
      ),
    );
  }

  Widget _momentTile(Map<String, dynamic> moment) {
    final id = _id(moment);
    final title = _momentTitle(moment);
    final subtitle = [
      if (moment['linked_place_name'] != null) '${moment['linked_place_name']}',
      ?_dateLabel(moment),
    ].join(' · ');
    return _RecordRow(
      key: ValueKey('moment-${moment['id']}'),
      leading: _Thumb(
        url: _mediaUrl(moment['media_url']),
        mediaType: '${moment['media_type'] ?? 'image'}',
        seed: moment['id'],
      ),
      title: title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      trailing: _deleteButton('moments', id, moment, '$title 삭제'),
    );
  }

  Widget _pinTile(Map<String, dynamic> pin) {
    final id = _id(pin);
    final name = '${pin['place_name'] ?? '장소'}';
    final memo = '${pin['memo'] ?? ''}'.trim();
    return _RecordRow(
      key: ValueKey('pin-${pin['id']}'),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: V2ToneColors.of(V2Tone.sage).soft,
          borderRadius: BorderRadius.circular(V2Radius.ctl),
        ),
        alignment: Alignment.center,
        child: Icon(
          V2Icons.location,
          size: 22,
          color: V2ToneColors.of(V2Tone.sage).text,
        ),
      ),
      title: name,
      subtitle: memo.isEmpty ? null : memo,
      trailing: _deleteButton('pins', id, pin, '$name 삭제'),
    );
  }

  Widget _deleteButton(
    String kind,
    int? id,
    Map<String, dynamic> item,
    String tooltip,
  ) {
    if (_deleting.contains('$kind/$id')) {
      return const SizedBox(
        width: V2Space.tap,
        height: V2Space.tap,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    return V2IconButton(
      icon: V2Icons.delete,
      tooltip: tooltip,
      onPressed: id == null ? null : () => _confirmDelete(kind, item),
    );
  }

  String? _mediaUrl(Object? raw) {
    final url = raw == null ? '' : '$raw'.trim();
    if (url.isEmpty) return null;
    return url.startsWith('http') ? url : '${_auth.baseUrl}$url';
  }
}

/// List row whose text is one screen-reader node and whose trailing delete
/// button stays a separate, focusable button (V2ListTile would merge them).
class _RecordRow extends StatelessWidget {
  const _RecordRow({
    super.key,
    required this.leading,
    required this.title,
    required this.trailing,
    this.subtitle,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ExcludeSemantics(child: leading),
            const SizedBox(width: 12),
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: V2Text.bodyStrong.copyWith(color: p.ink),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: V2Text.cap.copyWith(color: p.sub),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: V2Space.x2),
      child: Text(text, style: V2Text.body.copyWith(color: p.sub)),
    );
  }
}

/// 44px thumbnail: the photo, or a placeholder for videos/text/broken files.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.url,
    required this.mediaType,
    required this.seed,
  });

  final String? url;
  final String mediaType;
  final Object? seed;

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    final placeholder = SizedBox(
      width: _size,
      height: _size,
      child: V2PhotoPlaceholder(
        seed: seed,
        aspectRatio: 1,
        icon: mediaType == 'video'
            ? V2Icons.video
            : mediaType == 'text'
            ? V2Icons.text
            : V2Icons.image,
        radius: V2Radius.ctl,
      ),
    );
    if (url == null || mediaType != 'image') return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(V2Radius.ctl),
      child: Image.network(
        url!,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        cacheWidth: 120,
        excludeFromSemantics: true,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
        errorBuilder: (context, error, stack) => placeholder,
      ),
    );
  }
}
