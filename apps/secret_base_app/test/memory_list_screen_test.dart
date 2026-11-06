import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/screens/home/memory_list_screen.dart';
import 'package:secret_base_app/screens/secret_base/secret_base_screen.dart';

void main() {
  testWidgets('MemoryListScreen opens the 비밀기지 hub on the 추억 tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MemoryListScreen(baseUrl: 'https://b.test', authHeaders: {}),
      ),
    );
    await tester.pump();
    final hub = tester.widget<SecretBaseScreen>(find.byType(SecretBaseScreen));
    expect(hub.initialTab, 3);
    expect(jsonEncode(hub.authHeaders), '{}');
    await tester.pumpWidget(const SizedBox());
  });
}
