import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/afterglow_api.dart';
import '../../../v2/v2.dart';
import '../afterglow_section.dart';
import 'map_api.dart';
import 'map_logic.dart';

// ── Add place (mini sheet) ──────────────────────────────────────────────────

class AddPlaceResult {
  final String name;
  final String category;
  final String status; // visited | wishlist
  const AddPlaceResult(this.name, this.category, this.status);
}

/// 장소 추가 미니 시트: 이름·분류만 채우고 두 버튼 중 하나로 저장.
class AddPlaceSheet extends StatefulWidget {
  final String initialName;
  final String initialCategory;
  final bool saving;
  final String? error;
  final Future<void> Function(AddPlaceResult result) onSave;

  const AddPlaceSheet({
    super.key,
    required this.initialName,
    required this.initialCategory,
    required this.onSave,
    this.saving = false,
    this.error,
  });

  @override
  State<AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends State<AddPlaceSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  late String _category = widget.initialCategory;
  bool _saving = false;
  String? _nameError;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit(String status) async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = '장소 이름을 적어 주세요');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(AddPlaceResult(name, _category, status));
    } catch (_) {
      if (mounted) {
        setState(() => _error = '장소를 저장하지 못했어요. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        V2TextField(
          key: const Key('map_add_name'),
          label: '장소 이름',
          hint: '예: 성수 카페',
          controller: _name,
          enabled: !_saving,
          error: _nameError,
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        const SizedBox(height: V2Space.x3),
        Wrap(
          spacing: V2Space.x2,
          runSpacing: V2Space.x2,
          children: [
            for (final c in mapCategories)
              V2Chip(
                label: '${mapCategoryEmojis[c]} $c',
                selected: _category == c,
                onTap: _saving ? null : () => setState(() => _category = c),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: V2Space.x3),
          V2Banner(tone: V2BannerTone.err, message: _error!),
        ],
        const SizedBox(height: V2Space.x4),
        Row(
          children: [
            Expanded(
              child: V2Button(
                key: const Key('map_add_visited'),
                label: '다녀왔어요',
                loading: _saving,
                onPressed: _saving ? null : () => _submit('visited'),
              ),
            ),
            const SizedBox(width: V2Space.x3),
            Expanded(
              child: V2Button(
                key: const Key('map_add_wishlist'),
                label: '가고 싶어요',
                variant: V2ButtonVariant.soft,
                onPressed: _saving ? null : () => _submit('wishlist'),
              ),
            ),
          ],
        ),
        const SizedBox(height: V2Space.x2),
        Text(
          '별점과 한마디는 나중에 남길 수 있어요',
          textAlign: TextAlign.center,
          style: V2Text.cap,
        ),
      ],
    );
  }
}

// ── Place detail (3 sections) ───────────────────────────────────────────────

class PlaceDetailBody extends StatefulWidget {
  final Map<String, dynamic> pin;
  final MapApi api;
  final List<Map<String, dynamic>> posts;
  final int? myUserId;
  final String myName;
  final String partnerName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback? onLeaveMoment;
  final VoidCallback onContributeAfterglow;
  final Future<void> Function(Map<String, dynamic> pin) onWriteNote;

  const PlaceDetailBody({
    super.key,
    required this.pin,
    required this.api,
    required this.posts,
    required this.myUserId,
    required this.myName,
    required this.partnerName,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
    required this.onLeaveMoment,
    required this.onContributeAfterglow,
    required this.onWriteNote,
  });

  @override
  State<PlaceDetailBody> createState() => _PlaceDetailBodyState();
}

class _PlaceDetailBodyState extends State<PlaceDetailBody> {
  List<Map<String, dynamic>>? _notes;
  bool _notesFailed = false;
  AfterglowState? _afterglow;
  bool _afterglowLoading = false;
  bool _moreOpen = false;

