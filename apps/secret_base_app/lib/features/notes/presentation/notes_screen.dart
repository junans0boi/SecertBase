import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth_service.dart';
import '../../../v2/v2.dart';
import '../../moment_loop/data/moment_loop_repository.dart';
import '../../moment_loop/domain/moment.dart';
import '../application/notes_controller.dart';
import '../application/notes_events.dart';
import '../data/notes_repository.dart';
import '../domain/note.dart';
import 'note_format.dart';

/// 첨부로 고른 장소 또는 순간.
class NoteAttachmentPick {
  final int? mapPinId;
  final int? setlogPostId;
  final String label;
  const NoteAttachmentPick({
    this.mapPinId,
    this.setlogPostId,
    required this.label,
  });
}

/// 쪽지 대화 화면. 컨트롤러·이벤트·선택기는 테스트에서 바꿔 끼운다.
class NotesScreen extends StatefulWidget {
  final NotesController? controller;
  final NotesEventSource? events;
  final Future<NotePhoto?> Function()? pickPhoto;
  final Future<DateTime?> Function(BuildContext context)? pickOpenAt;
  final Future<NoteAttachmentPick?> Function(BuildContext context)?
  pickAttachment;
  final DateTime Function()? now;

  const NotesScreen({
    super.key,
    this.controller,
    this.events,
    this.pickPhoto,
    this.pickOpenAt,
    this.pickAttachment,
    this.now,
  });

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> with WidgetsBindingObserver {
  late final NotesController _controller;
  late final bool _ownsController;
  final _text = TextEditingController();
  VoidCallback? _unsubscribe;
  NotePhoto? _photo;
  DateTime? _openAt;
  NoteAttachmentPick? _attachment;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        NotesController(
          repository: HttpNotesRepository(AuthService().apiClient),
        );
    _controller.addListener(_onChanged);
    _unsubscribe = (widget.events ?? socketNotesEvents)(_controller.applyEvent);
    _controller.setVisible(true);
    _controller.load();
    _text.addListener(() => setState(() {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.setVisible(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) _controller.load();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unsubscribe?.call();
    _controller.removeListener(_onChanged);
    if (_ownsController) _controller.dispose();
    _text.dispose();
    super.dispose();
  }

  bool get _canSend =>
      _text.text.trim().isNotEmpty || _photo != null || _attachment != null;

  Future<void> _send() async {
    if (!_canSend) return;
    final body = _text.text;
    final photo = _photo;
    final openAt = _openAt;
    final attachment = _attachment;
    _text.clear();
    setState(() {
      _photo = null;
      _openAt = null;
      _attachment = null;
    });
    await _controller.send(
      body,
      openAt: openAt,
      photo: photo,
      mapPinId: attachment?.mapPinId,
      setlogPostId: attachment?.setlogPostId,
    );
  }

  Future<void> _choosePhoto() async {
    final picked = await (widget.pickPhoto ?? _defaultPickPhoto)();
    if (picked != null && mounted) setState(() => _photo = picked);
  }

  Future<NotePhoto?> _defaultPickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return null;
    return NotePhoto(bytes: await file.readAsBytes(), name: file.name);
  }

  Future<DateTime?> _defaultPickOpenAt(BuildContext context) async {
    final now = _now;
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _chooseOpenAt() async {
    final at = await (widget.pickOpenAt ?? _defaultPickOpenAt)(context);
    if (at == null || !mounted) return;
    if (!at.isAfter(_now)) {
      showV2Snack(context, '지금보다 나중 시각을 골라 주세요', tone: V2Tone.err);
      return;
    }
    setState(() => _openAt = at);
  }

  Future<void> _chooseAttachment() async {
    final pick = await (widget.pickAttachment ?? _defaultPickAttachment)(
      context,
    );
    if (pick != null && mounted) setState(() => _attachment = pick);
  }

  Future<NoteAttachmentPick?> _defaultPickAttachment(BuildContext context) {
    final repo = HttpMomentLoopRepository(apiClient: AuthService().apiClient);
    return showModalBottomSheet<NoteAttachmentPick>(
      context: context,
      showDragHandle: true,
      builder: (_) => _AttachmentSheet(repository: repo),
    );
  }

  Future<void> _showActions(Note note) async {
    if (note.status != NoteStatus.visible) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!note.mine)
              Padding(
                padding: const EdgeInsets.all(V2Space.x3),
                child: Wrap(
                  spacing: V2Space.x2,
                  children: [
                    for (final emoji in noteReactions)
                      TextButton(
                        key: ValueKey('react-$emoji'),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _controller.react(note, emoji);
                        },
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                  ],
                ),
              ),
            if (note.mine)
              ListTile(
                key: const ValueKey('delete-note'),
                leading: const Icon(V2Icons.delete),
                title: const Text('쪽지 지우기'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final ok = await _controller.delete(note);
                  if (!ok && mounted) {
                    showV2Snack(context, '지우지 못했어요', tone: V2Tone.err);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final items = <Widget>[
      for (final pending in _controller.pending.reversed)
        _PendingBubble(
          pending: pending,
          onRetry: () => _controller.retry(pending.clientRequestId),
          onDiscard: () => _controller.discardPending(pending.clientRequestId),
        ),
      for (final note in _controller.notes.reversed)
        _NoteBubble(
          note: note,
          now: _now,
          onLongPress: () => _showActions(note),
        ),
    ];
    return V2Theme(
      child: Scaffold(
        backgroundColor: V2Colors.bg,
        appBar: const V2Header(title: '쪽지', showBack: true),
        body: Column(
          children: [
            Expanded(child: _list(items, p)),
            _composer(p),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Widget> items, V2Palette p) {
    if (_controller.loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.loadFailed && items.isEmpty) {
      return V2ErrorState(
        title: '쪽지를 불러오지 못했어요',
        body: '잠시 후 다시 시도해 주세요.',
        retryLabel: '다시 불러오기',
        onRetry: _controller.load,
      );
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          '아직 쪽지가 없어요.\n첫 쪽지를 남겨 보세요.',
          textAlign: TextAlign.center,
          style: V2Text.body.copyWith(color: p.muted),
        ),
      );
    }
    return ListView(
      reverse: true,
      padding: const EdgeInsets.symmetric(
        horizontal: V2Space.page,
        vertical: V2Space.x3,
      ),
      children: [
        ...items,
        if (_controller.hasMore)
          TextButton(
            key: const ValueKey('load-more'),
            onPressed: _controller.loadMore,
            child: const Text('이전 쪽지 보기'),
          ),
      ],
    );
  }

  Widget _composer(V2Palette p) {
    final chips = <Widget>[
      if (_photo != null)
        _StagedChip(
          label: '사진 1장',
          onRemove: () => setState(() => _photo = null),
        ),
      if (_attachment != null)
        _StagedChip(
          label: _attachment!.label,
          onRemove: () => setState(() => _attachment = null),
        ),
      if (_openAt != null)
        _StagedChip(
          key: const ValueKey('staged-open-at'),
          label: '${formatNoteTime(_openAt!)}에 열려요',
          onRemove: () => setState(() => _openAt = null),
        ),
    ];
    return Material(
      color: p.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            V2Space.x2,
            V2Space.x2,
            V2Space.x2,
            V2Space.x2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (chips.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: V2Space.x2),
                  child: Wrap(
                    spacing: V2Space.x2,
                    runSpacing: V2Space.x1,
                    children: chips,
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  V2IconButton(
                    icon: V2Icons.image,
                    tooltip: '사진 첨부',
                    onPressed: _choosePhoto,
                  ),
                  V2IconButton(
                    icon: V2Icons.location,
                    tooltip: '장소·순간 첨부',
                    onPressed: _chooseAttachment,
                  ),
                  V2IconButton(
                    icon: Icons.schedule_rounded,
                    tooltip: '열리는 시각 정하기',
                    onPressed: _chooseOpenAt,
                  ),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('note-input'),
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: noteBodyMax,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: '쪽지를 남겨 보세요',
                        filled: true,
                        fillColor: p.soft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(V2Radius.ctl),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: V2Space.x3,
                          vertical: V2Space.x2,
                        ),
                      ),
                    ),
                  ),
                  V2IconButton(
                    icon: V2Icons.send,
                    tooltip: '보내기',
                    color: _canSend ? p.primary : null,
                    onPressed: _canSend ? _send : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StagedChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _StagedChip({super.key, required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return InputChip(
      label: Text(label, style: V2Text.cap),
      backgroundColor: p.primarySoft,
      onDeleted: onRemove,
      deleteButtonTooltipMessage: '빼기',
    );
  }
}

class _NoteBubble extends StatelessWidget {
  final Note note;
  final DateTime now;
  final VoidCallback onLongPress;
  const _NoteBubble({
    required this.note,
    required this.now,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final mine = note.mine;
    final scheduledMine =
        mine &&
        note.status == NoteStatus.visible &&
        note.openAt != null &&
        note.openAt!.isAfter(now);
    final children = <Widget>[];
    switch (note.status) {
      case NoteStatus.deleted:
        children.add(
          Text('삭제된 쪽지', style: V2Text.body.copyWith(color: p.muted)),
        );
      case NoteStatus.locked:
        children.add(
          Text(
            note.openAt == null
                ? '아직 열리지 않았어요'
                : '${formatNoteTime(note.openAt!)}에 열려요',
            style: V2Text.body.copyWith(color: p.sub),
          ),
        );
      case NoteStatus.visible:
        if (note.mediaUrl != null) {
          children.add(
            ClipRRect(
              borderRadius: BorderRadius.circular(V2Radius.ctl),
              child: Image.network(
                note.mediaUrl!.startsWith('http')
                    ? note.mediaUrl!
                    : '${AuthService().baseUrl}${note.mediaUrl}',
                width: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 220,
                  height: 80,
                  child: Center(child: Icon(V2Icons.image)),
                ),
              ),
            ),
          );
        }
        if (note.body != null && note.body!.isNotEmpty) {
          children.add(
            Text(note.body!, style: V2Text.body.copyWith(color: p.ink)),
          );
        }
        if (note.place != null) {
          children.add(
            _RefPreview(
              icon: V2Icons.location,
              ref: note.place!,
              fallback: '장소',
            ),
          );
        }
        if (note.moment != null) {
          children.add(
            _RefPreview(icon: V2Icons.image, ref: note.moment!, fallback: '순간'),
          );
        }
        if (scheduledMine) {
          children.add(
            Text(
              '${formatNoteTime(note.openAt!)}에 열려요',
              style: V2Text.cap.copyWith(color: p.sub),
            ),
          );
        }
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: V2Space.x1),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: onLongPress,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: V2Space.x3,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: mine ? p.primarySoft : p.soft,
                  borderRadius: BorderRadius.circular(V2Radius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(height: V2Space.x2),
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
            if (note.status == NoteStatus.visible &&
                (note.reaction != null || (mine && note.isRead)))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  [
                    if (note.reaction != null) note.reaction!,
                    if (mine && note.isRead) '읽음',
                  ].join(' '),
                  style: V2Text.cap.copyWith(color: p.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RefPreview extends StatelessWidget {
  final IconData icon;
  final NoteRef ref;
  final String fallback;
  const _RefPreview({
    required this.icon,
    required this.ref,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final title = ref.unavailable
        ? '$fallback을(를) 볼 수 없어요'
        : (ref.title?.isNotEmpty == true ? ref.title! : fallback);
    return Container(
      padding: const EdgeInsets.all(V2Space.x2),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(V2Radius.ctl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: p.sub),
          const SizedBox(width: V2Space.x2),
          Flexible(
            child: Text(
              title,
              style: V2Text.cap,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingBubble extends StatelessWidget {
  final PendingNote pending;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;
  const _PendingBubble({
    required this.pending,
    required this.onRetry,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final status = pending.error != null
        ? pending.error!
        : pending.failed
        ? '연결되면 다시 보낼게요'
        : '보내는 중…';
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: V2Space.x1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: V2Space.x3,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: p.primarySoft.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(V2Radius.card),
              ),
              child: Text(
                pending.body.isEmpty ? '첨부' : pending.body,
                style: V2Text.body.copyWith(color: p.ink),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status,
                  key: const ValueKey('pending-status'),
                  style: V2Text.cap.copyWith(
                    color: pending.error != null ? p.errText : p.muted,
                  ),
                ),
                if (pending.failed) ...[
                  TextButton(
                    key: const ValueKey('pending-retry'),
                    onPressed: onRetry,
                    child: const Text('다시 보내기'),
                  ),
                  TextButton(
                    key: const ValueKey('pending-discard'),
                    onPressed: onDiscard,
                    child: const Text('지우기'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentSheet extends StatelessWidget {
  final MomentLoopRepository repository;
  const _AttachmentSheet({required this.repository});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: SizedBox(
          height: 360,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: '장소'),
                  Tab(text: '순간'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    FutureBuilder<List<MomentMapPin>>(
                      future: repository.fetchMapPins(),
                      builder: (context, snap) => _items(
                        context,
                        snap,
                        (pin) => (
                          pin.name,
                          NoteAttachmentPick(mapPinId: pin.id, label: pin.name),
                        ),
                      ),
                    ),
                    FutureBuilder(
                      future: repository.fetchFeed(DateTime.now()),
                      builder: (context, snap) => _items(context, snap, (m) {
                        final label = (m.caption?.isNotEmpty == true
                            ? m.caption!
                            : (m.takenAt ?? '순간'));
                        return (
                          label,
                          NoteAttachmentPick(setlogPostId: m.id, label: label),
                        );
                      }),
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

  Widget _items<T>(
    BuildContext context,
    AsyncSnapshot<List<T>> snap,
    (String, NoteAttachmentPick) Function(T) map,
  ) {
    if (snap.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    final data = snap.data;
    if (data == null || data.isEmpty) {
      return const Center(child: Text('붙일 수 있는 항목이 없어요'));
    }
    return ListView(
      children: [
        for (final item in data)
          ListTile(
            title: Text(
              map(item).$1,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => Navigator.pop(context, map(item).$2),
          ),
      ],
    );
  }
}
