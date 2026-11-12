import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth_service.dart';
import '../../../features/moment_loop/application/moment_loop_controller.dart';
import '../../../features/moment_loop/application/upload_outbox.dart';
import '../../../features/moment_loop/data/moment_image_compressor.dart';
import '../../../features/moment_loop/data/media_upload_service.dart'
    show MomentLoopException;
import '../../../features/moment_loop/data/video_shrinker.dart';
import '../../../features/moment_loop/domain/moment.dart';
import '../../../features/moment_loop/domain/moment_edit.dart';
import '../../../features/moment_loop/domain/photo_date.dart';
import '../../../v2/v2.dart';
import 'editor/editor_item.dart';
import 'editor/moment_editor_page.dart';
import 'moment_format.dart';
import 'moment_media.dart';
import 'moment_place_picker.dart';
import 'moment_days.dart' show MomentStartSource;

/// One attachment in the composer: a new file or an existing post.
class PickedMoment {
  final String name;
  final Uint8List bytes;
  final bool isVideo;
  final Moment? post;
  final String? clientRequestId;
  final String key;

  /// What the editor started from (in memory only), for re-editing.
  final EditorItem? source;

  /// First frame for video tiles.
  final Uint8List? thumb;

  PickedMoment({
    required this.name,
    required this.bytes,
    required this.isVideo,
    this.post,
    this.clientRequestId,
    this.source,
    this.thumb,
  }) : key = post != null
           ? 'post_${post.id}'
           : clientRequestId ?? UploadOutbox.newId();

  factory PickedMoment.fromMedia(MomentMedia media) => PickedMoment(
    name: media.name,
    bytes: media.bytes,
    isVideo: media.isVideo,
    clientRequestId: media.clientRequestId,
  );

  factory PickedMoment.fromPost(Moment post) => PickedMoment(
    name: post.mediaUrl?.split('/').last ?? '기존 기록',
    bytes: Uint8List(0),
    isVideo: post.isVideo,
    post: post,
  );

  MomentMedia toMedia() => MomentMedia(
    name: name,
    bytes: bytes,
    isVideo: isVideo,
    clientRequestId: clientRequestId,
  );

  MomentEditItem toEditItem() => post != null
      ? MomentEditItem.existing(post!)
      : MomentEditItem.added(toMedia());
}

class _Place {
  final int? id;
  final String name;
  const _Place({required this.id, required this.name});
}

enum _CaptureKind { photo, video }

/// 기록 작성기: 촬영 · 갤러리 · 글만, 한 줄, 접힌 "더 보기".
class MomentComposerPage extends StatefulWidget {
  final MomentLoopController controller;
  final UploadOutbox outbox;
  final MomentDraft? initialDraft;
  final MomentEdit? edit;
  final String? draftId;
  final Future<List<MomentMedia>> Function()? mediaPicker;
  final bool startWithTodayMoment;

  /// Pre-linked place (예: 지도에서 "이 장소에서 순간 남기기").
  final int? initialPinId;
  final String? initialPinName;

  const MomentComposerPage({
    super.key,
    required this.controller,
    required this.outbox,
    this.initialDraft,
    this.edit,
    this.draftId,
    this.mediaPicker,
    this.startWithTodayMoment = true,
    this.initialPinId,
    this.initialPinName,
    this.startSource = MomentStartSource.none,
    this.initialDate,
    this.startPick,
    this.videoShrinker,
    this.probeDuration = probeVideoDuration,
    this.editorVideoPreview = true,
  });

  /// Opens the camera or the gallery right away (from 기록's
  /// "내 순간 올리기" sheet).
  final MomentStartSource startSource;

  /// Files a new record under this day (a day's empty row).
  final DateTime? initialDate;

  /// Files the user is already picking (web opens the album chooser inside
  /// the tap that led here; see `_openComposer`).
  final Future<List<XFile>>? startPick;

  /// Shrinks videos over 30MB before upload; defaults to the platform one.
  final VideoShrinker? videoShrinker;

  /// Reads a picked clip's length; injected in tests (no video plugin there).
  final Future<Duration?> Function(XFile file) probeDuration;

  /// Video playback and filmstrips in the editor (off in widget tests).
  final bool editorVideoPreview;

