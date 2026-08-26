/**
 * 마블 작전 캐릭터 정의 — Single Source of Truth (Node.js 버전)
 *
 * Flutter 버전: apps/secret_base_app/lib/core/marble_characters.dart
 * 두 파일의 id, itemId, slot, grade, isFree 는 항상 동일하게 유지할 것.
 *
 * 새 세션에서 캐릭터 작업 시 반드시 이 파일을 먼저 읽을 것.
 * 이모지/이미지 에셋 사용 금지 — 모든 렌더링은 Canvas CustomPainter.
 */

export const MARBLE_CHARACTERS = [
  {
    id:          'k',
    name:        '케이',
    codename:    'Agent K',
    description: '침묵의 전문가. 말보다 행동으로 증명하는 베테랑 요원.',
    initial:     'K',
    // Canvas 색상 (0xAARRGGBB → '#RRGGBB')
    skinColor:   '#C88F60',
    hairColor:   '#141420',  // 짧고 짙은 검정
    outfitColor: '#0C1B2A',  // 딥 네이비 수트
    eyeColor:    '#3A2010',
    hairStyle:   'short',
    special:     'tie',      // 넥타이
    slot:        'marble_character_m',
    itemId:      100,
    grade:       'B',
    isFree:      true,
  },
  {
    id:          'ria',
    name:        '리아',
    codename:    'Agent RIA',
    description: '완벽한 위장술과 날카로운 직관. 팀의 두뇌.',
    initial:     'R',
    skinColor:   '#E0BFAA',
    hairColor:   '#160810',  // 다크 밥컷
    outfitColor: '#1E2D4A',  // 네이비 블레이저
    eyeColor:    '#8B1A1A',  // 다크레드 눈
    hairStyle:   'bob',
    special:     'pin',      // 크림슨 핀 악세서리
    slot:        'marble_character_f',
    itemId:      101,
    grade:       'B',
    isFree:      true,
  },
  {
    id:          'luna',
    name:        '루나',
    codename:    'Agent LUNA',
    description: '달의 기운을 담은 신비로운 특수요원. 심리전의 달인.',
    initial:     'L',
    skinColor:   '#F2D8BC',
    hairColor:   '#5B21B6',  // 보라 숏컷
    outfitColor: '#5B21B6',  // 퍼플 재킷
    eyeColor:    '#7C3AED',  // 보라 눈
    hairStyle:   'short',    // 보라색 숏컷
    special:     'none',
    slot:        'marble_character_f',
    itemId:      102,
    grade:       'A',
    isFree:      false,
  },
  {
    id:          'rex',
    name:        '렉스',
    codename:    'Agent REX',
    description: '최전선 야전 전문가. 어떤 지형에서도 살아남는 생존의 신.',
    initial:     'X',
    skinColor:   '#C07840',
    hairColor:   '#6B3A12',  // 갈색 미디엄
    outfitColor: '#5C3010',  // 짙은 갈색 야전복
    eyeColor:    '#7B4A18',
    hairStyle:   'medium',
    special:     'none',
    slot:        'marble_character_m',
    itemId:      103,
    grade:       'A',
    isFree:      false,
  },
  {
    id:          'zia',
    name:        '지아',
    codename:    'Agent ZIA',
    description: '완벽한 사회 침투 능력. 어디서든 자연스럽게 녹아드는 카멜레온.',
    initial:     'Z',
    skinColor:   '#DCCAB4',
    hairColor:   '#070C14',  // 짙은 검정 롱헤어
    outfitColor: '#0E7490',  // 틸 컬러 재킷
    eyeColor:    '#164E63',  // 딥 틸 눈
    hairStyle:   'long',
    special:     'none',
    slot:        'marble_character_f',
    itemId:      104,
    grade:       'A',
    isFree:      false,
  },
  {
    id:          'drv',
    name:        '닥터V',
    codename:    'Dr. VOID',
    description: '조직 최고의 과학 두뇌. 눈에 보이지 않는 위협이 전문.',
    initial:     'V',
    skinColor:   '#DCC8A8',
    hairColor:   '#8898AA',  // 은발
    outfitColor: '#D0D8E8',  // 흰 실험복
    eyeColor:    '#94A3B8',  // 은회색 눈
    hairStyle:   'silver',   // 은발
    special:     'coat',     // 흰 코트
    slot:        'marble_character_m',
    itemId:      105,
    grade:       'S',
    isFree:      false,
  },
  {
    id:          'hayun',
    name:        '하윤',
    codename:    'Agent HAYUN',
    description: '자연과 하나가 되는 숲의 사냥꾼. 아무도 모르게 목표에 접근한다.',
    initial:     'H',
    skinColor:   '#C89060',
    hairColor:   '#1C1008',  // 짙은 검정 숏컷
    outfitColor: '#3D5A2A',  // 올리브 전투복
    eyeColor:    '#365314',  // 올리브 눈
    hairStyle:   'short',
    special:     'none',
    slot:        'marble_character_f',
    itemId:      106,
    grade:       'S',
    isFree:      false,
  },
  {
    id:          'jake',
    name:        '제이크',
    codename:    'Agent JAKE',
    description: '해군 특수부대 출신. 바다 위에서도 도시에서도 완벽한 임무 수행.',
    initial:     'J',
    skinColor:   '#EACBA0',
    hairColor:   '#7B4A18',  // 갈색 미디엄
    outfitColor: '#1D3461',  // 네이비 해군복
    eyeColor:    '#1E40AF',  // 딥 블루 눈
    hairStyle:   'medium',
    special:     'anchor',   // 닻 문양
    slot:        'marble_character_m',
    itemId:      107,
    grade:       'S',
    isFree:      false,
  },
  {
    id:          'nova',
    name:        '노바',
    codename:    'Agent NOVA',
    description: '폭발물 전문가이자 천재 공학자. 파란 머리카락 한 가닥은 행운의 상징.',
    initial:     'N',
    skinColor:   '#D4956A',
    hairColor:   '#2C1810',  // 다크브라운 + 파란 섹션 한 가닥
    outfitColor: '#C2410C',  // 주황 봄버 재킷
    eyeColor:    '#B45309',  // 앰버 눈
    hairStyle:   'spiky',    // 스파이키 + 파란 메쉬 한 가닥 (color: #2563EB)
    special:     'goggles',  // 고글 (이마에 올려져 있음)
    slot:        'marble_character_f',
    itemId:      108,
    grade:       'SS',
    isFree:      false,
  },
  {
    id:          'omega',
    name:        '오메가',
    codename:    'OMEGA',
    description: '정체도 성별도 나이도 미상. 조직 내 가장 두려운 이름.',
    initial:     'Ω',
    skinColor:   '#101418',  // 마스크로 가려짐 (렌더링 시 무시)
    hairColor:   '#050810',  // 전신 후드
    outfitColor: '#080C10',  // 올블랙
    eyeColor:    '#00FF88',  // 발광 초록 눈 (유일한 식별자)
    hairStyle:   'hood',     // 풀 후드 — 머리카락 없음, 후드만 그림
    special:     'mask',     // 얼굴 전체 마스크, 눈만 초록 발광
    slot:        'marble_character_m', // 슬롯은 m이지만 성별 미상
    itemId:      109,
    grade:       'SSS',
    isFree:      false,
  },
];

// ── 편의 접근자 ──────────────────────────────────────────────────────────────

/** ID로 캐릭터 조회 */
export const getCharById = (id) => MARBLE_CHARACTERS.find((c) => c.id === id) ?? null;

/** 소켓 스키마 검증용 ID 배열 (socket.js의 marbleCharacterIds 와 동기화) */
export const MARBLE_CHARACTER_IDS = MARBLE_CHARACTERS.map((c) => c.id);
// → ['k','ria','luna','rex','zia','drv','hayun','jake','nova','omega']

export const FREE_CHARACTER_IDS = MARBLE_CHARACTERS.filter((c) => c.isFree).map((c) => c.id);
// → ['k', 'ria']
