import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/screens/archive/archive_screen.dart';

void main() {
  testWidgets('archive exposes only working features for the beta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ArchiveScreen())),
    );

    expect(find.text('MomentLoop'), findsOneWidget);
    expect(find.text('비밀 지도'), findsOneWidget);

    // 비활성 REST에 의존하는 항목은 복구 전까지 숨긴다 (#32).
    expect(find.text('우리 앨범'), findsNothing);
    expect(find.text('타임캡슐'), findsNothing);
    expect(find.text('마음 대피소'), findsNothing);
    expect(find.text('마음 교감'), findsNothing);
    expect(find.text('추억 저장고'), findsNothing);
  });
}
