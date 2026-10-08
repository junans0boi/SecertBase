import 'dart:typed_data';

class Moment {
  final int id;
  final int userId;
  final String? userName;
  final String? mediaType;
  final String? mediaUrl;
  final String? caption;
  final String? sessionId;
  final String? takenAt;
  final String? capturedAt;
  final int? mapPinId;
  final String? linkedPlaceName;
  final bool todayLocked;
  final List<MomentReaction> reactions;
  final Map<String, dynamic> extra;

  const Moment({
    required this.id,
    required this.userId,
    this.userName,
    this.mediaType,
    this.mediaUrl,
    this.caption,
    this.sessionId,
    this.takenAt,
    this.capturedAt,
    this.mapPinId,
    this.linkedPlaceName,
    this.todayLocked = false,
    this.reactions = const [],
    this.extra = const {},
  });

  bool get isVideo => mediaType == 'video';

  bool get hasMedia =>
      mediaUrl != null && mediaUrl!.trim().isNotEmpty && mediaType != 'text';

  String get sessionKey {
    final value = sessionId?.trim() ?? '';
    return value.isNotEmpty ? value : 'solo_$id';
  }

  Map<String, dynamic> toLegacyMap() => {
    ...extra,
    'id': id,
    'user_id': userId,
    'Nickname': userName,
    'UserName': userName,
    'media_type': mediaType,
    'media_url': mediaUrl,
    'caption': caption,
    'session_id': sessionId,
    'taken_at': takenAt,
    'captured_at': capturedAt,
    'map_pin_id': mapPinId,
    'linked_place_name': linkedPlaceName,
    'today_locked': todayLocked,
    'session_reactions': reactions
        .map((reaction) => reaction.toJson())
        .toList(),
  };
}

class MomentReaction {
  final int? userId;
  final String emoji;

  const MomentReaction({this.userId, required this.emoji});

  Map<String, dynamic> toJson() => {'user_id': userId, 'emoji': emoji};
}

class MomentMedia {
  final String name;
  final Uint8List bytes;
  final bool isVideo;

  const MomentMedia({
    required this.name,
    required this.bytes,
    required this.isVideo,
  });
}

class MomentDraft {
  final String caption;
  final DateTime takenAt;
  final DateTime capturedAt;
  final String sessionId;
  final bool todayMoment;
  final int? mapPinId;
  final List<MomentMedia> media;

  const MomentDraft({
    required this.caption,
    required this.takenAt,
    required this.capturedAt,
    required this.sessionId,
    this.todayMoment = false,
    this.mapPinId,
    this.media = const [],
  });

  MomentDraft copyWith({int? mapPinId}) => MomentDraft(
    caption: caption,
    takenAt: takenAt,
    capturedAt: capturedAt,
    sessionId: sessionId,
    todayMoment: todayMoment,
    mapPinId: mapPinId ?? this.mapPinId,
    media: media,
  );
}

class MomentMapPin {
  final int id;
  final String name;
  final String? category;

  const MomentMapPin({required this.id, required this.name, this.category});
}

class MomentMapPinDraft {
  final String name;
  final String? category;
  final DateTime visitDate;
  final String memo;

  const MomentMapPinDraft({
    required this.name,
    required this.visitDate,
    required this.memo,
    this.category,
  });
}
