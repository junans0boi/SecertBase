import 'dart:convert';
import 'package:flutter/foundation.dart';

final pendingPushTarget = ValueNotifier<PushTarget?>(null);

/// The complete notification destination survives every transport and app state.
class PushTarget {
  final String screen;
  final int? postId;
  final String? gameType;
  final String? roomCode;
  final String? draftId;
  const PushTarget({
    required this.screen,
    this.postId,
    this.gameType,
    this.roomCode,
    this.draftId,
  });

  static PushTarget? fromData(Map data) {
    final screen = data['screen'];
    if (!const [
      'moment_detail',
      'today_loop',
      'game_invite',
      'moment_draft',
    ].contains(screen)) {
      return null;
    }
    String? text(String key) {
      final value = data[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    return PushTarget(
      screen: screen as String,
      postId: int.tryParse('${data['post_id']}'),
      gameType: text('game_type'),
      roomCode: text('room_code'),
      draftId: text('draft_id'),
    );
  }

  static PushTarget? fromPayload(String payload) {
    try {
      final data = jsonDecode(payload);
      return data is Map ? fromData(data) : null;
    } on FormatException {
      return null;
    }
  }

  static PushTarget? fromUri(Uri uri) {
    final fragment = Uri.tryParse(uri.fragment);
    return fromData({...uri.queryParameters, ...?fragment?.queryParameters});
  }

  Map<String, Object> toData() => {
    'screen': screen,
    'post_id': ?postId,
    'game_type': ?gameType,
    'room_code': ?roomCode,
    'draft_id': ?draftId,
  };
  String toPayload() => jsonEncode(toData());
}
