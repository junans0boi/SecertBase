import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/http/api_exception.dart';
import 'package:secret_base_app/core/push/push_target.dart';
import 'package:secret_base_app/features/notes/application/notes_controller.dart';
import 'package:secret_base_app/features/notes/application/notes_events.dart';
import 'package:secret_base_app/features/notes/application/notes_unread.dart';
import 'package:secret_base_app/features/notes/data/notes_repository.dart';
import 'package:secret_base_app/features/notes/domain/note.dart';
import 'package:secret_base_app/features/notes/presentation/notes_entry_button.dart';
import 'package:secret_base_app/features/notes/presentation/notes_screen.dart';
import 'package:secret_base_app/v2/v2.dart';

Note _note(
  int id, {
  bool mine = false,
  NoteStatus status = NoteStatus.visible,
  String? body,
  DateTime? openAt,
  DateTime? readAt,
  String? reaction,
}) => Note(
  id: id,
  mine: mine,
  status: status,
  body: status == NoteStatus.visible ? (body ?? '쪽지 $id') : null,
  openAt: openAt,
  readAt: readAt,
  reaction: reaction,
);

class _FakeRepo implements NotesRepository {
  List<Note> notes;
  int unread;
  int nextId = 100;
  final sent = <PendingNote>[];
  final reads = <int>[];
  final deleted = <int>[];
  Object? sendError;
  int sendCalls = 0;

  _FakeRepo({this.notes = const [], this.unread = 0});

  @override
  Future<NotesPage> list({int? before, int limit = 30}) async => NotesPage(
    notes: notes.reversed.toList(),
    nextBefore: null,
    unreadCount: unread,
  );

  @override
  Future<int> unreadCount() async => unread;

  @override
  Future<Note> send(PendingNote draft) async {
    sendCalls++;
    final error = sendError;
    if (error != null) throw error;
    sent.add(draft);
    final note = Note(
      id: nextId++,
      mine: true,
      status: NoteStatus.visible,
      body: draft.body,
      openAt: draft.openAt,
    );
    notes = [...notes, note];
    return note;
  }

  @override
  Future<int> markRead(int lastReadId) async {
    reads.add(lastReadId);
    unread = 0;
    return 0;
  }

  @override
  Future<void> delete(int id) async => deleted.add(id);

  @override
  Future<Note> react(int id, String? emoji) async =>
      notes.firstWhere((n) => n.id == id).copyWith(reaction: emoji);
}

const _network = ApiException(
  statusCode: null,
  code: 'network_error',
  message: 'x',
);

typedef _Event = (String, Map<String, dynamic>);

Widget _screen(
  NotesController controller, {
  StreamController<_Event>? events,
  Future<DateTime?> Function(BuildContext)? pickOpenAt,
  DateTime? now,
}) => MaterialApp(
  home: NotesScreen(
    controller: controller,
    events: (listener) {
      final sub = events?.stream.listen((e) => listener(e.$1, e.$2));
      return () => sub?.cancel();
    },
    pickOpenAt: pickOpenAt,
    now: now == null ? null : () => now,
  ),
);

