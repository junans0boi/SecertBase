import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../features/moment_loop/application/moment_loop_controller.dart';
import '../../../features/moment_loop/application/upload_outbox.dart';
import '../../../features/moment_loop/data/media_upload_service.dart'
    show MomentLoopException;
import '../../../features/moment_loop/data/moment_image_compressor.dart';
import '../../../features/moment_loop/data/video_shrinker.dart';
import '../../../features/moment_loop/domain/moment.dart';
import '../../../features/moment_loop/domain/photo_date.dart';
import '../../../v2/v2.dart';
import 'editor/editor_item.dart';
import 'editor/moment_editor_page.dart';
import 'moment_days.dart';
import 'moment_format.dart';
import 'moment_media.dart';
import 'moment_place_picker.dart';

enum _CaptureKind { photo, video }

/// A new photo/video record: pick → edit (caption, date, place in the
/// editor) → saved to the upload queue. Returns the record's day, or null
/// when nothing was posted.
abstract final class MomentPostFlow {
  /// Opens the album right away (inside the user's tap — mobile browsers
  /// only open a file chooser there). Call it before any `await`.
  static Future<List<XFile>> pickAlbum() =>
      ImagePicker().pickMultipleMedia(limit: momentMaxMedia);

  static Future<DateTime?> start(
    BuildContext context, {
    required MomentLoopController controller,
    required UploadOutbox outbox,
    required MomentStartSource source,
    Future<List<XFile>>? picked,
    Future<List<MomentMedia>> Function()? mediaPicker,
    DateTime? date,
    bool todayMoment = false,
    bool hasTodayMoment = false,
    MomentPlace? place,
    VideoShrinker? shrinker,
    Future<Duration?> Function(XFile file) probeDuration = probeVideoDuration,
    bool videoPreview = true,
  }) async {
    void toast(String msg) {
      if (context.mounted) showV2Snack(context, msg, tone: V2Tone.err);
    }

    final List<XFile> files;
    try {
      if (picked != null) {
        files = await picked;
      } else if (mediaPicker != null) {
        files = [
          for (final m in await mediaPicker())
            XFile.fromData(
              m.bytes,
              name: m.name,
              mimeType: m.isVideo ? 'video/mp4' : 'image/jpeg',
            ),
        ];
      } else if (source == MomentStartSource.camera) {
        if (!context.mounted) return null;
        final file = await _capture(context);
        files = file == null ? const [] : [file];
      } else {
        files = await pickAlbum();
      }
    } catch (_) {
      toast('사진을 불러오지 못했어요. 다시 시도해 주세요.');
      return null;
    }
    if (files.isEmpty || !context.mounted) return null;

    final shrink = shrinker ?? createVideoShrinker();
    final items = <EditorItem>[];
    String? issue;
    DateTime? photoDate;
    for (final file in files.take(momentMaxMedia)) {
      final video =
          isVideoName(file.name) ||
          isVideoName(file.path) ||
          (file.mimeType ?? '').startsWith('video/');
      if (video) {
        final duration = await probeDuration(file);
        final length = await file.length();
        if (!shrink.supported) {
          final problem = momentVideoTooLong(duration)
              ? MomentMediaIssue.tooLong
              : length > momentMaxBytes
              ? MomentMediaIssue.tooLarge
              : null;
          if (problem != null) {
            issue = momentMediaIssueLabel(problem);
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
      try {
        final raw = await file.readAsBytes();
        photoDate ??= await exifCaptureDate(raw);
        final bytes = compressMomentImage(raw);
        final problem = momentMediaIssue(isVideo: false, bytes: bytes.length);
        if (problem != null) {
          issue = momentMediaIssueLabel(problem);
          continue;
        }
        items.add(
          EditorItem.photo(
            file: file,
            name: _jpegName(file.name),
            photo: bytes,
          ),
        );
      } catch (_) {
        issue = '열 수 없는 사진이 있어 뺐어요';
      }
    }
    if (photoDate == null) {
      try {
        photoDate = dateOnly(await files.first.lastModified());
      } catch (_) {}
    }
    final today = dateOnly(DateTime.now());
    if (photoDate != null && dateOnly(photoDate).isAfter(today)) {
      photoDate = null;
    }
    if (!context.mounted) return null;
    if (items.isEmpty) {
      toast(issue ?? '올릴 수 있는 사진이 없어요');
      return null;
    }

    final day = dateOnly(date ?? photoDate ?? today);
    final options = MomentPostOptions(
      date: day,
      photoDate: photoDate,
      place: place,
      todayMoment: day == today && (todayMoment || !hasTodayMoment),
      pickPlace: (ctx, current) => showMomentPlacePicker(
        ctx,
        controller: controller,
        selectedId: current,
      ),
    );
    final outcome = await MomentEditorPage.open(
      context,
      items,
      shrinker: shrink,
      videoPreview: videoPreview,
      post: options,
    );
    if (outcome == null || !context.mounted) return null;
    if (outcome.media.isEmpty) {
      toast(outcome.issue ?? '올릴 수 있는 사진이 없어요');
      return null;
    }
    final post = outcome.post ?? options;
    final now = DateTime.now();
    final takenAt = dateOnly(post.date);
    final draft = MomentDraft(
      caption: post.caption,
      takenAt: takenAt,
      capturedAt: DateTime(
        takenAt.year,
        takenAt.month,
        takenAt.day,
        now.hour,
        now.minute,
        now.second,
      ),
      sessionId: UploadOutbox.newId(),
      todayMoment: post.todayMoment && post.isToday,
      mapPinId: post.place?.id,
      media: [
        for (final m in outcome.media)
          MomentMedia(name: m.name, bytes: m.bytes, isVideo: m.item.isVideo),
      ],
    );
    try {
      await outbox.enqueue(draft);
    } on MomentLoopException {
      toast('저장하지 못했어요. 다시 시도해 주세요.');
      return null;
    } catch (_) {
      toast('기기에 저장하지 못했어요. 저장 공간을 확인해 주세요.');
      return null;
    }
    if (outcome.issue != null && context.mounted) {
      showV2Snack(context, outcome.issue!, tone: V2Tone.warn);
    }
    return takenAt;
  }

  static Future<XFile?> _capture(BuildContext context) async {
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
    if (kind == null || !context.mounted) return null;
    if (!kIsWeb) {
      final choice = await showV2PermissionSheet(
        context,
        V2PermissionKind.camera,
      );
      if (choice != V2PermissionChoice.allow || !context.mounted) return null;
    }
    final picker = ImagePicker();
    try {
      return kind == _CaptureKind.photo
          ? await picker.pickImage(source: ImageSource.camera)
          : await picker.pickVideo(
              source: ImageSource.camera,
              maxDuration: momentMaxVideo,
            );
    } on PlatformException {
      if (!context.mounted) return null;
      final choice = await showV2PermissionSheet(
        context,
        V2PermissionKind.camera,
        denied: true,
      );
      if (choice == V2PermissionChoice.openSettings) {
        await Geolocator.openAppSettings();
      }
      return null;
    }
  }

  static String _jpegName(String name) {
    final stem = name.contains('.')
        ? name.substring(0, name.lastIndexOf('.'))
        : name;
    return '${stem.isEmpty ? 'photo' : stem}.jpg';
  }
}
