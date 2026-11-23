import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/http/api_client.dart';
import 'package:secret_base_app/features/notes/data/notes_repository.dart';
import 'package:secret_base_app/features/notes/domain/note.dart';

void main() {
  late List<http.Request> requests;
  late HttpNotesRepository repo;

  setUp(() {
    requests = [];
    repo = HttpNotesRepository(
      ApiClient(
        baseUrl: 'http://x.test',
        tokenProvider: () => 'jwt',
        client: MockClient((request) async {
          requests.add(request);
          final body = switch (request.url.path) {
            '/api/notes' when request.method == 'GET' => {
              'ok': true,
              'notes': [
                {
                  'id': 5,
                  'mine': false,
                  'status': 'locked',
                  'body': null,
                  'open_at': '2026-11-24T00:00:00.000Z',
                },
                {
                  'id': 4,
                  'mine': true,
                  'status': 'visible',
                  'body': '안녕',
                  'map_pin': {'id': 3, 'place_name': '카페'},
                  'setlog_post': {'id': 8, 'deleted': true},
                },
              ],
              'next_before': 4,
              'unread_count': 2,
            },
            '/api/notes' => {
              'ok': true,
              'note': {'id': 6, 'mine': true, 'status': 'visible', 'body': 'x'},
            },
            '/api/notes/unread' => {'ok': true, 'unread_count': 7},
            '/api/notes/read' => {'ok': true, 'unread_count': 0},
            _ => {'ok': true},
          };
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
  });

  test(
    'list sends the cursor and parses locked, mine and reference notes',
    () async {
      final page = await repo.list(before: 9, limit: 10);
      expect(requests.single.url.query, 'limit=10&before=9');
      expect(page.nextBefore, 4);
      expect(page.unreadCount, 2);
      expect(page.notes.first.status, NoteStatus.locked);
      expect(page.notes.first.body, isNull);
      expect(page.notes.first.openAt, isNotNull);
      expect(page.notes.last.place?.title, '카페');
      expect(page.notes.last.moment?.unavailable, isTrue);
    },
  );

  test(
    'send posts JSON with client_request_id, open_at in UTC and references',
    () async {
      await repo.send(
        PendingNote(
          clientRequestId: 'req-1',
          body: '안녕',
          openAt: DateTime.utc(2026, 11, 24, 9),
          mapPinId: 3,
          setlogPostId: 8,
        ),
      );
      final body = jsonDecode(requests.single.body) as Map;
      expect(requests.single.method, 'POST');
      expect(body['client_request_id'], 'req-1');
      expect(body['open_at'], '2026-11-24T09:00:00.000Z');
      expect(body['map_pin_id'], '3');
      expect(body['setlog_post_id'], '8');
      expect(requests.single.headers['Authorization'], 'Bearer jwt');
    },
  );

  test(
    'photo sends multipart media; read, unread and delete hit the right routes',
    () async {
      await repo.send(
        PendingNote(
          clientRequestId: 'req-2',
          body: '',
          photo: const NotePhoto(bytes: [1, 2, 3], name: 'a.png'),
        ),
      );
      expect(
        requests.last.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      expect(await repo.unreadCount(), 7);
      expect(await repo.markRead(5), 0);
      expect(jsonDecode(requests.last.body), {'last_read_id': 5});
      await repo.delete(5);
      expect(requests.last.method, 'DELETE');
      expect(requests.last.url.path, '/api/notes/5');
    },
  );
}
