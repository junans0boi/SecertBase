import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 마블 작전 & 윷놀이 공용 캐릭터 정의 — Single Source of Truth
//
// 캐릭터는 직접 그린 Canvas 2D 초상화로 표현됩니다.
// 이모지/이미지 에셋 사용 금지 — 모든 렌더링은 CustomPainter로 구현.
//
// 새 세션에서 캐릭터 구현 시 반드시 이 파일을 먼저 읽을 것.
// ─────────────────────────────────────────────────────────────────────────────

/// 하나의 스파이 에이전트 캐릭터 전체 정의
class MarbleCharacter {
  final String id;           // socket / DB 식별자
  final String name;         // 한글 이름
  final String codename;     // 영문 코드네임
  final String description;  // 1줄 소개
  final String initial;      // 보드 토큰에 그려지는 이니셜 (예: 'K', 'Ω')

  // ── 피부 / 머리 / 의상 색상 ──────────────────────────────────────────────
  final Color skinColor;
  final Color hairColor;
  final Color outfitColor;

  // ── 머리 스타일 ──────────────────────────────────────────────────────────
  /// short | bob | long | silver | spiky | hood
  final String hairStyle;

  // ── 특수 소품 ─────────────────────────────────────────────────────────────
  /// tie | pin | coat | goggles | anchor | mask | none
  final String special;

  // ── 눈 색상 (기본: hairColor 어둡게) ─────────────────────────────────────
  final Color? eyeColor; // null이면 dark brown(#2B1A0E) 기본값 사용

  // ── 상점/인벤토리 슬롯 ───────────────────────────────────────────────────
  /// 'marble_character_m' | 'marble_character_f'
  final String slot;

  // ── DB 아이템 ID (migration 0021_marble_characters.sql 기준) ─────────────
  final int itemId;

  // ── 등급 ─────────────────────────────────────────────────────────────────
  /// 'B' | 'A' | 'S' | 'SS' | 'SSS'
  final String grade;

  // ── 기본 제공 여부 ────────────────────────────────────────────────────────
  final bool isFree; // true면 모든 유저가 처음부터 보유

