# 03. Wayfinder Map — 게임 2.0 3차

> 상태: 구현·통합·병합 완료, **운영 배포는 마이그레이션 오류 수정 대기**(#255). 근거: `02-spec.md`.

## Destination
윷놀이·텔레파시·원카드·블랙잭·도둑잡기·패널티킥이 확정된 디자인으로 운영에 반영되고, 윷 상점 전환 마이그레이션이 운영 DB에 적용된 상태.

## Notes
- 디자인은 HTML 목업 → 사용자 선택 → Flutter 구현 순서로 진행(목업 2차에서 윷만 방향 전환).
- 병합: 게임별 작업 공간에서 구현 → 통합 브랜치 `feat/games-v2-r3-integ` → PR #253 → main.
- 운영 배포는 main 병합이 자동 실행(빌드 → DB 마이그레이션 → 웹 교체·서버 재시작).

## Tickets
| # | 제목 | 종류 | 상태 |
|---|---|---|---|
| 31 | [윷놀이 시스템 — 캐릭터 능력치·윷 스킨·마이그레이션](issues/31-yut-system.md) | server+client | 완료 |
| 32 | [윷놀이 새 디자인 — 낮/밤 랜덤](issues/32-yut-design.md) | client | 완료 |
| 33 | [텔레파시 B안 + 맵기 3단계·19+](issues/33-telepathy-heat.md) | server+client | 완료 |
| 34 | [텔레파시·재대결 버그 3종](issues/34-telepathy-fixes.md) | server+client | 완료 |
| 35 | [원카드 디자인](issues/35-onecard-design.md) | client | 완료 |
| 36 | [블랙잭·도둑잡기 디자인·글꼴](issues/36-blackjack-oldmaid-design.md) | client | 완료 |
| 37 | [패널티킥 로비·결과 디자인](issues/37-penalty-lobby-result.md) | client | 완료 |
| 38 | [디자인 목업 검토·결정](issues/38-design-mockups.md) | design | 완료 |
| 39 | [운영 배포 — 0049 마이그레이션 ENUM 오류 수정](issues/39-prod-deploy-fix.md) | server | **진행 중** |
| 40 | [핵폭탄 매운맛 경고문 강화](issues/40-nuclear-warning.md) | client | **진행 중** |

## 진행 순서(실제)
1. 목업 10종(탭) → 결정 → 2. 구현 6건 병렬 → 3. 통합·테스트·실플레이 확인 → 4. 질문 은행 재조정 → 5. PR #253 병합 → 6. 배포 중 마이그레이션 오류 → 7. #255 수정.

## 위험·교훈
| ID | 내용 | 대응 |
|---|---|---|
| R1 | 마이그레이션이 ENUM에 없는 효과 키를 넣어 운영 배포가 멈춤 | #255 수정 + `migration-stat-keys.test.js`(ENUM을 마이그레이션 순서대로 따라가며 INSERT 검사) |
| R2 | 시험 서버·시험 환경 글꼴이 달라 골든에 한글/이모지가 대체 글꼴로 나옴 | 실제 앱 캡처(캔버스 저장)로 별도 확인 |
| R3 | `Semantics(button)`에 `onTap`이 없으면 접근성 켜진 환경에서 탭이 먹지 않음 | 텔레파시 3곳 수정(#34) |
| R4 | 에이전트가 `node_modules` 심볼릭 링크를 커밋 | 해당 커밋을 되돌리고 모든 작업 공간에서 추적 제외(main에는 들어간 적 없음) |
