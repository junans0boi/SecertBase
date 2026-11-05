# 03. Wayfinder Map — 놀이 게임 전면 정비 + 탱크 대작전 2.0

> 라벨: `wayfinder:map` · GitHub 이슈: Map #179 · Spec #177 · Grilling #178 · 티켓 #180–#200 (네이티브 하위 이슈와 blocked-by 관계로 연결).
> 로컬 사본: `issues/NN-*.md`.

## Destination

`main`에서 갈라진 `feat/game-overhaul` 브랜치에 다음 두 가지가 반영되어 푸시된 상태입니다.

- 감사(`docs/GAME_AUDIT_2026-11-04.md`)의 Phase 0–1 결함과 게임별 높음·보통 결함 수정
- 탱크 대작전 2.0

이때 서버 테스트가 모두 통과해야 합니다.

## Notes

- **도메인**: 놀이(Play) 공간. 용어는 `CONTEXT.md`를 따르고, ADR-0001에 따라 원카드 내부 식별자 `uno`는 유지합니다.
- **실행 모드**: 사용자가 이 맵 안에서 실행까지 하라고 요청했습니다. 그래서 일반적인 "Plan, don't do"를 덮어쓰고, 결정 티켓 대신 구현 티켓을 차례로 처리합니다.
- **그릴링 방식**: 사용자 요청에 따라 HITL 그릴링을 셀프 그릴링으로 대체했습니다(`01-grilling.md`).
- **세션마다 참고할 스킬**: `tdd`(엔진 시험 지점), `code-review`.
- **검증 제약**: Node는 ChatGPT 앱에 번들된 node v24를 쓰고, Flutter와 gh는 없습니다. Dart 변경은 정적 리뷰로만 검증합니다.

## Decisions so far

모든 결정은 그릴링에서 확정했고, 상세 내용은 각 Q 항목에 있습니다.

- [판돈 권위 (Q5–Q7)](01-grilling.md#round-2--공통-인프라-q1에-의존): 서버 pending game + 비방장 준비 완료. 판돈 대상은 yut·uno·tank·gostop만.
- [정산 (Q8)](01-grilling.md#round-2--공통-인프라-q1에-의존): gameId 기반 ref로 멱등 처리. 정산 후에 상태를 삭제.
- [재시작 (Q9)](01-grilling.md#round-2--공통-인프라-q1에-의존): Redis 요청 레코드를 검증하고 lock 안에서 처리. 마블·탱크 지원 추가.
- [방장 (Q10)](01-grilling.md#round-2--공통-인프라-q1에-의존): 방장 전용 권한을 없애고, 서버가 단계·시간 조건을 검증.
- [복원·막힘 (Q11)](01-grilling.md#round-2--공통-인프라-q1에-의존): 기존 이벤트를 재전송해 복원. 진행 중에 시작 요청이 오면 이어하기.
- [이탈 (Q12)](01-grilling.md#round-2--공통-인프라-q1에-의존): 턴 타이머는 탱크만. 이어하기 정리에는 90초 유예.
- [에러 표면화 (Q13)](01-grilling.md#round-2--공통-인프라-q1에-의존): ack 거부 사유를 SnackBar로 표시.
- [무승부 (Q14)](01-grilling.md#round-2--공통-인프라-q1에-의존): `is_draw` 추가, 참여 XP 30.
- [안정성 (Q15)](01-grilling.md#round-2--공통-인프라-q1에-의존): socket.on 래핑 + 프로세스 핸들러.
- [탱크 2.0 (Q16–Q26)](01-grilling.md#round-3--탱크-대작전-20-q2에-의존): 전차 4종, 무기 9종, 보급, 낙하, 테마 4종, 30초 타이머, 서든데스, 통계, 재대결, events 기반 연출.
- [게임별 정책 (Q27–Q33)](01-grilling.md#round-4--게임별-결함-정책-q1-q10에-의존): 고스톱 규칙, 마블 1-based 레벨, 볼링은 서버 결과 후 연출, 패널티 서든데스, 도둑잡기 별칭, 윷 빽도·잡기, 원카드 스택.

## Tickets

| # | 제목 | Blocked by |
|---|---|---|
| 01 | [서버 핸들러 예외 안전망](issues/01-handler-safety-net.md) | – |
| 02 | [무승부 결과 기록과 참여 보상](issues/02-draw-results.md) | 01 |
| 03 | [재시작 프로토콜 검증](issues/03-restart-protocol.md) | 01 |
| 04 | [서버 권위 판돈과 로비 준비 완료](issues/04-server-stake-and-ready.md) | 01 |
| 05 | [gameId 기반 멱등 정산](issues/05-idempotent-settlement.md) | 04 |
| 06 | [복원·이어하기·정리 유예](issues/06-restore-and-resume.md) | 01 |
| 07 | [클라이언트 거부 사유 안내](issues/07-client-game-notice.md) | – |
| 08 | [고스톱 진행 정지·규칙 수정](issues/08-gostop-rules.md) | – |
| 09 | [원카드 벌칙 스택·정보 노출 수정](issues/09-onecard-stack.md) | – |
| 10 | [도둑잡기 손패 별칭](issues/10-oldmaid-alias.md) | – |
| 11 | [윷 빽도·잡기 보너스 수정](issues/11-yut-backdo.md) | – |
| 12 | [마블 레벨·특수칸·재시작](issues/12-marble.md) | 03 |
| 13 | [볼링 결과·연출 일치](issues/13-bowling.md) | 07 |
| 14 | [패널티킥 서든데스](issues/14-penalty-sudden-death.md) | 02 |
| 15 | [그림 맞히기 권한·타이머·검증](issues/15-catch.md) | 02, 06 |
| 16 | [가위바위보 끊김·리셋·기록](issues/16-rps.md) | 02 |
| 17 | [해적·텔레파시·폭탄·블랙잭 정리](issues/17-small-games.md) | 02 |
| 18 | [탱크 2.0 엔진](issues/18-tank-engine.md) | – |
| 19 | [탱크 2.0 소켓 계층](issues/19-tank-socket.md) | 02, 03, 04, 05, 18 |
| 20 | [탱크 2.0 Flutter 화면](issues/20-tank-flutter.md) | 07, 19 |
| 21 | [문서 갱신과 최종 검증](issues/21-final-verification.md) | 01–20 |

## Not yet specified

- 탱크 외 게임의 서버 턴 타이머. 탱크에서 UX를 검증한 뒤 게임별로 정합니다.
- 폭탄·룰렛을 다시 노출할지 여부. 콘텐츠 기획이 필요합니다.

## Out of scope

- 감사 Phase 4(파일·모듈 분리): 회귀 위험이 크고 Flutter 검증 수단이 없습니다.
- 마블 판돈, 고스톱 2장 매칭 선택 UI, 모바일 오디오, Redis 어댑터: `02-spec.md`의 Out of Scope를 참고하세요.
