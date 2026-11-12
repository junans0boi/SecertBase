import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/upload_image.dart';
import '../../../features/moment_loop/domain/moment.dart';
import '../../../v2/v2.dart';
import 'moment_format.dart';
import 'moment_media.dart';

/// How a new record starts (from the + button, a day's empty row, …).
enum MomentStartSource { none, camera, gallery, text }

/// One day of 우리의 하루: my posts and the partner's posts, each in time
/// order.
class MomentDayPage {
  MomentDayPage(this.day, this.mine, this.theirs);

  final DateTime day;
  final List<Moment> mine;
  final List<Moment> theirs;

  bool get hasMine => mine.isNotEmpty;
  bool get hasTheirs => theirs.isNotEmpty;

  /// Everything that day, both of us, in time order (the day viewer).
  List<Moment> get all => [...mine, ...theirs]..sort(momentTimeOrder);

  int get count => mine.length + theirs.length;

  /// Linked place names that day, without repeats.
  List<String> get places => {
    for (final m in all)
      if ((m.linkedPlaceName ?? '').trim().isNotEmpty)
        m.linkedPlaceName!.trim(),
  }.toList();
}

/// Capture time first (when it was taken), then the order inside a post.
int momentTimeOrder(Moment a, Moment b) {
  final t = (a.capturedAt ?? a.takenAt ?? '').compareTo(
    b.capturedAt ?? b.takenAt ?? '',
  );
  if (t != 0) return t;
  final s = a.sessionKey.compareTo(b.sessionKey);
  return s != 0 ? s : a.position.compareTo(b.position);
}

/// Groups posts into days, newest day first.
List<MomentDayPage> buildMomentDayPages(Iterable<Moment> moments, int? me) {
  final byDay = <String, MomentDayPage>{};
  for (final m in moments) {
    final d = momentDay(m);
    if (d == null) continue;
    final page = byDay.putIfAbsent(dayKey(d), () => MomentDayPage(d, [], []));
    (m.userId == me ? page.mine : page.theirs).add(m);
  }
  for (final p in byDay.values) {
    p.mine.sort(momentTimeOrder);
    p.theirs.sort(momentTimeOrder);
  }
  return byDay.values.toList()..sort((a, b) => b.day.compareTo(a.day));
}

String momentFeedDayLabel(DateTime day, [DateTime? now]) {
  final today = dateOnly(now ?? DateTime.now());
  final diff = today.difference(dateOnly(day)).inDays;
  if (diff == 0) return '오늘';
  if (diff == 1) return '어제';
  return '${day.month}/${day.day}';
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

String momentFeedDayLong(DateTime day, [DateTime? now]) {
  final short = momentFeedDayLabel(day, now);
  final md = '${day.month}월 ${day.day}일 ${_weekdays[day.weekday - 1]}요일';
  return short == '오늘' || short == '어제' ? '$short · $md' : md;
}

/// Photo/video/text fill for one post.
class MomentFill extends StatelessWidget {
  const MomentFill({
    super.key,
    required this.moment,
    required this.baseUrl,
    this.blur = false,
    this.cacheWidth,
  });

  final Moment? moment;
  final String baseUrl;
  final bool blur;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final m = moment;
    Widget fill;
    if (m == null || (m.todayLocked && m.mediaUrl == null)) {
      fill = V2PhotoPlaceholder(seed: m?.id ?? 'none', radius: 0);
    } else if (m.isVideo && m.mediaUrl != null) {
      fill = MomentVideoThumb(
        url: mediaUrlFor(baseUrl, m.mediaUrl),
        seed: m.id,
      );
    } else if (m.mediaUrl != null && m.mediaType != 'text') {
      fill = UploadImage(
        raw: m.mediaUrl!,
        baseUrl: baseUrl,
        pixelWidth: cacheWidth,
        error: V2PhotoPlaceholder(seed: m.id, radius: 0),
      );
    } else {
      fill = Container(
        color: const Color(0xFF2B2440),
        padding: const EdgeInsets.all(14),
        alignment: Alignment.center,
        child: Text(
          m.caption ?? '',
          textAlign: TextAlign.center,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: V2Text.sans(
            size: 15,
            weight: FontWeight.w700,
            color: Colors.white,
            height: 1.45,
          ),
        ),
      );
    }
    if (!blur) return fill;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
      child: Transform.scale(scale: 1.15, child: fill),
    );
  }
}

/// "어떻게 남길까요?": camera / album / text only.
Future<MomentStartSource?> showMomentSourceSheet(
  BuildContext context, {
  String title = '기록 남기기',
}) {
  return showV2Sheet<MomentStartSource>(
    context,
    title: title,
    builder: (ctx) => V2List(
      children: [
        V2ListTile(
          key: const Key('moment_source_camera'),
          icon: V2Icons.camera,
          title: '카메라로 찍기',
          subtitle: '사진이나 1분까지의 영상',
          onTap: () => Navigator.pop(ctx, MomentStartSource.camera),
        ),
        V2ListTile(
          key: const Key('moment_source_gallery'),
          icon: V2Icons.gallery,
          tone: V2Tone.sky,
          title: '앨범에서 고르기',
          subtitle: '여러 장을 한 번에 골라요',
          onTap: () => Navigator.pop(ctx, MomentStartSource.gallery),
        ),
        V2ListTile(
          key: const Key('moment_source_text'),
          icon: V2Icons.text,
          tone: V2Tone.sage,
          title: '글만 쓰기',
          onTap: () => Navigator.pop(ctx, MomentStartSource.text),
        ),
      ],
    ),
  );
}