  Map<String, dynamic> get _pin => widget.pin;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNotes());
    if (pinStatus(_pin) == 'visited') unawaited(_loadAfterglow());
  }

  Future<void> _loadNotes() async {
    setState(() => _notesFailed = false);
    try {
      final list = await widget.api.fetchReviews(_pin['id']);
      if (mounted) setState(() => _notes = list);
    } catch (_) {
      if (mounted) {
        setState(() {
          _notes = const [];
          _notesFailed = true;
        });
      }
    }
  }

  Future<void> _loadAfterglow() async {
    final token = widget.api.auth.token;
    final id = placeIntForMap(_pin['id']);
    if (token == null || id == null) return;
    setState(() => _afterglowLoading = true);
    final api = AfterglowApi(baseUrl: widget.api.baseUrl, token: token);
    try {
      final state = await api.fetchForPin(id);
      if (mounted) setState(() => _afterglow = state);
    } catch (_) {
      // The section simply stays hidden.
    } finally {
      api.close();
      if (mounted) setState(() => _afterglowLoading = false);
    }
  }

  String _author(Object? userId) =>
      '$userId' == '${widget.myUserId}' ? widget.myName : widget.partnerName;

  Future<void> _deleteNote(Map<String, dynamic> note) async {
    try {
      await widget.api.deleteReview(_pin['id'], note['id']);
      await _loadNotes();
    } catch (_) {
      if (mounted) showV2Snack(context, '한마디를 지우지 못했어요', tone: V2Tone.err);
    }
  }

  String _mediaUrl(String raw) {
    final url = raw.trim();
    if (url.isEmpty) return '';
    return url.startsWith('http') ? url : '${widget.api.baseUrl}$url';
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final visited = pinStatus(_pin) == 'visited';
    final category = '${_pin['category'] ?? '기타'}';
    final rating = placeIntForMap(_pin['rating']) ?? 0;
    final date = formattedDate(_pin['visit_date']);
    final tags = extractPinTags(_pin);
    final memo = cleanPinMemo(_pin['memo']);
    final photo = _mediaUrl('${_pin['media_url'] ?? ''}');
    final linked = linkedSetlogPostsForMap(_pin, widget.posts);
    final creator = _author(_pin['user_id']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. 요약
        Wrap(
          spacing: V2Space.x2,
          runSpacing: V2Space.x2,
          children: [
            V2Chip(
              label: visited ? '다녀온 곳' : '가고 싶은 곳',
              tone: visited ? V2Tone.ok : V2Tone.lilac,
              icon: visited ? V2Icons.ok : V2Icons.heartOutline,
            ),
            V2Chip(label: '${mapCategoryEmojis[category] ?? '📍'} $category'),
            if (date != null && visited) V2Chip(label: date),
          ],
        ),
        if (rating > 0) ...[
          const SizedBox(height: V2Space.x2),
          Semantics(
            label: '별점 5점 중 $rating점',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      V2Icons.star,
                      size: 20,
                      color: i <= rating ? V2Colors.honey : p.line2,
                    ),
                ],
              ),
            ),
          ),
        ],
        if (photo.isNotEmpty) ...[
          const SizedBox(height: V2Space.x3),
          ClipRRect(
            borderRadius: BorderRadius.circular(V2Radius.card),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => V2PhotoPlaceholder(
                  seed: _pin['id'] ?? 0,
                  aspectRatio: 16 / 9,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: V2Space.x2),
        Text(
          '$creator${_josaI(creator)} 남겼어요',
          style: V2Text.cap.copyWith(color: p.sub),
        ),

        // 2. 우리 이야기
        const SizedBox(height: V2Space.x5),
        Semantics(
          header: true,
          child: Text('우리 이야기', style: V2Text.head.copyWith(color: p.ink)),
        ),
        const SizedBox(height: V2Space.x3),
        if (memo.isNotEmpty || tags.isNotEmpty)
          V2Card(
            variant: V2CardVariant.soft,
            padding: const EdgeInsets.all(V2Space.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tags.isNotEmpty)
                  Wrap(
                    spacing: V2Space.x2,
                    runSpacing: V2Space.x1,
                    children: [
                      for (final t in tags)
                        V2Chip(label: '#$t', tone: V2Tone.rose),
                    ],
                  ),
                if (memo.isNotEmpty) ...[
                  if (tags.isNotEmpty) const SizedBox(height: V2Space.x2),
                  Text(memo, style: V2Text.body.copyWith(color: p.ink)),
                ],
              ],
            ),
          ),
        const SizedBox(height: V2Space.x3),
        _NotesBlock(
          notes: _notes,
          failed: _notesFailed,
          authorOf: (n) => _author(n['user_id']),
          isMine: (n) => '${n['user_id']}' == '${widget.myUserId}',
          mediaUrl: _mediaUrl,
          onRetry: _loadNotes,
          onDelete: _deleteNote,
          onWrite: () async {
            await widget.onWriteNote(_pin);
            if (mounted) await _loadNotes();
          },
        ),
        const SizedBox(height: V2Space.x3),
        _MemoriesBlock(
          posts: linked,
          baseUrl: widget.api.baseUrl,
          onLeaveMoment: widget.onLeaveMoment,
        ),
        if (visited && (_afterglowLoading || _afterglow != null)) ...[
          const SizedBox(height: V2Space.x3),
          V2Section(
            title: '우리의 여운',
            child: _afterglowLoading && _afterglow == null
                ? const V2SkeletonCard()
                : AfterglowSection(
                    state: _afterglow!,
                    baseUrl: widget.api.baseUrl,
                    currentUserId: widget.myUserId,
                    onContribute: widget.onContributeAfterglow,
                  ),
          ),
        ],

        // 3. 더보기
        const SizedBox(height: V2Space.x4),
        Semantics(
          button: true,
          expanded: _moreOpen,
          label: '더 보기',
          onTap: () => setState(() => _moreOpen = !_moreOpen),
          child: ExcludeSemantics(
            child: InkWell(
              key: const Key('map_detail_more'),
              onTap: () => setState(() => _moreOpen = !_moreOpen),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: V2Space.tap),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '더 보기',
                        style: V2Text.bodyStrong.copyWith(color: p.ink),
                      ),
                    ),
                    Icon(
                      _moreOpen ? Icons.expand_less_rounded : V2Icons.expand,
                      color: p.sub,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_moreOpen)
          V2List(
            children: [
              V2ListTile(
                key: const Key('map_detail_share'),
                icon: V2Icons.share,
                title: '장소 복사해서 보내기',
                onTap: widget.onShare,
              ),
              V2ListTile(
                key: const Key('map_detail_edit'),
                icon: V2Icons.edit,
                title: '고치기',
                onTap: widget.onEdit,
              ),
              V2ListTile(
                key: const Key('map_detail_delete'),
                icon: V2Icons.delete,
                title: '지우기',
                destructive: true,
                onTap: widget.onDelete,
              ),
            ],
          ),
      ],
    );
  }

  String _josaI(String word) {
    if (word.isEmpty) return '이';
    final c = word.runes.last;
    if (c < 0xAC00 || c > 0xD7A3) return '가';
    return (c - 0xAC00) % 28 != 0 ? '이' : '가';
  }
}

