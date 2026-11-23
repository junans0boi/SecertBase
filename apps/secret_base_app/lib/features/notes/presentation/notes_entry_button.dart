import 'package:flutter/material.dart';

import '../../../v2/v2.dart';
import '../application/notes_unread.dart';

/// 홈 상단 쪽지 진입. 읽지 않은 쪽지가 있으면 점이 보인다.
class NotesEntryButton extends StatelessWidget {
  final NotesUnread unread;
  final VoidCallback onOpen;
  const NotesEntryButton({
    super.key,
    required this.unread,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: unread,
    builder: (context, _) => V2IconButton(
      key: const ValueKey('home-notes-entry'),
      icon: V2Icons.mail,
      tooltip: unread.hasUnread ? '쪽지, 읽지 않은 쪽지 ${unread.count}통' : '쪽지',
      dot: unread.hasUnread,
      onPressed: onOpen,
    ),
  );
}
