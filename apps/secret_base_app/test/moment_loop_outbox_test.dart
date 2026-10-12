import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/http/api_client.dart';
import 'package:secret_base_app/features/moment_loop/application/upload_outbox.dart';
import 'package:secret_base_app/features/moment_loop/domain/moment.dart';
import 'package:secret_base_app/features/moment_loop/domain/moment_edit.dart';
import 'moment_loop_test_support.dart';

void main() {
  test(
    'worker resumes only for the original signed in user and couple',
    () async {
      var userId = 7;
      var scope = 'couple-a';
      var signedIn = false;
      var posts = 0;
      final queue = UploadOutbox(
        store: MemoryOutboxStore(),
        currentUserId: () => userId,
        currentScope: () => scope,
        canUpload: () => signedIn,
        apiClient: ApiClient(
          baseUrl: 'https://secretbase.example',
          tokenProvider: () => signedIn ? 'token' : null,
          client: MockClient((_) async {
            posts++;
            return http.Response('{"ok":true,"post":{"id":9}}', 201);
          }),
        ),
      );
      final id = await queue.enqueue(
        MomentDraft(
          caption: '보존',
          takenAt: DateTime(2026, 10, 12),
          capturedAt: DateTime(2026, 10, 12),
          sessionId: 'auth-session',
        ),
      );
      await queue.resume();
      expect(posts, 0);
      signedIn = true;
      scope = 'couple-b';
      await queue.resume();
      expect(posts, 0);
      expect(await queue.readDraft(id), isNull);
      scope = 'couple-a';
      userId = 8;
      await queue.resume();
      expect(posts, 0);
      userId = 7;
      await queue.resume();
      expect(posts, 1);
      expect(queue.drafts, isEmpty);
    },
  );

  test(
    'legacy standalone edit uses row PATCH without manufacturing a session',
    () async {
      final requests = <String>[];
      final queue = UploadOutbox(
        store: MemoryOutboxStore(),
        currentUserId: () => 7,
        apiClient: ApiClient(
          baseUrl: 'https://secretbase.example',
          tokenProvider: () => 'token',
          client: MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            final body = jsonDecode(request.body) as Map;
            expect(body.containsKey('session_id'), isFalse);
            expect(body['position'], 0);
            return http.Response('{"ok":true,"post":{"id":9}}', 200);
          }),
        ),
      );
      const post = Moment(id: 9, userId: 7, mediaType: 'text');
      await queue.enqueueEdit(
        MomentEdit(
          original: [post],
          items: [MomentEditItem.existing(post)],
          fields: MomentDraft(
            caption: 'legacy',
            takenAt: DateTime(2026, 10, 12),
            capturedAt: DateTime(2026, 10, 12),
            sessionId: '',
          ),
        ),
      );
      await queue.resume();
      expect(requests, ['PATCH /api/setlog/9']);
      expect(queue.drafts, isEmpty);
    },
  );

  test(
    'revealed group rejects media changes and date changes while fields remain editable',
    () async {
      final queue = UploadOutbox(
        store: MemoryOutboxStore(),
        currentUserId: () => 7,
        apiClient: ApiClient(
          baseUrl: 'https://secretbase.example',
          tokenProvider: () => 'token',
          client: MockClient((_) async => http.Response('{"ok":true}', 200)),
        ),
      );
      const post = Moment(
        id: 9,
        userId: 7,
        sessionId: 'revealed',
        mediaEditLocked: true,
        takenAt: '2026-10-12',
        mediaType: 'image',
      );
      MomentDraft fields(DateTime date) => MomentDraft(
        caption: '변경',
        takenAt: date,
        capturedAt: date,
        sessionId: 'revealed',
      );
      await expectLater(
        queue.enqueueEdit(
          MomentEdit(
            original: [post],
            items: [],
            fields: fields(DateTime(2026, 10, 12)),
          ),
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        queue.enqueueEdit(
          MomentEdit(
            original: [post],
            items: [MomentEditItem.existing(post)],
            fields: fields(DateTime(2026, 10, 11)),
          ),
        ),
        throwsA(isA<Exception>()),
      );
      await queue.enqueueEdit(
        MomentEdit(
          original: [post],
          items: [MomentEditItem.existing(post)],
          fields: fields(DateTime(2026, 10, 12)),
        ),
      );
      await queue.resume();
      expect(queue.drafts, isEmpty);
    },
  );
  test(
    'failed draft reopens for editing without losing the request ID after a lost response',
    () async {
      final requests = <http.MultipartRequest>[];
      var online = false;
      final queue = UploadOutbox(
        store: MemoryOutboxStore(),
        currentUserId: () => 7,
        apiClient: ApiClient(
          baseUrl: 'https://secretbase.example',
          tokenProvider: () => 'token',
          client: MockClient.streaming((request, body) async {
            await body.toBytes();
            if (request is http.MultipartRequest) {
              requests.add(request);
              if (!online) {
                throw Exception('response lost after server committed');
              }
            }
            return http.StreamedResponse(
              Stream.value(utf8.encode('{"ok":true,"post":{"id":11}}')),
              200,
            );
          }),
        ),
      );
      final id = await queue.enqueue(
        MomentDraft(
          caption: '전송',
          takenAt: DateTime(2026, 10, 12),
          capturedAt: DateTime(2026, 10, 12),
          sessionId: 'stable',
          media: [
            MomentMedia(
              name: 'v.mp4',
              bytes: Uint8List.fromList([5]),
              isVideo: true,
            ),
          ],
        ),
      );
      await queue.resume();
      final reopened = (await queue.readDraft(id))!;
      await queue.replace(
        id,
        MomentDraft(
          caption: '수정',
          takenAt: reopened.takenAt,
          capturedAt: reopened.capturedAt,
          sessionId: reopened.sessionId,
          media: reopened.media,
        ),
      );
      online = true;
      await queue.retry(id);
      expect(queue.drafts, isEmpty);
      expect(requests, hasLength(2));
      expect(
        requests.last.fields['client_request_id'],
        requests.first.fields['client_request_id'],
      );
      expect(requests.last.fields['caption'], '수정');
    },
  );
  test(
    'group edit keeps session identity, updates fields and orders retained plus added rows',
    () async {
      final requests = <String>[];
      final payloads = <Map<String, dynamic>>[];
      final api = ApiClient(
        baseUrl: 'https://secretbase.example',
        tokenProvider: () => 'token',
        client: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.method == 'PATCH') {
            payloads.add(jsonDecode(request.body) as Map<String, dynamic>);
          }
          return http.Response(
            jsonEncode({
              'ok': true,
              'post': {'id': 53, 'user_id': 7},
            }),
            200,
          );
        }),
      );
      final queue = UploadOutbox(
        store: MemoryOutboxStore(),
        apiClient: api,
        currentUserId: () => 7,
      );
      final original = [
        const Moment(
          id: 51,
          userId: 7,
          sessionId: 'keep-session',
          mediaType: 'image',
        ),
        const Moment(
          id: 52,
          userId: 7,
          sessionId: 'keep-session',
          mediaType: 'image',
        ),
      ];
      await queue.enqueueEdit(
        MomentEdit(
          original: original,
          fields: MomentDraft(
            caption: '수정',
            takenAt: DateTime(2026, 10, 1),
            capturedAt: DateTime(2026, 10, 1),
            sessionId: 'keep-session',
            mapPinId: 9,
          ),
          items: [
            MomentEditItem.added(
              MomentMedia(
                name: 'new.mp4',
                bytes: Uint8List.fromList([3]),
                isVideo: true,
              ),
            ),
            MomentEditItem.existing(original[1]),
          ],
        ),
      );
      await queue.resume();
      expect(queue.drafts, isEmpty);
      expect(requests, [
        'PATCH /api/setlog/session/keep-session',
        'POST /api/setlog',
        'DELETE /api/setlog/51',
        'PATCH /api/setlog/session/keep-session/order',
      ]);
      expect(payloads.first, containsPair('taken_at', '2026-10-01'));
      expect(payloads.first, containsPair('map_pin_id', 9));
      expect(payloads.first.containsKey('session_id'), isFalse);
      expect(payloads.last, {
        'order': [53, 52],
      });
    },
  );
  test(
    'partial failure survives cold start and retries only the remaining row with the same key',
    () async {
      final store = MemoryOutboxStore();
      final requests = <http.MultipartRequest>[];
      var online = false;
      var nextId = 40;
      final api = ApiClient(
        baseUrl: 'https://secretbase.example',
        tokenProvider: () => 'token',
        client: MockClient.streaming((request, body) async {
          requests.add(request as http.MultipartRequest);
          await body.toBytes();
          if (requests.length == 2 && !online) throw Exception('offline');
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode({
                  'ok': true,
                  'post': {'id': nextId++, 'user_id': 7},
                }),
              ),
            ),
            201,
          );
        }),
      );
      final notifications = <String>[];
      final queue = UploadOutbox(
        store: store,
        apiClient: api,
        currentUserId: () => 7,
        failureNotifier: (id) async => notifications.add(id),
      );
      final id = await queue.enqueue(
        MomentDraft(
          caption: '두 장',
          takenAt: DateTime(2026, 10, 12),
          capturedAt: DateTime(2026, 10, 12),
          sessionId: 'unchanged',
          media: [
            MomentMedia(
              name: 'first.mp4',
              bytes: Uint8List.fromList([1]),
              isVideo: true,
            ),
            MomentMedia(
              name: 'second.mp4',
              bytes: Uint8List.fromList([2]),
              isVideo: true,
            ),
          ],
        ),
      );
      await queue.resume();
      expect(queue.drafts.single.uploadedCount, 1);
      expect(queue.drafts.single.status, UploadDraftStatus.failed);
      expect(notifications, [id]);
      online = true;
      final recovered = UploadOutbox(
        store: store,
        apiClient: api,
        currentUserId: () => 7,
      );
      await recovered.resume();
      expect(recovered.drafts, isEmpty);
      expect(store.records, isEmpty);
      expect(store.files, isEmpty);
      expect(requests, hasLength(3));
      expect(requests.map((r) => r.fields['position']).toList(), [
        '0',
        '1',
        '1',
      ]);
      expect(
        requests[1].fields['client_request_id'],
        requests[2].fields['client_request_id'],
      );
      expect(
        requests[0].fields['client_request_id'],
        isNot(requests[1].fields['client_request_id']),
      );
      expect(requests[2].fields['session_id'], 'unchanged');
    },
  );

  test(
    'Today designation from a previous business date stays failed until edited',
    () async {
      final queue = UploadOutbox(
        store: MemoryOutboxStore(),
        currentUserId: () => 7,
        apiClient: ApiClient(
          baseUrl: 'https://secretbase.example',
          tokenProvider: () => 'token',
          client: MockClient(
            (_) async => http.Response('{"ok":true,"post":{"id":1}}', 201),
          ),
        ),
      );
      await queue.enqueue(
        MomentDraft(
          caption: 'old Today',
          takenAt: DateTime(2020, 1, 1),
          capturedAt: DateTime(2020, 1, 1),
          sessionId: 'old',
          todayMoment: true,
        ),
      );
      await queue.resume();
      expect(queue.drafts.single.status, UploadDraftStatus.failed);
      expect(queue.drafts.single.error, 'today_moment_wrong_date');
    },
  );

  test(
    'enqueue persists bytes and returns while HTTP is still pending',
    () async {
      final store = MemoryOutboxStore();
      final response = Completer<http.Response>();
      final api = ApiClient(
        baseUrl: 'https://secretbase.example',
        tokenProvider: () => 'token',
        client: MockClient((_) => response.future),
      );
      final queue = UploadOutbox(
        store: store,
        apiClient: api,
        currentUserId: () => 7,
      );
      final bytes = Uint8List.fromList([1, 2, 3]);
      final id = await queue.enqueue(
        MomentDraft(
          caption: '기록',
          takenAt: DateTime(2026, 10, 12),
          capturedAt: DateTime(2026, 10, 12, 10),
          sessionId: 'stable-session',
          media: [MomentMedia(name: 'clip.mp4', bytes: bytes, isVideo: true)],
        ),
      );
      bytes[0] = 99;
      expect(queue.drafts.single.id, id);
      final restored = await queue.readDraft(id);
      expect(restored!.media.single.bytes, [1, 2, 3]);
      final running = queue.resume();
      await Future<void>.delayed(Duration.zero);
      expect(queue.drafts.single.status, UploadDraftStatus.uploading);
      response.complete(
        http.Response(
          jsonEncode({
            'ok': true,
            'post': {'id': 31, 'user_id': 7},
          }),
          201,
        ),
      );
      await running;
      expect(queue.drafts, isEmpty);
      expect(queue.feedRevision.value, 1);
      expect(store.records, isEmpty);
      expect(store.files, isEmpty);
    },
  );
}