class _NotesBlock extends StatelessWidget {
  final List<Map<String, dynamic>>? notes;
  final bool failed;
  final String Function(Map<String, dynamic>) authorOf;
  final bool Function(Map<String, dynamic>) isMine;
  final String Function(String) mediaUrl;
  final VoidCallback onRetry;
  final Future<void> Function(Map<String, dynamic>) onDelete;
  final VoidCallback onWrite;

  const _NotesBlock({
    required this.notes,
    required this.failed,
    required this.authorOf,
    required this.isMine,
    required this.mediaUrl,
    required this.onRetry,
    required this.onDelete,
    required this.onWrite,
  });

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '둘의 한마디',
                style: V2Text.bodyStrong.copyWith(color: p.ink),
              ),
            ),
            V2Button(
              key: const Key('map_note_write'),
              label: '한마디 남기기',
              icon: V2Icons.edit,
              variant: V2ButtonVariant.soft,
              size: V2ButtonSize.sm,
              fullWidth: false,
              onPressed: onWrite,
            ),
          ],
        ),
        const SizedBox(height: V2Space.x2),
        if (notes == null)
          const V2SkeletonLine(width: 160)
        else if (failed)
          V2Banner(
            tone: V2BannerTone.warn,
            message: '한마디를 불러오지 못했어요',
            actionLabel: '다시 시도',
            onAction: onRetry,
          )
        else if (notes!.isEmpty)
          Text('아직 남긴 한마디가 없어요', style: V2Text.cap.copyWith(color: p.sub))
        else
          for (final n in notes!)
            Padding(
              padding: const EdgeInsets.only(bottom: V2Space.x2),
              child: V2Card(
                variant: V2CardVariant.soft,
                padding: const EdgeInsets.fromLTRB(
                  V2Space.x4,
                  V2Space.x3,
                  V2Space.x2,
                  V2Space.x3,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authorOf(n),
                            style: V2Text.label.copyWith(color: p.sub),
                          ),
                          if ('${n['content'] ?? ''}'.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '${n['content']}',
                                style: V2Text.body.copyWith(color: p.ink),
                              ),
                            ),
                          if (mediaUrl('${n['media_url'] ?? ''}').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: V2Space.x2),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  V2Radius.ctl,
                                ),
                                child: Image.network(
                                  mediaUrl('${n['media_url']}'),
                                  height: 140,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isMine(n))
                      V2IconButton(
                        icon: V2Icons.close,
                        tooltip: '한마디 지우기',
                        onPressed: () => onDelete(n),
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _MemoriesBlock extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final String baseUrl;
  final VoidCallback? onLeaveMoment;
  const _MemoriesBlock({
    required this.posts,
    required this.baseUrl,
    required this.onLeaveMoment,
  });

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('이 장소의 기록', style: V2Text.bodyStrong.copyWith(color: p.ink)),
        const SizedBox(height: V2Space.x2),
        if (posts.isNotEmpty)
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: posts.length.clamp(0, 12),
              separatorBuilder: (_, _) => const SizedBox(width: V2Space.x2),
              itemBuilder: (_, i) {
                final post = posts[i];
                final raw = '${post['media_url'] ?? ''}'.trim();
                final url = raw.isEmpty
                    ? ''
                    : (raw.startsWith('http') ? raw : '$baseUrl$raw');
                final isImage = url.isNotEmpty && post['media_type'] == 'image';
                return ClipRRect(
                  borderRadius: BorderRadius.circular(V2Radius.ctl),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: isImage
                        ? Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                V2PhotoPlaceholder(seed: post['id'] ?? i),
                          )
                        : Container(
                            color: p.soft2,
                            padding: const EdgeInsets.all(V2Space.x2),
                            alignment: Alignment.center,
                            child: Text(
                              '${post['caption'] ?? ''}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: V2Text.label.copyWith(color: p.sub),
                            ),
                          ),
                  ),
                );
              },
            ),
          )
        else
          Text(
            '아직 이 장소에서 남긴 기록이 없어요',
            style: V2Text.cap.copyWith(color: p.sub),
          ),
        if (onLeaveMoment != null) ...[
          const SizedBox(height: V2Space.x2),
          V2Button(
            key: const Key('map_leave_moment'),
            label: '이 장소에서 순간 남기기',
            icon: V2Icons.camera,
            variant: V2ButtonVariant.soft,
            size: V2ButtonSize.sm,
            onPressed: onLeaveMoment,
          ),
        ],
      ],
    );
  }
}

