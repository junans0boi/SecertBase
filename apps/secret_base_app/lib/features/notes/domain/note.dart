/// 쪽지 한 통. 서버가 열람 전·삭제 상태의 본문을 비워 보내므로 앱은 그대로 그린다.
enum NoteStatus { visible, locked, deleted }

/// 서버와 같은 반응 이모지 6개.
const noteReactions = ['❤️', '😊', '😂', '😢', '👍', '🔥'];
const noteBodyMax = 1000;

class NoteRef {
  final int id;
  final String? title;
  final String? subtitle;
  final bool unavailable;
  const NoteRef({
    required this.id,
    this.title,
    this.subtitle,
    this.unavailable = false,
  });
}

class Note {
  final int id;
  final bool mine;
  final NoteStatus status;
  final String? body;
  final String? mediaUrl;
  final DateTime? createdAt;
  final DateTime? openAt;
  final DateTime? readAt;
  final String? reaction;
  final NoteRef? place;
  final NoteRef? moment;

  const Note({
    required this.id,
    required this.mine,
    required this.status,
    this.body,
    this.mediaUrl,
    this.createdAt,
    this.openAt,
    this.readAt,
    this.reaction,
    this.place,
    this.moment,
  });

  bool get isRead => readAt != null;

  factory Note.fromJson(Map<String, dynamic> json) {
    DateTime? time(Object? v) =>
        v is String ? DateTime.tryParse(v)?.toLocal() : null;
    final pin = json['map_pin'];
    final post = json['setlog_post'];
    return Note(
      id: (json['id'] as num).toInt(),
      mine: json['mine'] == true,
      status: switch (json['status']) {
        'locked' => NoteStatus.locked,
        'deleted' => NoteStatus.deleted,
        _ => NoteStatus.visible,
      },
      body: json['body'] as String?,
      mediaUrl: json['media_url'] as String?,
      createdAt: time(json['created_at']),
      openAt: time(json['open_at']),
      readAt: time(json['read_at']),
      reaction: json['reaction'] as String?,
      place: pin is Map
          ? NoteRef(
              id: (pin['id'] as num).toInt(),
              title: pin['place_name'] as String?,
              subtitle: pin['category'] as String?,
              unavailable: pin['deleted'] == true,
            )
          : null,
      moment: post is Map
          ? NoteRef(
              id: (post['id'] as num).toInt(),
              title: post['caption'] as String?,
              subtitle: post['taken_at'] as String?,
              unavailable: post['deleted'] == true || post['locked'] == true,
            )
          : null,
    );
  }

  Note copyWith({
    NoteStatus? status,
    DateTime? readAt,
    Object? reaction = _keep,
  }) => Note(
    id: id,
    mine: mine,
    status: status ?? this.status,
    body: (status ?? this.status) == NoteStatus.deleted ? null : body,
    mediaUrl: (status ?? this.status) == NoteStatus.deleted ? null : mediaUrl,
    createdAt: createdAt,
    openAt: openAt,
    readAt: readAt ?? this.readAt,
    reaction: identical(reaction, _keep) ? this.reaction : reaction as String?,
    place: place,
    moment: moment,
  );
}

const _keep = Object();

/// 보내는 중이거나 보내지 못한 쪽지. [clientRequestId]가 같으면 서버가 한 번만 만든다.
class PendingNote {
  final String clientRequestId;
  final String body;
  final DateTime? openAt;
  final NotePhoto? photo;
  final int? mapPinId;
  final int? setlogPostId;
  final bool failed;
  final String? error;

  const PendingNote({
    required this.clientRequestId,
    required this.body,
    this.openAt,
    this.photo,
    this.mapPinId,
    this.setlogPostId,
    this.failed = false,
    this.error,
  });

  PendingNote copyWith({bool? failed, String? error}) => PendingNote(
    clientRequestId: clientRequestId,
    body: body,
    openAt: openAt,
    photo: photo,
    mapPinId: mapPinId,
    setlogPostId: setlogPostId,
    failed: failed ?? this.failed,
    error: error,
  );
}

class NotePhoto {
  final List<int> bytes;
  final String name;
  const NotePhoto({required this.bytes, required this.name});
}

class NotesPage {
  final List<Note> notes; // 최신순
  final int? nextBefore;
  final int unreadCount;
  const NotesPage({
    required this.notes,
    required this.nextBefore,
    required this.unreadCount,
  });
}
