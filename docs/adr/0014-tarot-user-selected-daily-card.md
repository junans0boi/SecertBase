# 타로는 사용자가 고른 한 장을 하루 동안 고정한다

status: accepted
date: 2026-09-10

## Context

기존 타로 vertical slice는 날짜·범위·카탈로그 버전으로 서버가 카드를 자동
선택했다. 결과는 결정론적이었지만 사용자가 카드를 고르는 순간과 기대감이 없어,
타로를 직접 해보는 재미가 약했다.

## Decision

- 개인과 활성 Couple은 각각 하루에 한 번, 메이저 아르카나 22장 중 한 장을 직접
  선택한다.
- `GET /api/relationship/tarot/today`에서 아직 선택하지 않은 범위는 카드 본문 없이
  `drawRequired: true`와 22장의 선택용 `key`·`position` 목록을 반환한다.
- `POST /api/relationship/tarot/today/draw`는 `scope`와 `cardKey`를 받아 선택한
  카드를 날짜·카탈로그 버전·범위에 저장한다. 활성 Couple 선택은 양쪽에 같은 카드가
  보인다.
- 선택 후에는 같은 날짜에 다른 카드를 선택할 수 없고, 재추첨 endpoint와 스프레드는
  제공하지 않는다. 이미 선택된 범위의 재선택은 `tarot_already_drawn`으로 거절한다.
- 카드 본문은 계속 정방향만 사용하고, 자기성찰용 안내와 사실 예측·진단 아님을
  함께 표시한다.
- 이전 자동 선택 row는 `selected_by_user = 0`으로 남아 미추첨처럼 보여준다. 첫
  명시적 선택 시 해당 row를 새 계약의 선택 row로 교체할 수 있다.

## Consequences

- 타로 화면에 카드 뒷면 선택 UI가 생겨 결과를 직접 고르는 경험을 제공한다.
- 날짜와 범위가 같으면 재방문해도 사용자가 선택한 카드가 유지된다.
- 카드 선택 전에는 해석 내용을 노출하지 않아 선택 순간의 의미를 보존한다.
- 저장 계약에는 자동 생성과 사용자 선택을 구분하는 `selected_by_user`가 필요하다.