// ── Edit place ──────────────────────────────────────────────────────────────

class EditPlaceResult {
  final String memo;
  final List<String> tags;
  final int rating;
  final DateTime date;
  final XFile? newImage;
  final bool removeImage;
  const EditPlaceResult({
    required this.memo,
    required this.tags,
    required this.rating,
    required this.date,
    this.newImage,
    this.removeImage = false,
  });
}

class EditPlaceSheet extends StatefulWidget {
  final Map<String, dynamic> pin;
  final String baseUrl;
  final Future<void> Function(EditPlaceResult) onSave;
  const EditPlaceSheet({
    super.key,
    required this.pin,
    required this.baseUrl,
    required this.onSave,
  });

  @override
  State<EditPlaceSheet> createState() => _EditPlaceSheetState();
}

class _EditPlaceSheetState extends State<EditPlaceSheet> {
  late final _memo = TextEditingController(
    text: cleanPinMemo(widget.pin['memo']),
  );
  late int _rating = placeIntForMap(widget.pin['rating']) ?? 0;
  late DateTime _date =
      parseDateString(widget.pin['visit_date']) ?? DateTime.now();
  late final Set<String> _tags = {...extractPinTags(widget.pin)};
  XFile? _image;
  bool _removeImage = false;
  bool _saving = false;
  String? _error;

