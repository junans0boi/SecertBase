import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/http/api_client.dart';
import 'package:secret_base_app/features/moment_loop/data/media_upload_service.dart';
import 'package:secret_base_app/features/moment_loop/data/moment_loop_repository.dart';
import 'package:secret_base_app/features/moment_loop/domain/moment.dart';

void main() {
  test(
    'feed adapter parses locked moments and MariaDB reaction JSON',
    () async {
      final api = _api((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/setlog');
        return http.Response(
          jsonEncode({
            'ok': true,
            'posts': [
              {
                'id': 7,
                'user_id': 2,
                'UserName': '상대',
                'media_type': 'text',
                'caption': '잠긴 기록',
                'session_id': 'session-7',
                'today_locked': true,
                'session_reactions': '[{"user_id":1,"emoji":"❤️"}]',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final feed = await HttpMomentLoopRepository(
        apiClient: api,
      ).fetchFeed(DateTime(2026, 10, 5));

      expect(feed.single.todayLocked, isTrue);
      expect(feed.single.userName, '상대');
      expect(feed.single.reactions.single.emoji, '❤️');
    },
  );

  test(
    'upload adapter preserves setlog multipart fields and media limit',
    () async {
      late http.MultipartRequest captured;
      final api = _apiWithClient(
        MockClient.streaming((request, body) async {
          captured = request as http.MultipartRequest;
          await body.toBytes();
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode({
                  'ok': true,
                  'post': {
                    'id': 8,
                    'user_id': 1,
                    'media_type': 'image',
                    'media_url': '/uploads/photo.png',
                    'session_id': 'session-8',
                    'caption': '사진',
                  },
                }),
              ),
            ),
            201,
          );
        }),
      );
      final repository = HttpMomentLoopRepository(apiClient: api);

      final created = await repository.create(
        MomentDraft(
          caption: '사진',
          takenAt: DateTime(2026, 10, 8),
          capturedAt: DateTime(2026, 10, 8, 12, 30),
          sessionId: 'session-8',
          todayMoment: true,
          mapPinId: 22,
          media: [
            MomentMedia(
              name: 'photo.png',
              bytes: Uint8List.fromList([1, 2, 3]),
              isVideo: false,
            ),
          ],
        ),
      );

      expect(created.single.id, 8);
      expect(captured.fields['caption'], '사진');
      expect(captured.fields['taken_at'], '2026-10-08');
      expect(captured.fields['today_moment'], 'true');
      expect(captured.fields['map_pin_id'], '22');
      expect(captured.files.single.field, 'media');
      expect(captured.files.single.filename, 'photo.png');
    },
  );

  test('upload adapter rejects files larger than the backend limit', () async {
    final service = HttpMediaUploadService(
      _api((_) async {
        fail('oversized media must be rejected before a request is sent');
      }),
    );

    await expectLater(
      service.upload(
        MomentDraft(
          caption: '큰 파일',
          takenAt: DateTime(2026, 10, 8),
          capturedAt: DateTime(2026, 10, 8),
          sessionId: 'large',
          media: [
            MomentMedia(
              name: 'large.mp4',
              bytes: Uint8List(HttpMediaUploadService.maxFileBytes + 1),
              isVideo: true,
            ),
          ],
        ),
      ),
      throwsA(
        isA<MomentLoopException>().having(
          (error) => error.code,
          'code',
          'media_too_large',
        ),
      ),
    );
  });
}

ApiClient _api(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      baseUrl: 'https://secretbase.example',
      tokenProvider: () => 'jwt-token',
      client: MockClient(handler),
    );

ApiClient _apiWithClient(http.Client client) => ApiClient(
  baseUrl: 'https://secretbase.example',
  tokenProvider: () => 'jwt-token',
  client: client,
);
