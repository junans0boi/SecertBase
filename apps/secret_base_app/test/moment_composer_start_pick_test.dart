import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:secret_base_app/core/http/api_client.dart';
import 'package:secret_base_app/features/moment_loop/application/moment_loop_controller.dart';
import 'package:secret_base_app/features/moment_loop/data/moment_loop_repository.dart';
import 'package:secret_base_app/features/moment_loop/domain/moment.dart';
import 'package:secret_base_app/screens/archive/moment/moment_composer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'moment_loop_test_support.dart';

// "앨범에서 고르기" on the web opens the album chooser inside the user's tap
// and hands the pending pick to the composer as `startPick`.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpComposer(
    WidgetTester tester, {
    required Future<List<XFile>> startPick,
    Future<List<MomentMedia>> Function()? mediaPicker,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = MockClient(
      (_) async => http.Response(
        jsonEncode({'ok': true, 'posts': []}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final controller = MomentLoopController(
      repository: HttpMomentLoopRepository(
        apiClient: ApiClient(
          baseUrl: 'https://secretbase.example',
          tokenProvider: () => 'test-token',
          client: api,
        ),
      ),
      currentUserId: () => 7,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MomentComposerPage(
          controller: controller,
          outbox: testOutbox(api),
          startPick: startPick,
          mediaPicker: mediaPicker,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('files picked before the composer opened are attached', (
    tester,
  ) async {
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 4, height: 4)),
    );
    await pumpComposer(
      tester,
      startPick: Future.value([
        XFile.fromData(png, name: 'album.png', mimeType: 'image/png'),
      ]),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moment_media_reorder_list')), findsOneWidget);
  });

  testWidgets('a chooser the browser never opened does not lock the buttons', (
    tester,
  ) async {
    final never = Completer<List<XFile>>();
    var picked = 0;
    await pumpComposer(
      tester,
      startPick: never.future,
      mediaPicker: () async {
        picked++;
        return [
          MomentMedia(
            name: 'clip.mp4',
            bytes: Uint8List.fromList([1]),
            isVideo: true,
            clientRequestId: 'clip',
          ),
        ];
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moment_action_gallery')));
    await tester.pumpAndSettle();
    expect(picked, 1);
    expect(find.byKey(const Key('moment_media_reorder_list')), findsOneWidget);
  });
}