void main() {
  final fixedNow = DateTime(2026, 11, 23, 12);

  group('NotesController', () {
    test(
      'load marks received notes read and clears the unread count',
      () async {
        final repo = _FakeRepo(
          notes: [_note(1), _note(2, mine: true), _note(3)],
          unread: 2,
        );
        final c = NotesController(repository: repo);
        await c.load();
        expect(c.notes.map((n) => n.id), [1, 2, 3]);
        expect(repo.reads, [3]);
        expect(c.unread, 0);
      },
    );

    test('a hidden screen does not mark notes read', () async {
      final repo = _FakeRepo(notes: [_note(1)], unread: 1);
      final c = NotesController(repository: repo)..setVisible(false);
      await c.load();
      expect(repo.reads, isEmpty);
      expect(c.unread, 1);
    });

    test(
      'send keeps the same client_request_id across a network failure',
      () async {
        final repo = _FakeRepo()..sendError = _network;
        var n = 0;
        final c = NotesController(
          repository: repo,
          requestId: () => 'req-${++n}',
        );
        await c.send('안녕');
        expect(c.pending.single.failed, isTrue);
        expect(c.pending.single.error, isNull);
        repo.sendError = null;
        await c.flushPending();
        expect(c.pending, isEmpty);
        expect(repo.sent.single.clientRequestId, 'req-1');
        expect(c.notes.single.body, '안녕');
      },
    );

    test(
      'a permanent rejection is shown and not retried automatically',
      () async {
        final repo = _FakeRepo()
          ..sendError = const ApiException(
            statusCode: 409,
            code: 'active_couple_required',
            message: 'x',
          );
        final c = NotesController(repository: repo);
        await c.send('x');
        expect(c.pending.single.error, '연결이 해제되어 보낼 수 없어요');
        final calls = repo.sendCalls;
        await c.flushPending();
        expect(repo.sendCalls, calls);
        c.discardPending(c.pending.single.clientRequestId);
        expect(c.pending, isEmpty);
      },
    );

    test('empty drafts are not queued', () async {
      final c = NotesController(repository: _FakeRepo());
      await c.send('   ');
      expect(c.pending, isEmpty);
    });

    test(
      'socket events update notes, read marks, deletes and reactions',
      () async {
        final repo = _FakeRepo(notes: [_note(1, mine: true)]);
        final c = NotesController(repository: repo)..setVisible(false);
        await c.load();
        c.applyEvent('note:new', {
          'note': {'id': 5, 'mine': false, 'status': 'visible', 'body': '왔어요'},
        });
        expect(c.notes.last.body, '왔어요');
        expect(c.unread, 1);
        c.applyEvent('note:read', {
          'up_to_id': 1,
          'read_at': '2026-11-23T03:00:00Z',
        });
        expect(c.notes.first.isRead, isTrue);
        c.applyEvent('note:reaction', {'id': 1, 'reaction': '❤️'});
        expect(c.notes.first.reaction, '❤️');
        c.applyEvent('note:deleted', {'id': 5});
        expect(c.notes.last.status, NoteStatus.deleted);
        expect(c.notes.last.body, isNull);
      },
    );
  });

  group('NotesUnread', () {
    test('uses the server count and the socket stream for the dot', () async {
      final repo = _FakeRepo(unread: 2);
      late void Function(String, Map<String, dynamic>) emit;
      final u = NotesUnread(
        repository: repo,
        events: (listener) {
          emit = listener;
          return () {};
        },
      );
      await u.start();
      expect(u.hasUnread, isTrue);
      expect(u.count, 2);
      emit('note:new', {
        'note': {'id': 9, 'mine': false, 'status': 'visible'},
      });
      emit('note:new', {
        'note': {'id': 10, 'mine': true, 'status': 'visible'},
      });
      expect(u.count, 3);
      u.dispose();
    });

    test('without a repository it stays quiet', () async {
      final u = NotesUnread();
      await u.start();
      expect(u.count, 0);
    });

    testWidgets('the home entry button shows the dot and opens notes', (
      tester,
    ) async {
      final unread = NotesUnread(repository: _FakeRepo(unread: 3));
      await unread.refresh();
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: V2Theme(
            child: Scaffold(
              body: NotesEntryButton(unread: unread, onOpen: () => opened++),
            ),
          ),
        ),
      );
      expect(find.byTooltip('쪽지, 읽지 않은 쪽지 3통'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-notes-entry')));
      expect(opened, 1);
    });
  });

  group('NotesScreen', () {
    testWidgets('lists notes with 읽음, reactions, deleted and locked states', (
      tester,
    ) async {
      final repo = _FakeRepo(
        notes: [
          _note(1, body: '받은 쪽지', reaction: '😊'),
          _note(2, mine: true, body: '내 쪽지', readAt: DateTime(2026, 11, 23)),
          _note(3, status: NoteStatus.deleted),
          _note(
            4,
            status: NoteStatus.locked,
            openAt: DateTime(2026, 11, 24, 21, 30),
          ),
        ],
      );
      await tester.pumpWidget(
        _screen(NotesController(repository: repo), now: fixedNow),
      );
      await tester.pumpAndSettle();
      expect(find.text('받은 쪽지'), findsOneWidget);
      expect(find.text('내 쪽지'), findsOneWidget);
      expect(find.text('😊'), findsOneWidget);
      expect(find.text('읽음'), findsOneWidget);
      expect(find.text('삭제된 쪽지'), findsOneWidget);
      expect(find.text('11월 24일 오후 9:30에 열려요'), findsOneWidget);
      expect(find.textContaining('쪽지 4'), findsNothing);
    });

    testWidgets('shows an empty state', (tester) async {
      await tester.pumpWidget(
        _screen(NotesController(repository: _FakeRepo())),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('아직 쪽지가 없어요'), findsOneWidget);
    });

    testWidgets('typing and sending posts the note and clears the field', (
      tester,
    ) async {
      final repo = _FakeRepo();
      await tester.pumpWidget(_screen(NotesController(repository: repo)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('note-input')),
        '오늘 고마워',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('보내기'));
      await tester.pumpAndSettle();
      expect(repo.sent.single.body, '오늘 고마워');
      expect(find.text('오늘 고마워'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('note-input')))
            .controller!
            .text,
        isEmpty,
      );
    });

    testWidgets('a scheduled send carries open_at and shows when it opens', (
      tester,
    ) async {
      final repo = _FakeRepo();
      final openAt = DateTime(2026, 11, 24, 9);
      await tester.pumpWidget(
        _screen(
          NotesController(repository: repo),
          now: fixedNow,
          pickOpenAt: (_) async => openAt,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('열리는 시각 정하기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('staged-open-at')), findsOneWidget);
      expect(find.text('11월 24일 오전 9:00에 열려요'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('note-input')),
        '내일 아침에 봐',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('보내기'));
      await tester.pumpAndSettle();
      expect(repo.sent.single.openAt, openAt);
      expect(find.byKey(const ValueKey('staged-open-at')), findsNothing);
    });

    testWidgets('a past open time is refused', (tester) async {
      await tester.pumpWidget(
        _screen(
          NotesController(repository: _FakeRepo()),
          now: fixedNow,
          pickOpenAt: (_) async => DateTime(2026, 11, 1),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('열리는 시각 정하기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('staged-open-at')), findsNothing);
      expect(find.text('지금보다 나중 시각을 골라 주세요'), findsOneWidget);
    });

    testWidgets('a failed send stays visible and can be retried', (
      tester,
    ) async {
      final repo = _FakeRepo()..sendError = _network;
      await tester.pumpWidget(_screen(NotesController(repository: repo)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('note-input')),
        '나중에 갈게',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('보내기'));
      await tester.pumpAndSettle();
      expect(find.text('연결되면 다시 보낼게요'), findsOneWidget);
      repo.sendError = null;
      await tester.tap(find.byKey(const ValueKey('pending-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pending-status')), findsNothing);
      expect(repo.sent.single.body, '나중에 갈게');
    });

    testWidgets('a note pushed over the socket appears and is marked read', (
      tester,
    ) async {
      final repo = _FakeRepo();
      final events = StreamController<_Event>();
      addTearDown(events.close);
      await tester.pumpWidget(
        _screen(NotesController(repository: repo), events: events),
      );
      await tester.pumpAndSettle();
      events.add((
        'note:new',
        {
          'note': {
            'id': 7,
            'mine': false,
            'status': 'visible',
            'body': '방금 온 쪽지',
          },
        },
      ));
      await tester.pumpAndSettle();
      expect(find.text('방금 온 쪽지'), findsOneWidget);
      expect(repo.reads, [7]);
    });

    testWidgets('long press on a received note offers reactions', (
      tester,
    ) async {
      final repo = _FakeRepo(notes: [_note(1, body: '반응해줘')]);
      await tester.pumpWidget(_screen(NotesController(repository: repo)));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('반응해줘'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('react-❤️')));
      await tester.pumpAndSettle();
      expect(find.text('❤️'), findsOneWidget);
    });

    testWidgets('long press on my note deletes it', (tester) async {
      final repo = _FakeRepo(notes: [_note(1, mine: true, body: '지울래')]);
      await tester.pumpWidget(_screen(NotesController(repository: repo)));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('지울래'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-note')));
      await tester.pumpAndSettle();
      expect(repo.deleted, [1]);
      expect(find.text('삭제된 쪽지'), findsOneWidget);
    });
  });

  test('a notes push opens the notes screen target', () {
    final target = PushTarget.fromData({
      'screen': 'notes',
      'type': 'partner_note',
    });
    expect(target?.screen, 'notes');
    expect(PushTarget.fromPayload(target!.toPayload())?.screen, 'notes');
    expect(noteEventNames, contains('note:new'));
  });
}