  @override
  State<MomentComposerPage> createState() => _MomentComposerPageState();
}

class _MomentComposerPageState extends State<MomentComposerPage> {
  final _caption = TextEditingController();
  final _captionFocus = FocusNode();
  final _imagePicker = ImagePicker();
  late final VideoShrinker _shrinker =
      widget.videoShrinker ?? createVideoShrinker();
  late final List<PickedMoment> _media;
  _Place? _place;
  bool _saving = false;
  bool _picking = false;
  bool _todayMoment = true;
  bool _moreOpen = false;
  bool _textOnly = false;
  String? _captionError;
  DateTime _date = dateOnly(DateTime.now());
  bool _dateTouched = false;
  ({String label, Future<void> Function() again})? _issue;

  bool get _editing => widget.edit != null;
  MomentDraft? get _initial => widget.initialDraft ?? widget.edit?.fields;
  bool get _dateLocked =>
      widget.edit?.original.any((p) => p.mediaEditLocked) == true;
  bool get _mediaLocked =>
      _dateLocked || (_editing && widget.edit!.fields.sessionId.isEmpty);
  bool get _isToday => _date == dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    if (widget.startSource == MomentStartSource.text) {
      _textOnly = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _captionFocus.requestFocus();
      });
    } else if (widget.startSource != MomentStartSource.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.startSource == MomentStartSource.camera) {
          unawaited(_capture());
        } else {
          unawaited(_addFromGallery());
        }
      });
    }
    final startPick = widget.startPick;
    if (startPick != null) unawaited(_takeStartPick(startPick));
    final initial = _initial;
    _media = widget.edit != null
        ? widget.edit!.items
              .map(
                (i) => i.post != null
                    ? PickedMoment.fromPost(i.post!)
                    : PickedMoment.fromMedia(i.media!),
              )
              .toList()
        : initial != null
        ? initial.media.map(PickedMoment.fromMedia).toList()
        : <PickedMoment>[];
    if (initial != null) {
      _caption.text = initial.caption;
      _date = dateOnly(initial.takenAt);
      _dateTouched = true;
      _todayMoment = initial.todayMoment;
      if (initial.mapPinId != null) {
        _place = _Place(
          id: initial.mapPinId,
          name: widget.edit?.original.first.linkedPlaceName ?? '연결한 장소',
        );
      }
    } else {
      _todayMoment = widget.startWithTodayMoment;
      final day = widget.initialDate;
      if (day != null) {
        _date = dateOnly(day);
        _dateTouched = true;
        if (!_isToday) _todayMoment = false;
      }
      if (widget.initialPinId != null) {
        _place = _Place(
          id: widget.initialPinId,
          name: widget.initialPinName ?? '연결한 장소',
        );
        _moreOpen = true;
      }
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    _captionFocus.dispose();
    super.dispose();
  }

  void _toast(String msg, {V2Tone tone = V2Tone.neutral}) {
    if (!mounted) return;
    showV2Snack(context, msg, tone: tone);
  }

  // ── Picking ────────────────────────────────────────────────────────────────

  Future<void> _addFromGallery() async {
    if (_mediaLocked || _saving || _picking) return;
    final remaining = momentMaxMedia - _media.length;
    if (remaining <= 0) return;
    _picking = true;
    try {
      if (widget.mediaPicker != null) {
        final picked = await widget.mediaPicker!();
        final items = picked.take(remaining).map((m) {
          if (m.isVideo) return PickedMoment.fromMedia(m);
          return PickedMoment.fromMedia(
            MomentMedia(
              name: _jpegName(m.name),
              bytes: compressMomentImage(m.bytes),
              isVideo: false,
              clientRequestId: m.clientRequestId,
            ),
          );
        });
        if (mounted) setState(() => _media.addAll(items));
        return;
      }
      final files = await _imagePicker.pickMultipleMedia(limit: remaining);
      if (files.isEmpty) return;
      await _ingest(files, again: _addFromGallery);
    } catch (_) {
      _toast('사진을 불러오지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
    } finally {
      _picking = false;
    }
  }

  // Deliberately not guarded by [_picking]: if the browser never answers,
  // the composer's own camera/album buttons must keep working.
  Future<void> _takeStartPick(Future<List<XFile>> pick) async {
    try {
      final files = await pick;
      if (!mounted || files.isEmpty) return;
      final remaining = momentMaxMedia - _media.length;
      if (remaining <= 0) return;
      await _ingest(files.take(remaining).toList(), again: _addFromGallery);
    } catch (_) {
      _toast('사진을 불러오지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
    }
  }

  Future<void> _capture() async {
    if (_mediaLocked || _saving || _picking) return;
    if (_media.length >= momentMaxMedia) return;
    final kind = await showV2Sheet<_CaptureKind>(
      context,
      title: '촬영',
      builder: (ctx) => V2List(
        children: [
          V2ListTile(
            key: const Key('moment_capture_photo'),
            icon: V2Icons.camera,
            title: '사진 찍기',
            onTap: () => Navigator.pop(ctx, _CaptureKind.photo),
          ),
          V2ListTile(
            key: const Key('moment_capture_video'),
            icon: V2Icons.video,
            tone: V2Tone.sky,
            title: '영상 찍기',
            subtitle: '1분까지 담을 수 있어요',
            onTap: () => Navigator.pop(ctx, _CaptureKind.video),
          ),
        ],
      ),
    );
    if (kind == null || !mounted) return;
    if (!kIsWeb) {
      final choice = await showV2PermissionSheet(
        context,
        V2PermissionKind.camera,
      );
      if (choice != V2PermissionChoice.allow || !mounted) return;
    }
    _picking = true;
    try {
      final XFile? file = kind == _CaptureKind.photo
          ? await _imagePicker.pickImage(source: ImageSource.camera)
          : await _imagePicker.pickVideo(
              source: ImageSource.camera,
              maxDuration: momentMaxVideo,
            );
      if (file == null) return;
      await _ingest([file], again: _capture);
    } on PlatformException {
      if (!mounted) return;
      final choice = await showV2PermissionSheet(
        context,
        V2PermissionKind.camera,
        denied: true,
      );
      if (choice == V2PermissionChoice.openSettings) {
        await Geolocator.openAppSettings();
      }
    } catch (_) {
      _toast('촬영한 파일을 불러오지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
    } finally {
      _picking = false;
    }
  }

  /// Reads what was picked, opens the editor, and adds what comes back.
  /// Clips that need cutting or shrinking are refused up front when this
  /// device has no encoder; the editor does the cutting and shrinking.
  Future<void> _ingest(
    List<XFile> files, {
    required Future<void> Function() again,
  }) async {
    final items = <EditorItem>[];
    DateTime? suggested;
    final wantsSuggestion = _media.isEmpty && !_dateTouched;
    ({String label, Future<void> Function() again})? issue;
    for (final file in files) {
      final video =
          isVideoName(file.name) ||
          isVideoName(file.path) ||
          (file.mimeType ?? '').startsWith('video/');
      if (video) {
        final duration = await widget.probeDuration(file);
        final length = await file.length();
        if (!_shrinker.supported) {
          final problem = momentVideoTooLong(duration)
              ? MomentMediaIssue.tooLong
              : length > momentMaxBytes
              ? MomentMediaIssue.tooLarge
              : null;
          if (problem != null) {
            issue = (label: momentMediaIssueLabel(problem), again: again);
            continue;
          }
        }
        items.add(
          EditorItem.video(
            file: file,
            name: file.name.isEmpty ? 'clip.mp4' : file.name,
            bytes: length,
            duration: duration,
          ),
        );
        continue;
      }
      final raw = await file.readAsBytes();
      if (wantsSuggestion && suggested == null && items.isEmpty) {
        suggested = await exifCaptureDate(raw);
      }
      final bytes = compressMomentImage(raw);
      final problem = momentMediaIssue(isVideo: false, bytes: bytes.length);
      if (problem != null) {
        issue = (label: momentMediaIssueLabel(problem), again: again);
        continue;
      }
      items.add(
        EditorItem.photo(file: file, name: _jpegName(file.name), photo: bytes),
      );
    }
    if (wantsSuggestion && suggested == null && files.isNotEmpty) {
      try {
        suggested = dateOnly(await files.first.lastModified());
      } catch (_) {}
    }
    if (!mounted) return;
    if (items.isEmpty) {
      setState(() => _issue = issue);
      return;
    }
    final outcome = await MomentEditorPage.open(
      context,
      items,
      shrinker: _shrinker,
      videoPreview: widget.editorVideoPreview,
    );
    if (!mounted) return;
    if (outcome == null) {
      if (issue != null) setState(() => _issue = issue);
      return;
    }
    if (outcome.issue != null) {
      issue = (label: outcome.issue!, again: again);
    }
    final added = outcome.media.map(_fromEdited).toList();
    setState(() {
      _issue = issue;
      final room = momentMaxMedia - _media.length;
      _media.addAll(added.take(room < 0 ? 0 : room));
      final today = dateOnly(DateTime.now());
      if (added.isNotEmpty &&
          suggested != null &&
          !suggested.isAfter(today) &&
          suggested != _date) {
        _date = suggested;
        if (suggested != today) _todayMoment = false;
      }
    });
  }

  PickedMoment _fromEdited(EditedMedia m) => PickedMoment(
    name: m.name,
    bytes: m.bytes,
    isVideo: m.item.isVideo,
    source: m.item,
    thumb: m.thumb,
  );

  /// Re-opens the editor for one tile (keeps its earlier edits).
  Future<void> _reedit(int index) async {
    if (_saving || _mediaLocked || index >= _media.length) return;
    final source = _media[index].source;
    if (source == null) return;
    final outcome = await MomentEditorPage.open(
      context,
      [source],
      shrinker: _shrinker,
      videoPreview: widget.editorVideoPreview,
    );
    if (!mounted || outcome == null) return;
    setState(() {
      if (outcome.media.isEmpty) {
        if (outcome.issue != null) {
          _issue = (label: outcome.issue!, again: () => _reedit(index));
        }
        return;
      }
      final i = _media.indexWhere((m) => identical(m.source, source));
      if (i < 0) return;
      _media[i] = _fromEdited(outcome.media.first);
    });
  }

  String _jpegName(String name) {
    final stem = name.contains('.')
        ? name.substring(0, name.lastIndexOf('.'))
        : name;
    return '${stem.isEmpty ? 'photo' : stem}.jpg';
  }

  void _reorder(int oldIndex, int newIndex) {
    if (_saving ||
        oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= _media.length) {
      return;
    }
    setState(() {
      final item = _media.removeAt(oldIndex);
      _media.insert(newIndex.clamp(0, _media.length), item);
    });
  }

  // ── Location ───────────────────────────────────────────────────────────────

  Future<void> _pickPlace() async {
    final picked = await showMomentPlacePicker(
      context,
      controller: widget.controller,
      selectedId: _place?.id,
    );
    if (!mounted || picked == null) return;
    setState(() {
      final place = picked.place;
      _place = picked.cleared || place == null
          ? null
          : _Place(id: place.id, name: place.name);
    });
  }

  // ── Date ───────────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: today,
      helpText: '기록 날짜',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = dateOnly(picked);
      _dateTouched = true;
      if (_date != today) _todayMoment = false;
    });
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_saving) return;
    final caption = _caption.text.trim();
    if (caption.isEmpty && _media.isEmpty) {
      setState(() => _captionError = '한 줄이나 사진을 남겨 주세요');
      _captionFocus.requestFocus();
      return;
    }
    setState(() {
      _saving = true;
      _captionError = null;
    });
    final now = DateTime.now();
    final at = DateTime(
      _date.year,
      _date.month,
      _date.day,
      now.hour,
      now.minute,
      now.second,
    );
    final sessionId = _initial?.sessionId ?? UploadOutbox.newId();
    try {
      final draft = MomentDraft(
        caption: caption,
        takenAt: _date,
        capturedAt: _editing ? _initial!.capturedAt : at,
        sessionId: sessionId,
        todayMoment: !_editing && _todayMoment && _isToday,
        mapPinId: _place?.id,
        tags: _initial?.tags ?? const ['#momentloop'],
        media: _media
            .where((m) => m.post == null)
            .map((m) => m.toMedia())
            .toList(),
      );
      if (widget.draftId != null) {
        await widget.outbox.replace(
          widget.draftId!,
          draft,
          editItems: _editing
              ? _media.map((m) => m.toEditItem()).toList()
              : null,
        );
      } else if (_editing) {
        await widget.outbox.enqueueEdit(
          MomentEdit(
            original: widget.edit!.original,
            fields: draft,
            items: _media.map((m) => m.toEditItem()).toList(),
          ),
        );
      } else {
        await widget.outbox.enqueue(draft);
      }
      if (mounted) Navigator.pop(context, _date);
    } on MomentLoopException catch (error) {
      _toast(switch (error.code) {
        'today_loop_date_locked' => '열린 오늘의 순간은 날짜를 바꿀 수 없어요',
        'today_loop_locked' => '열린 오늘의 순간은 사진을 추가·삭제할 수 없어요',
        'draft_busy' => '지금 올리는 중이에요. 끝난 뒤에 고쳐 주세요.',
        _ => '저장하지 못했어요. 쓴 내용은 그대로 남아 있어요.',
      }, tone: V2Tone.err);
    } catch (_) {
      _toast('기기에 저장하지 못했어요. 저장 공간을 확인해 주세요.', tone: V2Tone.err);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  String get _moreSummary => [
    _place?.name ?? '장소 없음',
    _isToday ? '오늘' : '${_date.month}월 ${_date.day}일',
    if (!_editing) _todayMoment && _isToday ? '오늘의 순간 켜짐' : '오늘의 순간 꺼짐',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final canAdd = _media.length < momentMaxMedia && !_mediaLocked && !_saving;
    final title = _editing
        ? '순간 고치기'
        : widget.draftId != null
        ? '임시저장 고치기'
        : '새 순간';
    return V2Theme(
      child: Scaffold(
        backgroundColor: p.bg,
        appBar: V2Header(title: title, showBack: true),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.page,
                    V2Space.x2,
                    V2Space.page,
                    V2Space.x6,
                  ),
                  children: [
                    if (_issue != null) ...[
                      V2Banner(
                        key: const Key('moment_media_issue'),
                        tone: V2BannerTone.err,
                        message: _issue!.label,
                        actionLabel: '다시 고르기',
                        onAction: () => unawaited(_issue!.again()),
                        onDismiss: () => setState(() => _issue = null),
                      ),
                      const SizedBox(height: V2Space.x3),
                    ],
                    if (_dateLocked)
                      const Padding(
                        padding: EdgeInsets.only(bottom: V2Space.x3),
                        child: V2Banner(
                          message:
                              '열린 오늘의 순간은 사진과 날짜를 바꿀 수 없어요. 글과 장소는 고칠 수 있어요.',
                        ),
                      ),
                    if (_media.isEmpty)
                      _Actions(
                        enabled: canAdd,
                        textOnly: _textOnly,
                        onCapture: _capture,
                        onGallery: _addFromGallery,
                        onTextOnly: () {
                          setState(() => _textOnly = true);
                          _captionFocus.requestFocus();
                        },
                      )
                    else
                      _MediaStrip(
                        media: _media,
                        locked: _mediaLocked,
                        saving: _saving,
                        canAdd: canAdd,
                        onReorder: _reorder,
                        onRemove: (i) => setState(() => _media.removeAt(i)),
                        onEdit: (i) => unawaited(_reedit(i)),
                        onAddCapture: _capture,
                        onAddGallery: _addFromGallery,
                      ),
                    const SizedBox(height: V2Space.x4),
                    V2TextField(
                      key: const Key('moment_caption_field'),
                      label: '한 줄',
                      hint: '오늘 남기고 싶은 장면을 적어 주세요',
                      controller: _caption,
                      focusNode: _captionFocus,
                      maxLength: momentCaptionMax,
                      enabled: !_saving,
                      error: _captionError,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        if (_captionError != null) {
                          setState(() => _captionError = null);
                        }
                      },
                    ),
                    const SizedBox(height: V2Space.x2),
                    _MoreCard(
                      open: _moreOpen,
                      summary: _moreSummary,
                      onToggle: () => setState(() => _moreOpen = !_moreOpen),
                      children: [
                        V2ListTile(
                          key: const Key('moment_place_tile'),
                          icon: V2Icons.location,
                          tone: V2Tone.sage,
                          title: '장소',
                          subtitle: _place?.name ?? '비밀지도 장소를 붙일 수 있어요',
                          trailing: _place == null
                              ? null
                              : V2IconButton(
                                  icon: V2Icons.close,
                                  tooltip: '장소 빼기',
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() => _place = null),
                                ),
                          onTap: _saving ? null : _pickPlace,
                        ),
                        V2ListTile(
                          key: const Key('moment_date_tile'),
                          icon: V2Icons.calendar,
                          tone: V2Tone.sky,
                          title: '날짜',
                          subtitle: _isToday ? '오늘' : longDate(_date),
                          onTap: _saving || _dateLocked ? null : _pickDate,
                        ),
                        if (!_editing)
                          V2ListTile(
                            icon: V2Icons.sparkle,
                            tone: V2Tone.honey,
                            title: '오늘의 순간',
                            subtitle: _isToday
                                ? '둘이 모두 남기면 함께 열려요'
                                : '오늘 날짜의 기록만 오늘의 순간이 될 수 있어요',
                            trailing: V2Toggle(
                              value: _todayMoment && _isToday,
                              semanticLabel: '오늘의 순간으로 남기기',
                              onChanged: _saving || !_isToday
                                  ? null
                                  : (v) => setState(() => _todayMoment = v),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  V2Space.page,
                  V2Space.x2,
                  V2Space.page,
                  V2Space.x3,
                ),
                child: V2Button(
                  key: const Key('moment_save'),
                  label: _editing || widget.draftId != null
                      ? '저장하기'
                      : '남기기 · 둘만 볼 수 있어요',
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final bool enabled;
  final bool textOnly;
  final VoidCallback onCapture;
  final VoidCallback onGallery;
  final VoidCallback onTextOnly;
  const _Actions({
    required this.enabled,
    required this.textOnly,
    required this.onCapture,
    required this.onGallery,
    required this.onTextOnly,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            key: const Key('moment_action_capture'),
            icon: V2Icons.camera,
            label: '촬영',
            tone: V2Tone.rose,
            onTap: enabled ? onCapture : null,
          ),
        ),
        const SizedBox(width: V2Space.x3),
        Expanded(
          child: _ActionTile(
            key: const Key('moment_action_gallery'),
            icon: V2Icons.gallery,
            label: '갤러리',
            tone: V2Tone.peach,
            onTap: enabled ? onGallery : null,
          ),
        ),
        const SizedBox(width: V2Space.x3),
        Expanded(
          child: _ActionTile(
            key: const Key('moment_action_text'),
            icon: V2Icons.text,
            label: '글만',
            tone: V2Tone.lilac,
            selected: textOnly,
            onTap: onTextOnly,
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final V2Tone tone;
  final bool selected;
  final VoidCallback? onTap;
  const _ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final c = V2ToneColors.of(tone);
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: Material(
        color: selected ? c.soft : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: V2Radius.cardAll,
          side: BorderSide(color: selected ? c.base : p.line, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: V2Radius.cardAll),
          child: SizedBox(
            height: 92,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.soft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: c.text, size: 24),
                ),
                const SizedBox(height: 6),
                Text(label, style: V2Text.bodyStrong.copyWith(color: p.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaStrip extends StatelessWidget {
  final List<PickedMoment> media;
  final bool locked;
  final bool saving;
  final bool canAdd;
  final void Function(int, int) onReorder;
  final void Function(int) onRemove;
  final void Function(int) onEdit;
  final VoidCallback onAddCapture;
  final VoidCallback onAddGallery;

  const _MediaStrip({
    required this.media,
    required this.locked,
    required this.saving,
    required this.canAdd,
    required this.onReorder,
    required this.onRemove,
    required this.onEdit,
    required this.onAddCapture,
    required this.onAddGallery,
  });

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final base = AuthService().baseUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 104,
          child: ReorderableListView.builder(
            key: const Key('moment_media_reorder_list'),
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            itemExtent: 104,
            itemCount: media.length,
            onReorderItem: locked ? (_, _) {} : onReorder,
            itemBuilder: (context, i) {
              final m = media[i];
              return Semantics(
                key: ValueKey('media_${m.key}'),
                label: '${m.isVideo ? '영상' : '사진'} ${i + 1}번',
                child: ReorderableDelayedDragStartListener(
                  key: ValueKey(m.key),
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(right: V2Space.x2),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(V2Radius.ctl),
                            child: m.isVideo && m.thumb != null
                                ? Image.memory(m.thumb!, fit: BoxFit.cover)
                                : m.isVideo
                                ? Container(
                                    color: p.soft2,
                                    child: Icon(V2Icons.video, color: p.sub),
                                  )
                                : m.post != null
                                ? Image.network(
                                    mediaUrlFor(base, m.post!.mediaUrl),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        V2PhotoPlaceholder(seed: m.post!.id),
                                  )
                                : Image.memory(m.bytes, fit: BoxFit.cover),
                          ),
                        ),
                        if (!locked && m.source != null)
                          Positioned.fill(
                            child: Semantics(
                              button: true,
                              label: '이 ${m.isVideo ? '영상' : '사진'} 편집',
                              onTap: saving ? null : () => onEdit(i),
                              child: ExcludeSemantics(
                                child: GestureDetector(
                                  key: Key('moment_media_edit_$i'),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: saving ? null : () => onEdit(i),
                                  child: Align(
                                    alignment: Alignment.bottomLeft,
                                    child: Container(
                                      margin: const EdgeInsets.all(6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: V2Colors.scrim,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            m.isVideo
                                                ? Icons.content_cut_rounded
                                                : V2Icons.edit,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            '편집',
                                            style: V2Text.cap.copyWith(
                                              color: Colors.white,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (!locked)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Semantics(
                              button: true,
                              label: '이 ${m.isVideo ? '영상' : '사진'} 빼기',
                              onTap: saving ? null : () => onRemove(i),
                              child: ExcludeSemantics(
                                child: InkWell(
                                  onTap: saving ? null : () => onRemove(i),
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Align(
                                      alignment: Alignment.topRight,
                                      child: Container(
                                        margin: const EdgeInsets.all(4),
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: V2Colors.scrim,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          V2Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (canAdd) ...[
          const SizedBox(height: V2Space.x2),
          Row(
            children: [
              Expanded(
                child: V2Button(
                  key: const Key('moment_add_capture'),
                  label: '촬영',
                  icon: V2Icons.camera,
                  variant: V2ButtonVariant.soft,
                  size: V2ButtonSize.sm,
                  onPressed: onAddCapture,
                ),
              ),
              const SizedBox(width: V2Space.x2),
              Expanded(
                child: V2Button(
                  key: const Key('moment_add_gallery'),
                  label: '갤러리',
                  icon: V2Icons.gallery,
                  variant: V2ButtonVariant.soft,
                  size: V2ButtonSize.sm,
                  onPressed: onAddGallery,
                ),
              ),
            ],
          ),
        ],
        if (!locked && media.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: V2Space.x2),
            child: Text('길게 눌러 순서를 바꿀 수 있어요', style: V2Text.cap),
          ),
      ],
    );
  }
}

class _MoreCard extends StatelessWidget {
  final bool open;
  final String summary;
  final VoidCallback onToggle;
  final List<Widget> children;
  const _MoreCard({
    required this.open,
    required this.summary,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          label: '더 보기, $summary',
          onTap: onToggle,
          child: ExcludeSemantics(
            child: InkWell(
              key: const Key('moment_more_toggle'),
              onTap: onToggle,
              borderRadius: BorderRadius.circular(V2Radius.ctl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: V2Space.tap),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: V2Space.x2),
                  child: Row(
                    children: [
                      Text(
                        '더 보기',
                        style: V2Text.bodyStrong.copyWith(color: p.ink),
                      ),
                      const SizedBox(width: V2Space.x2),
                      Expanded(
                        child: Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: V2Text.cap.copyWith(color: p.sub),
                        ),
                      ),
                      Icon(
                        open ? Icons.expand_less_rounded : V2Icons.expand,
                        color: p.sub,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (open) V2List(children: children),
      ],
    );
  }
}
