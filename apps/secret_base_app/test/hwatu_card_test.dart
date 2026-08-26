import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/ui/hwatu_card.dart';

const _referenceXs = [9, 73, 137, 201, 268, 332, 396, 460];
const _referenceYs = [8, 102, 197, 293, 388, 483];
const _referenceLayout = [
  [
    'm1_bright',
    'm1_animal',
    'm1_junk_1',
    'm1_junk_2',
    'm7_animal_1',
    'm7_animal_2',
    'm7_junk_1',
    'm7_junk_2',
  ],
  [
    'm2_animal',
    'm2_ribbon',
    'm2_junk_1',
    'm2_junk_2',
    'm8_bright',
    'm8_animal',
    'm8_junk_1',
    'm8_junk_2',
  ],
  [
    'm3_bright',
    'm3_ribbon',
    'm3_junk_1',
    'm3_junk_2',
    'm9_animal',
    'm9_ribbon',
    'm9_junk_1',
    'm9_junk_2',
  ],
  [
    'm4_animal',
    'm4_ribbon',
    'm4_junk_1',
    'm4_junk_2',
    'm10_animal',
    'm10_ribbon',
    'm10_junk_1',
    'm10_junk_2',
  ],
  [
    'm5_animal',
    'm5_ribbon',
    'm5_junk_1',
    'm5_junk_2',
    'm11_bright',
    'm11_junk_d',
    'm11_junk_1',
    'm11_junk_2',
  ],
  [
    'm6_animal',
    'm6_ribbon',
    'm6_junk_1',
    'm6_junk_2',
    'm12_bright',
    'm12_animal',
    'm12_ribbon',
    'm12_junk_d',
  ],
];

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<Uint8List> _rgba(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) throw StateError('이미지 픽셀을 읽을 수 없습니다');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('화투 48장 그림이 모두 앱 자산에 포함된다', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest
        .listAssets()
        .where(
          (path) =>
              path.startsWith('assets/images/hwatu/') && path.endsWith('.png'),
        )
        .toList();

    expect(paths, hasLength(48));
    for (final path in paths) {
      final bytes = await rootBundle.load(path);
      expect(bytes.lengthInBytes, greaterThan(0), reason: path);
    }
  });

  test('48장 그림이 첨부 원본의 해당 카드 픽셀과 일치한다', () async {
    final referenceBytes = await File(
      'test/fixtures/hwatu_reference_sheet.png',
    ).readAsBytes();
    final referenceImage = await _decode(referenceBytes);
    final referencePixels = await _rgba(referenceImage);

    for (var row = 0; row < _referenceLayout.length; row++) {
      for (var col = 0; col < _referenceLayout[row].length; col++) {
        final cardId = _referenceLayout[row][col];
        final assetData = await rootBundle.load(hwatuCardAssetPath(cardId));
        final assetImage = await _decode(
          assetData.buffer.asUint8List(
            assetData.offsetInBytes,
            assetData.lengthInBytes,
          ),
        );
        expect(assetImage.width, 60, reason: cardId);
        expect(assetImage.height, 91, reason: cardId);
        final assetPixels = await _rgba(assetImage);

        int? mismatch;
        for (var y = 0; y < 91 && mismatch == null; y++) {
          for (var x = 0; x < 60 && mismatch == null; x++) {
            final assetOffset = (y * 60 + x) * 4;
            final referenceOffset =
                ((_referenceYs[row] + y) * referenceImage.width +
                    _referenceXs[col] +
                    x) *
                4;
            for (var channel = 0; channel < 4; channel++) {
              if (assetPixels[assetOffset + channel] !=
                  referencePixels[referenceOffset + channel]) {
                mismatch = assetOffset + channel;
                break;
              }
            }
          }
        }

        expect(mismatch, isNull, reason: '$cardId 원본 픽셀 불일치');
        assetImage.dispose();
      }
    }
    referenceImage.dispose();
  });

  testWidgets('앞면은 원본 비율을 유지하고 탭·강조 동작을 보존한다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: HwatuCard(
            width: 60,
            highlighted: true,
            onTap: () => taps++,
            card: const {
              'id': 'm1_bright',
              'month': 1,
              'type': 'bright',
              'subtype': null,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    expect(provider.assetName, 'assets/images/hwatu/m1_bright.png');
    expect(tester.getSize(find.byType(AnimatedContainer)), const Size(60, 91));

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.boxShadow, hasLength(1));
    expect(
      decoration.boxShadow!.single.color,
      kHwatuGold.withValues(alpha: 0.9),
    );

    await tester.tap(find.byType(HwatuCard));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('뒷면은 기존 코드 그림을 유지한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: HwatuCard(card: null))),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('앞면을 길게 누르면 카드 상세 동작을 호출할 수 있다', (tester) async {
    var longPresses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: HwatuCard(
            card: const {
              'id': 'm8_animal',
              'month': 8,
              'type': 'animal',
              'subtype': null,
            },
            onLongPress: () => longPresses++,
          ),
        ),
      ),
    );

    await tester.longPress(find.byType(HwatuCard));
    expect(longPresses, 1);
  });
}