  const MarbleCharacter({
    required this.id,
    required this.name,
    required this.codename,
    required this.description,
    required this.initial,
    required this.skinColor,
    required this.hairColor,
    required this.outfitColor,
    required this.hairStyle,
    required this.special,
    this.eyeColor,
    required this.slot,
    required this.itemId,
    required this.grade,
    required this.isFree,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 캐릭터 목록 (순서 = 로비/인벤토리 표시 순서)
// ─────────────────────────────────────────────────────────────────────────────

const List<MarbleCharacter> kMarbleCharacters = [

  // ── 01. 케이 — 기본 남성 에이전트 ─────────────────────────────────────────
  MarbleCharacter(
    id: 'k',
    name: '케이',
    codename: 'Agent K',
    description: '침묵의 전문가. 말보다 행동으로 증명하는 베테랑 요원.',
    initial: 'K',
    skinColor:  Color(0xFFC88F60),
    hairColor:  Color(0xFF141420), // 짧고 짙은 검정
    outfitColor: Color(0xFF0C1B2A), // 딥 네이비 수트
    hairStyle: 'short',
    special: 'tie',            // 넥타이
    eyeColor: Color(0xFF3A2010),
    slot: 'marble_character_m',
    itemId: 100,
    grade: 'B',
    isFree: true,
  ),

  // ── 02. 리아 — 기본 여성 에이전트 ─────────────────────────────────────────
  MarbleCharacter(
    id: 'ria',
    name: '리아',
    codename: 'Agent RIA',
    description: '완벽한 위장술과 날카로운 직관. 팀의 두뇌.',
    initial: 'R',
    skinColor:  Color(0xFFE0BFAA),
    hairColor:  Color(0xFF160810), // 다크 밥컷
    outfitColor: Color(0xFF1E2D4A), // 네이비 블레이저
    hairStyle: 'bob',
    special: 'pin',            // 크림슨 핀 악세서리
    eyeColor: Color(0xFF8B1A1A), // 다크레드 눈
    slot: 'marble_character_f',
    itemId: 101,
    grade: 'B',
    isFree: true,
  ),

  // ── 03. 루나 — 보라 파워 ──────────────────────────────────────────────────
  MarbleCharacter(
    id: 'luna',
    name: '루나',
    codename: 'Agent LUNA',
    description: '달의 기운을 담은 신비로운 특수요원. 심리전의 달인.',
    initial: 'L',
    skinColor:  Color(0xFFF2D8BC),
    hairColor:  Color(0xFF5B21B6), // 보라 숏컷
    outfitColor: Color(0xFF5B21B6), // 퍼플 재킷
    hairStyle: 'short', // 보라색 숏컷
    special: 'none',
    eyeColor: Color(0xFF7C3AED),   // 보라 눈
    slot: 'marble_character_f',
    itemId: 102,
    grade: 'A',
    isFree: false,
  ),

  // ── 04. 렉스 — 야전 전문가 ────────────────────────────────────────────────
  MarbleCharacter(
    id: 'rex',
    name: '렉스',
    codename: 'Agent REX',
    description: '최전선 야전 전문가. 어떤 지형에서도 살아남는 생존의 신.',
    initial: 'X',
    skinColor:  Color(0xFFC07840),
    hairColor:  Color(0xFF6B3A12), // 갈색 미디엄 헤어
    outfitColor: Color(0xFF5C3010), // 짙은 갈색 야전복
    hairStyle: 'medium',
    special: 'none',
    eyeColor: Color(0xFF7B4A18),
    slot: 'marble_character_m',
    itemId: 103,
    grade: 'A',
    isFree: false,
  ),

  // ── 05. 지아 — 첩보의 달인 ────────────────────────────────────────────────
  MarbleCharacter(
    id: 'zia',
    name: '지아',
    codename: 'Agent ZIA',
    description: '완벽한 사회 침투 능력. 어디서든 자연스럽게 녹아드는 카멜레온.',
    initial: 'Z',
    skinColor:  Color(0xFFDCCAB4),
    hairColor:  Color(0xFF070C14), // 짙은 검정 롱헤어
    outfitColor: Color(0xFF0E7490), // 틸 컬러 재킷
    hairStyle: 'long',
    special: 'none',
    eyeColor: Color(0xFF164E63),   // 딥 틸 눈
    slot: 'marble_character_f',
    itemId: 104,
    grade: 'A',
    isFree: false,
  ),

  // ── 06. 닥터V — 과학 천재 ─────────────────────────────────────────────────
  MarbleCharacter(
    id: 'drv',
    name: '닥터V',
    codename: 'Dr. VOID',
    description: '조직 최고의 과학 두뇌. 눈에 보이지 않는 위협이 전문.',
    initial: 'V',
    skinColor:  Color(0xFFDCC8A8),
    hairColor:  Color(0xFF8898AA), // 은발
    outfitColor: Color(0xFFD0D8E8), // 흰 실험복
    hairStyle: 'silver', // 은발 (회색빛)
    special: 'coat',           // 흰 코트
    eyeColor: Color(0xFF94A3B8),   // 은회색 눈
    slot: 'marble_character_m',
    itemId: 105,
    grade: 'S',
    isFree: false,
  ),

  // ── 07. 하윤 — 숲의 사냥꾼 ────────────────────────────────────────────────
  MarbleCharacter(
    id: 'hayun',
    name: '하윤',
    codename: 'Agent HAYUN',
    description: '자연과 하나가 되는 숲의 사냥꾼. 아무도 모르게 목표에 접근한다.',
    initial: 'H',
    skinColor:  Color(0xFFC89060),
    hairColor:  Color(0xFF1C1008), // 짙은 검정 숏컷
    outfitColor: Color(0xFF3D5A2A), // 올리브 전투복
    hairStyle: 'short',
    special: 'none',
    eyeColor: Color(0xFF365314),   // 올리브 눈
    slot: 'marble_character_f',
    itemId: 106,
    grade: 'S',
    isFree: false,
  ),

  // ── 08. 제이크 — 해군 특수대 ──────────────────────────────────────────────
  MarbleCharacter(
    id: 'jake',
    name: '제이크',
    codename: 'Agent JAKE',
    description: '해군 특수부대 출신. 바다 위에서도 도시에서도 완벽한 임무 수행.',
    initial: 'J',
    skinColor:  Color(0xFFEACBA0),
    hairColor:  Color(0xFF7B4A18), // 갈색 미디엄
    outfitColor: Color(0xFF1D3461), // 네이비 해군복
    hairStyle: 'medium',
    special: 'anchor',         // 닻 문양
    eyeColor: Color(0xFF1E40AF),   // 딥 블루 눈
    slot: 'marble_character_m',
    itemId: 107,
    grade: 'S',
    isFree: false,
  ),

  // ── 09. 노바 — 폭발 전문가 ────────────────────────────────────────────────
  MarbleCharacter(
    id: 'nova',
    name: '노바',
    codename: 'Agent NOVA',
    description: '폭발물 전문가이자 천재 공학자. 파란 머리카락 한 가닥은 행운의 상징.',
    initial: 'N',
    skinColor:  Color(0xFFD4956A),
    hairColor:  Color(0xFF2C1810),  // 다크브라운 + 파란 섹션
    outfitColor: Color(0xFFC2410C), // 주황 봄버 재킷
    hairStyle: 'spiky',           // 스파이키 + 파란 메쉬 한 가닥
    special: 'goggles',           // 고글 (이마 위에 올라가 있음)
    eyeColor: Color(0xFFB45309),   // 앰버 눈
    slot: 'marble_character_f',
    itemId: 108,
    grade: 'SS',
    isFree: false,
  ),

  // ── 10. 오메가 — 정체불명 ─────────────────────────────────────────────────
  MarbleCharacter(
    id: 'omega',
    name: '오메가',
    codename: 'OMEGA',
    description: '정체도 성별도 나이도 미상. 조직 내 가장 두려운 이름.',
    initial: 'Ω',
    skinColor:  Color(0xFF101418), // 마스크로 가려짐 (사실상 미사용)
    hairColor:  Color(0xFF050810), // 전신 후드
    outfitColor: Color(0xFF080C10), // 올블랙
    hairStyle: 'hood',            // 풀 후드 (머리카락 없음)
    special: 'mask',              // 마스크 + 초록 발광 눈만 보임
    eyeColor: Color(0xFF00FF88),   // 발광 초록 눈 (유일한 식별자)
    slot: 'marble_character_m',   // 슬롯은 m이지만 성별 미상
    itemId: 109,
    grade: 'SSS',
    isFree: false,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// 편의 접근자
// ─────────────────────────────────────────────────────────────────────────────

/// ID로 캐릭터 조회 (없으면 null)
MarbleCharacter? marbleCharById(String id) {
  try {
    return kMarbleCharacters.firstWhere((c) => c.id == id);
  } catch (_) {
    return null;
  }
}

/// 소켓/서버에서 쓰는 ID 목록 (socket.js marbleCharacterIds 와 동일하게 유지)
const List<String> kMarbleCharacterIds = [
  'k', 'ria', 'luna', 'rex', 'zia', 'drv', 'hayun', 'jake', 'nova', 'omega',
];

/// 기본 제공 캐릭터 (free: true)
const List<String> kFreeMarbleCharacterIds = ['k', 'ria'];

/// 남성 슬롯 캐릭터 IDs
const List<String> kMarbleMaleIds = ['k', 'rex', 'drv', 'jake', 'omega'];

/// 여성 슬롯 캐릭터 IDs
const List<String> kMarbleFemaleIds = ['ria', 'luna', 'zia', 'hayun', 'nova'];
