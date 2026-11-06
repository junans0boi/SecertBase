// 화투 48장의 정체성(월·종류·띠 종류·쌍피·비광).
//
// 서버 엔진 `services/realtime-server/src/gostop-engine.js`의 `DECK_DEF`를
// 그대로 옮긴 표다. 카드 id가 정본이며, 엔진처럼 과거 id 호환 표기
// (`m1_animal`은 실제로 홍단 띠, `m7_animal_2`는 초단 띠)도 id 기준으로 따른다.

/// 화투 종류. 엔진의 `type` 문자열과 같은 이름을 쓴다.
enum HwatuType {
  bright('bright', '광'),
  animal('animal', '열'),
  ribbon('ribbon', '띠'),
  junk('junk', '피');

  const HwatuType(this.wire, this.short);

  /// 엔진 JSON의 `type` 값.
  final String wire;

  /// 모서리 배지에 쓰는 한 글자.
  final String short;

  static HwatuType? fromWire(Object? value) {
    for (final t in values) {
      if (t.wire == value) return t;
    }
    return null;
  }
}

/// 띠 종류. 홍단(붉은 띠 + 시구 무늬), 청단(푸른 띠), 초단(무늬 없는 붉은 띠).
enum HwatuRibbon { hong, cheong, cho }

/// 카드 한 장의 정체성.
class HwatuCardSpec {
  const HwatuCardSpec(this.id, this.month, this.type, [this.subtype]);

  /// 엔진 카드 id (예: `m3_bright`, `m11_junk_d`).
  final String id;

  /// 1–12월.
  final int month;
  final HwatuType type;

  /// 엔진 `subtype`: `rain`(비광), `double`(쌍피), `red`(홍단), `blue`(청단),
  /// null(일반).
  final String? subtype;

  bool get isDouble => subtype == 'double';
  bool get isRain => subtype == 'rain';

  /// 띠 카드일 때만 의미가 있다.
  HwatuRibbon? get ribbon {
    if (type != HwatuType.ribbon) return null;
    return switch (subtype) {
      'red' => HwatuRibbon.hong,
      'blue' => HwatuRibbon.cheong,
      _ => HwatuRibbon.cho,
    };
  }

  /// 같은 달의 피 중 두 번째 그림(좌우 반전 변주)인지.
  bool get isSecondJunk => id.endsWith('_junk_2');

  /// 접근성 라벨 (예: "3월 벚꽃 광").
  String get label {
    final kind = switch (type) {
      HwatuType.bright => isRain ? '비광' : '광',
      HwatuType.animal => '열끗',
      HwatuType.ribbon => switch (ribbon!) {
        HwatuRibbon.hong => '홍단 띠',
        HwatuRibbon.cheong => '청단 띠',
        HwatuRibbon.cho => '초단 띠',
      },
      HwatuType.junk => isDouble ? '쌍피' : '피',
    };
    return '$month월 ${kHwatuMonthNames[month] ?? ''} $kind';
  }

  @override
  String toString() => 'HwatuCardSpec($id)';
}

const Map<int, String> kHwatuMonthNames = {
  1: '송학',
  2: '매조',
  3: '벚꽃',
  4: '흑싸리',
  5: '난초',
  6: '모란',
  7: '홍싸리',
  8: '공산',
  9: '국화',
  10: '단풍',
  11: '오동',
  12: '비',
};

const _b = HwatuType.bright;
const _a = HwatuType.animal;
const _r = HwatuType.ribbon;
const _j = HwatuType.junk;

