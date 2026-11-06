import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/v2/gallery/v2_gallery_screen.dart';
import 'package:secret_base_app/v2/v2.dart';

Widget _host(Widget child, {bool reducedMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      disableAnimations: reducedMotion,
    ),
    child: V2Theme(
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    ),
  ),
);

/// Performs a semantic tap the way a screen reader / Flutter web does.
Future<void> _semanticTap(WidgetTester tester, Finder finder) async {
  final node = tester.getSemantics(finder);
  expect(
    node.getSemanticsData().hasAction(SemanticsAction.tap),
    isTrue,
    reason: 'semantics node has no tap action',
  );
  node.owner!.performAction(node.id, SemanticsAction.tap);
  await tester.pump();
}

void main() {
  testWidgets('gallery renders every component without errors', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: V2GalleryScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('디자인 시스템'), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('더보기'), findsOneWidget);

    // Scroll through the whole gallery so every section builds.
    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 40; i++) {
      await tester.drag(list, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);

    // Dark variant renders too.
    await tester.tap(find.byTooltip('어두운 화면으로'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('밝은 화면으로'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('V2Button: semantic tap fires, loading and disabled ignore', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            V2Button(label: '기록 남기기', onPressed: () => taps++),
            V2Button(label: '저장', loading: true, onPressed: () => taps++),
            const V2Button(label: '비활성', onPressed: null),
          ],
        ),
      ),
    );
    await _semanticTap(tester, find.text('기록 남기기'));
    expect(taps, 1);
    await tester.tap(find.text('기록 남기기'));
    expect(taps, 2);

    final loading = tester.getSemantics(find.bySemanticsLabel('저장'));
    expect(loading.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    expect(tester.getSize(find.byType(TextButton).first).height, 52);
    handle.dispose();
  });

  testWidgets('V2Chip: semantic tap selects, exposes selected flag', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var selected = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _host(
          Wrap(
            children: [
              for (var i = 0; i < 2; i++)
                V2Chip(
                  label: i == 0 ? '전체' : '가 본 곳',
                  selected: selected == i,
                  onTap: () => setState(() => selected = i),
                ),
            ],
          ),
        ),
      ),
    );
    await _semanticTap(tester, find.text('가 본 곳'));
    expect(selected, 1);
    final data = tester.getSemantics(find.text('가 본 곳')).getSemanticsData();
    expect(data.flagsCollection.isSelected, Tristate.isTrue);
    expect(
      tester.getSize(find.byType(InkWell).first).height,
      greaterThanOrEqualTo(44),
    );
    handle.dispose();
  });

  testWidgets('V2Toggle and V2Check: semantic tap flips the value', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var on = false;
    var checked = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _host(
          Column(
            children: [
              V2Toggle(
                value: on,
                onChanged: (v) => setState(() => on = v),
                semanticLabel: '알림 받기',
              ),
              V2Check(
                value: checked,
                onChanged: (v) => setState(() => checked = v),
                label: '(필수) 이용약관에 동의해요',
              ),
            ],
          ),
        ),
      ),
    );
    await _semanticTap(tester, find.bySemanticsLabel('알림 받기'));
    expect(on, isTrue);
    final toggleData = tester
        .getSemantics(find.bySemanticsLabel('알림 받기'))
        .getSemanticsData();
    expect(toggleData.flagsCollection.isToggled, Tristate.isTrue);

    await _semanticTap(tester, find.text('(필수) 이용약관에 동의해요'));
    expect(checked, isTrue);
    expect(tester.getSize(find.byType(V2Toggle)).height, 44);
    handle.dispose();
  });

  testWidgets('V2Segmented, V2ListTile, V2Card: semantic taps work', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var seg = 0;
    var row = 0;
    var card = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _host(
          Column(
            children: [
              V2Segmented<int>(
                segments: const [
                  V2Segment(value: 0, label: '나'),
                  V2Segment(value: 1, label: '우리'),
                ],
                selected: seg,
                onChanged: (v) => setState(() => seg = v),
              ),
              V2List(
                children: [
                  V2ListTile(
                    icon: V2Icons.event,
                    title: '기념일',
                    subtitle: '88일 남음',
                    onTap: () => row++,
                  ),
                ],
              ),
              V2Card(onTap: () => card++, child: const Text('오늘의 기록')),
            ],
          ),
        ),
      ),
    );
    await _semanticTap(tester, find.text('우리'));
    expect(seg, 1);
    await _semanticTap(tester, find.text('기념일'));
    expect(row, 1);
    await _semanticTap(tester, find.text('오늘의 기록'));
    expect(card, 1);
    handle.dispose();
  });

  testWidgets('V2BottomTabBar: five Korean tabs, semantic tap switches', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var index = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          home: Scaffold(
            bottomNavigationBar: V2BottomTabBar(
              currentIndex: index,
              onTap: (i) => setState(() => index = i),
              badges: const {1: 2},
            ),
          ),
        ),
      ),
    );
    for (final label in ['홈', '기록', '지도', '놀이', '더보기']) {
      expect(find.text(label), findsOneWidget);
    }
    await _semanticTap(tester, find.bySemanticsLabel(RegExp('^지도')));
    expect(index, 2);
    await tester.tap(find.text('더보기'));
    expect(index, 4);
    handle.dispose();
  });

  testWidgets('V2TextField: password toggle and error message', (tester) async {
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            V2TextField(label: '비밀번호', password: true),
            V2TextField(label: '이름', error: '이름을 입력해 주세요'),
          ],
        ),
      ),
    );
    EditableText editable() =>
        tester.widget<EditableText>(find.byType(EditableText).first);
    expect(editable().obscureText, isTrue);
    await tester.tap(find.byTooltip('비밀번호 보기'));
    await tester.pump();
    expect(editable().obscureText, isFalse);
    expect(find.text('이름을 입력해 주세요'), findsOneWidget);
  });

  testWidgets('showV2Confirm resolves true on confirm, false on cancel', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: V2Button(
                label: '열기',
                onPressed: () async {
                  result = await showV2Confirm(
                    context,
                    title: '기록을 지울까요?',
                    confirmLabel: '지우기',
                    destructive: true,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('기록을 지울까요?'), findsOneWidget);
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();
    expect(result, isTrue);

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('permission sheet returns the choice; denied offers settings', (
    tester,
  ) async {
    V2PermissionChoice? choice;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                V2Button(
                  label: '위치',
                  onPressed: () async => choice = await showV2PermissionSheet(
                    context,
                    V2PermissionKind.location,
                  ),
                ),
                V2Button(
                  label: '거부됨',
                  onPressed: () async => choice = await showV2PermissionSheet(
                    context,
                    V2PermissionKind.camera,
                    denied: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('위치'));
    await tester.pumpAndSettle();
    expect(find.text('위치 권한이 필요해요'), findsOneWidget);
    await tester.tap(find.text('허용하기'));
    await tester.pumpAndSettle();
    expect(choice, V2PermissionChoice.allow);

    await tester.tap(find.text('거부됨'));
    await tester.pumpAndSettle();
    expect(find.text('설정에서 카메라 권한을 켜 주세요'), findsOneWidget);
    await tester.tap(find.text('설정 열기'));
    await tester.pumpAndSettle();
    expect(choice, V2PermissionChoice.openSettings);
  });

  testWidgets('destructive sheet keeps confirm disabled until acknowledged', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: V2Button(
              label: '탈퇴',
              onPressed: () async =>
                  result = await showV2ConfirmDestructiveSheet(
                    context,
                    title: '정말 탈퇴할까요?',
                    consequences: const ['기록이 삭제돼요'],
                    acknowledgement: '확인했어요',
                    confirmLabel: '탈퇴하기',
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('탈퇴'));
    await tester.pumpAndSettle();
    TextButton confirm() => tester.widget<TextButton>(
      find.ancestor(of: find.text('탈퇴하기'), matching: find.byType(TextButton)),
    );
    expect(confirm().onPressed, isNull);
    await tester.tap(find.text('확인했어요'));
    await tester.pump();
    expect(confirm().onPressed, isNotNull);
    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('showV2Snack shows message and action', (tester) async {
    var undone = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: V2Button(
              label: '지우기',
              onPressed: () => showV2Snack(
                context,
                '기록을 지웠어요',
                actionLabel: '되돌리기',
                onAction: () => undone = true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();
    expect(find.text('기록을 지웠어요'), findsOneWidget);
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(undone, isTrue);
  });

  testWidgets('skeleton is static under reduced motion and announces loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const V2SkeletonList(count: 2), reducedMotion: true),
    );
    // No ticking animation: settles immediately.
    await tester.pumpAndSettle();
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.bySemanticsLabel('불러오는 중이에요'), findsOneWidget);

    await tester.pumpWidget(_host(const V2SkeletonCard()));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets('states, banner, header and misc components render', (
    tester,
  ) async {
    var retried = false;
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: V2Theme(
          child: Scaffold(
            appBar: const V2Header(title: '알림 설정', showBack: true),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  V2ErrorState(onRetry: () => retried = true),
                  const V2EmptyState(
                    illustration: V2SceneIllustration(V2Scene.map),
                    title: '아직 장소가 없어요',
                  ),
                  V2Banner(
                    message: '새 기능이 생겼어요',
                    onDismiss: () => dismissed = true,
                  ),
                  const V2Section(title: '우리 이야기', actionLabel: '전체 보기'),
                  const V2AvatarPair(me: '민지', partner: '서윤'),
                  const V2Badge(count: 120),
                  const V2ProgressRing(value: 0.5),
                  const V2ProgressBar(value: 0.3),
                  const SizedBox(
                    width: 100,
                    child: V2PhotoPlaceholder(seed: 1, aspectRatio: 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('99+'), findsOneWidget);
    expect(find.byTooltip('뒤로 가기'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    expect(retried, isTrue);
    await tester.tap(find.byTooltip('닫기'));
    expect(dismissed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('interactive components meet the 44px tap target guideline', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            V2IconButton(icon: V2Icons.bell, tooltip: '알림', onPressed: () {}),
            V2Chip(label: '전체', onTap: () {}),
            V2Toggle(value: true, onChanged: (_) {}, semanticLabel: '알림'),
            V2Check(value: false, onChanged: (_) {}, semanticLabel: '동의'),
            V2Button(label: '저장', size: V2ButtonSize.sm, onPressed: () {}),
          ],
        ),
      ),
    );
    await expectLater(
      tester,
      meetsGuideline(
        const MinimumTapTargetGuideline(
          size: Size(44, 44),
          link: 'https://www.w3.org/WAI/WCAG21/Understanding/target-size.html',
        ),
      ),
    );
    handle.dispose();
  });
}