  bool get _visited => pinStatus(widget.pin) == 'visited';
  bool get _hasPhoto =>
      '${widget.pin['media_url'] ?? ''}'.trim().isNotEmpty && !_removeImage;

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (f != null && mounted) {
        setState(() {
          _image = f;
          _removeImage = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '사진을 불러오지 못했어요');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(DateTime.now()) ? DateTime.now() : _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: '다녀온 날',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        EditPlaceResult(
          memo: _memo.text,
          tags: _tags.toList(),
          rating: _rating,
          date: _date,
          newImage: _image,
          removeImage: _removeImage,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _error = '저장하지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        V2TextField(
          key: const Key('map_edit_memo'),
          label: '우리의 한마디',
          hint: '이 장소가 어땠는지 적어 보세요',
          controller: _memo,
          maxLines: 3,
          enabled: !_saving,
        ),
        const SizedBox(height: V2Space.x3),
        Text('이럴 때 좋았어요', style: V2Text.bodyStrong.copyWith(color: p.ink)),
        const SizedBox(height: V2Space.x2),
        Wrap(
          spacing: V2Space.x2,
          runSpacing: V2Space.x2,
          children: [
            for (final t in mapEmotionTags)
              V2Chip(
                label: t,
                selected: _tags.contains(t),
                onTap: _saving
                    ? null
                    : () => setState(
                        () =>
                            _tags.contains(t) ? _tags.remove(t) : _tags.add(t),
                      ),
              ),
          ],
        ),
        if (_visited) ...[
          const SizedBox(height: V2Space.x4),
          Text('별점', style: V2Text.bodyStrong.copyWith(color: p.ink)),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Semantics(
                  button: true,
                  label: '$i점',
                  selected: _rating == i,
                  onTap: () => setState(() => _rating = _rating == i ? 0 : i),
                  child: ExcludeSemantics(
                    child: InkWell(
                      onTap: () =>
                          setState(() => _rating = _rating == i ? 0 : i),
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: V2Space.tap,
                        height: V2Space.tap,
                        child: Icon(
                          V2Icons.star,
                          color: i <= _rating ? V2Colors.honey : p.line2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          V2ListTile(
            key: const Key('map_edit_date'),
            icon: V2Icons.calendar,
            tone: V2Tone.sky,
            title: '다녀온 날',
            subtitle: dateLabel(_date),
            onTap: _pickDate,
          ),
        ],
        const SizedBox(height: V2Space.x3),
        Row(
          children: [
            Expanded(
              child: V2Button(
                label: _image != null
                    ? '사진을 골랐어요'
                    : _hasPhoto
                    ? '사진 바꾸기'
                    : '사진 넣기',
                icon: V2Icons.gallery,
                variant: V2ButtonVariant.soft,
                size: V2ButtonSize.sm,
                onPressed: _saving ? null : _pickImage,
              ),
            ),
            if (_hasPhoto || _image != null) ...[
              const SizedBox(width: V2Space.x2),
              Expanded(
                child: V2Button(
                  label: '사진 빼기',
                  variant: V2ButtonVariant.text,
                  size: V2ButtonSize.sm,
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _image = null;
                          _removeImage = true;
                        }),
                ),
              ),
            ],
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: V2Space.x3),
          V2Banner(tone: V2BannerTone.err, message: _error!),
        ],
        const SizedBox(height: V2Space.x4),
        V2Button(
          key: const Key('map_edit_save'),
          label: '저장하기',
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

// ── 한마디 쓰기 ─────────────────────────────────────────────────────────────

class NoteComposeSheet extends StatefulWidget {
  final Future<void> Function(String content, XFile? image) onSubmit;
  const NoteComposeSheet({super.key, required this.onSubmit});

  @override
  State<NoteComposeSheet> createState() => _NoteComposeSheetState();
}

class _NoteComposeSheetState extends State<NoteComposeSheet> {
  final _text = TextEditingController();
  XFile? _image;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _text.text.trim();
    if (content.isEmpty && _image == null) {
      setState(() => _error = '한마디나 사진을 남겨 주세요');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(content, _image);
    } catch (_) {
      if (mounted) setState(() => _error = '저장하지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        V2TextField(
          key: const Key('map_note_field'),
          label: '한마디',
          hint: '둘만 볼 수 있어요',
          controller: _text,
          maxLines: 3,
          enabled: !_sending,
          error: _error,
        ),
        const SizedBox(height: V2Space.x3),
        V2Button(
          label: _image == null ? '사진 넣기' : '사진을 골랐어요',
          icon: V2Icons.gallery,
          variant: V2ButtonVariant.soft,
          size: V2ButtonSize.sm,
          onPressed: _sending
              ? null
              : () async {
                  try {
                    final f = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                    );
                    if (f != null && mounted) setState(() => _image = f);
                  } catch (_) {
                    if (mounted) setState(() => _error = '사진을 불러오지 못했어요');
                  }
                },
        ),
        const SizedBox(height: V2Space.x3),
        V2Button(
          key: const Key('map_note_send'),
          label: '남기기',
          loading: _sending,
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}

// ── 여운 한 장 ──────────────────────────────────────────────────────────────

class AfterglowPickResult {
  final int postId;
  final String caption;
  final String? emotion;
  const AfterglowPickResult(this.postId, this.caption, this.emotion);
}

class AfterglowPickSheet extends StatefulWidget {
  final List<Map<String, dynamic>> candidates;
  final VoidCallback onLeaveMoment;
  const AfterglowPickSheet({
    super.key,
    required this.candidates,
    required this.onLeaveMoment,
  });

  @override
  State<AfterglowPickSheet> createState() => _AfterglowPickSheetState();
}

class _AfterglowPickSheetState extends State<AfterglowPickSheet> {
  int? _postId;
  String? _emotion;
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    if (widget.candidates.isEmpty) {
      return V2EmptyState(
        illustration: const V2SceneIllustration(V2Scene.photo),
        title: '이 날 남긴 순간이 아직 없어요',
        body: '이 장소에서 순간을 남기면 여운으로 모아 드릴게요.',
        actionLabel: '이 장소에서 순간 남기기',
        onAction: widget.onLeaveMoment,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('가장 기억에 남는 순간을 골라 주세요', style: V2Text.cap.copyWith(color: p.sub)),
        const SizedBox(height: V2Space.x2),
        V2List(
          children: [
            for (final post in widget.candidates)
              V2ListTile(
                icon: _postId == post['id']
                    ? V2Icons.ok
                    : (post['media_type'] == 'video'
                          ? V2Icons.video
                          : V2Icons.image),
                tone: _postId == post['id'] ? V2Tone.rose : V2Tone.neutral,
                title: '${post['caption'] ?? ''}'.trim().isEmpty
                    ? '말없이 남긴 순간'
                    : '${post['caption']}',
                showChevron: false,
                onTap: () =>
                    setState(() => _postId = placeIntForMap(post['id'])),
              ),
          ],
        ),
        const SizedBox(height: V2Space.x3),
        V2TextField(label: '한 줄 (선택)', controller: _caption, maxLength: 60),
        Wrap(
          spacing: V2Space.x2,
          runSpacing: V2Space.x2,
          children: [
            for (final t in mapEmotionTags.take(5))
              V2Chip(
                label: t,
                selected: _emotion == t,
                onTap: () =>
                    setState(() => _emotion = _emotion == t ? null : t),
              ),
          ],
        ),
        const SizedBox(height: V2Space.x4),
        V2Button(
          key: const Key('map_afterglow_save'),
          label: '여운 남기기',
          onPressed: _postId == null
              ? null
              : () => Navigator.pop(
                  context,
                  AfterglowPickResult(_postId!, _caption.text, _emotion),
                ),
        ),
        V2Button(
          label: '나중에 남기기',
          variant: V2ButtonVariant.text,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