/// 엔진 `DECK_DEF`와 같은 순서의 48장.
const List<HwatuCardSpec> kHwatuDeck = [
  HwatuCardSpec('m1_bright', 1, _b),
  HwatuCardSpec('m1_animal', 1, _r, 'red'), // 호환 id, 실제는 홍단 띠
  HwatuCardSpec('m1_junk_1', 1, _j),
  HwatuCardSpec('m1_junk_2', 1, _j),
  HwatuCardSpec('m2_animal', 2, _a),
  HwatuCardSpec('m2_ribbon', 2, _r, 'red'),
  HwatuCardSpec('m2_junk_1', 2, _j),
  HwatuCardSpec('m2_junk_2', 2, _j),
  HwatuCardSpec('m3_bright', 3, _b),
  HwatuCardSpec('m3_ribbon', 3, _r, 'red'),
  HwatuCardSpec('m3_junk_1', 3, _j),
  HwatuCardSpec('m3_junk_2', 3, _j),
  HwatuCardSpec('m4_animal', 4, _a),
  HwatuCardSpec('m4_ribbon', 4, _r),
  HwatuCardSpec('m4_junk_1', 4, _j),
  HwatuCardSpec('m4_junk_2', 4, _j),
  HwatuCardSpec('m5_animal', 5, _a),
  HwatuCardSpec('m5_ribbon', 5, _r),
  HwatuCardSpec('m5_junk_1', 5, _j),
  HwatuCardSpec('m5_junk_2', 5, _j),
  HwatuCardSpec('m6_animal', 6, _a),
  HwatuCardSpec('m6_ribbon', 6, _r, 'blue'),
  HwatuCardSpec('m6_junk_1', 6, _j),
  HwatuCardSpec('m6_junk_2', 6, _j),
  HwatuCardSpec('m7_animal_1', 7, _a),
  HwatuCardSpec('m7_animal_2', 7, _r), // 호환 id, 실제는 초단 띠
  HwatuCardSpec('m7_junk_1', 7, _j),
  HwatuCardSpec('m7_junk_2', 7, _j),
  HwatuCardSpec('m8_bright', 8, _b),
  HwatuCardSpec('m8_animal', 8, _a),
  HwatuCardSpec('m8_junk_1', 8, _j),
  HwatuCardSpec('m8_junk_2', 8, _j),
  HwatuCardSpec('m9_animal', 9, _a),
  HwatuCardSpec('m9_ribbon', 9, _r, 'blue'),
  HwatuCardSpec('m9_junk_1', 9, _j),
  HwatuCardSpec('m9_junk_2', 9, _j),
  HwatuCardSpec('m10_animal', 10, _a),
  HwatuCardSpec('m10_ribbon', 10, _r, 'blue'),
  HwatuCardSpec('m10_junk_1', 10, _j),
  HwatuCardSpec('m10_junk_2', 10, _j),
  HwatuCardSpec('m11_bright', 11, _b),
  HwatuCardSpec('m11_junk_1', 11, _j),
  HwatuCardSpec('m11_junk_2', 11, _j),
  HwatuCardSpec('m11_junk_d', 11, _j, 'double'),
  HwatuCardSpec('m12_bright', 12, _b, 'rain'),
  HwatuCardSpec('m12_animal', 12, _a),
  HwatuCardSpec('m12_ribbon', 12, _r),
  HwatuCardSpec('m12_junk_d', 12, _j, 'double'),
];

final Map<String, HwatuCardSpec> _byId = {
  for (final spec in kHwatuDeck) spec.id: spec,
};

/// id로 카드 정체성을 찾는다. 모르는 id면 null.
HwatuCardSpec? hwatuSpecById(String? id) => id == null ? null : _byId[id];

/// 게임 상태의 카드 맵(`{id, month, type, subtype}`)을 정체성으로 바꾼다.
///
/// 엔진과 같이 id가 정본이다. 표에 없는 id면 맵의 month/type/subtype으로
/// 만든다(그림은 그 달의 피 그림으로 그린다). 뒷면(`null`/`id == 'back'`)이나
/// 읽을 수 없는 맵이면 null.
HwatuCardSpec? hwatuSpecFromCard(Map<String, dynamic>? card) {
  if (card == null) return null;
  final id = card['id'];
  if (id is! String || id == 'back') return null;
  final known = _byId[id];
  if (known != null) return known;
  final month = (card['month'] as num?)?.toInt();
  final type = HwatuType.fromWire(card['type']);
  if (month == null || month < 1 || month > 12 || type == null) return null;
  return HwatuCardSpec(id, month, type, card['subtype'] as String?);
}
