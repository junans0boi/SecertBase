# AI 개발 워크플로우 정리

## 개요

AI 개발을 안정적으로 진행하기 위해 참고할 수 있는 자료는 크게 두 가지다.

| 서비스 | 역할 | 설명 |
| --- | --- | --- |
| `mattpocock/skills` | 실행 도구 | AI 에이전트에게 특정 방식으로 일하게 만드는 개별 스킬 모음 |
| `My 7 Phases Of AI Development` | 프로세스 지도 | AI와 개발할 때 어떤 순서로 진행하면 좋은지 설명하는 개발 흐름 |

핵심 차이는 다음과 같다.

```text
AI Hero 7 Phases = AI 개발 전체 운영 흐름
mattpocock/skills = 그 흐름을 실제 작업으로 실행하게 해주는 에이전트 스킬 모음
```

즉:

```text
AI Hero는 지도다.
mattpocock/skills는 그 지도를 따라 움직이게 해주는 도구다.
```

## 1. mattpocock/skills

### 역할

`mattpocock/skills`는 AI 에이전트에게 특정 방식으로 일하게 만드는 개별 스킬 모음이다.

Codex나 Claude 같은 AI 에이전트에게 단순히 "구현해줘"라고 시키는 대신, 더 안전하고 체계적인 방식으로 작업하게 만든다.

- 구현 전에 기획을 검증하게 한다.
- 질문을 통해 요구사항을 명확히 만든다.
- 대화 내용을 PRD 또는 Spec으로 정리한다.
- Spec을 작은 작업 티켓으로 나눈다.
- 티켓 하나 단위로 구현하게 한다.
- 테스트 기반 개발을 유도한다.
- 코드 변경사항을 리뷰하게 한다.
- 세션이 길어졌을 때 다음 세션용 handoff를 만든다.

### 대표 스킬

| Skill | 역할 |
| --- | --- |
| `grill-with-docs` | 기능이나 기획을 구현하기 전에 에이전트가 질문을 던져 요구사항을 날카롭게 만들고, 필요한 용어와 결정을 문서화한다. |
| `grill-me` | 아이디어나 계획을 강하게 검증하고 약한 가정을 찾는다. |
| `research` | 기술, 외부 API, 기존 코드, 문서 등을 조사한다. |
| `prototype` | UI, 상태 모델, 기술 방식 등을 빠르게 실험한다. |
| `to-spec` | 대화 내용을 PRD 또는 Spec으로 정리한다. |
| `to-tickets` | Spec을 GitHub Issue 같은 작은 작업 티켓으로 쪼갠다. |
| `implement` | 티켓 단위로 실제 구현을 진행한다. |
| `tdd` | 테스트를 먼저 만들고 구현하는 개발 루프를 따른다. |
| `diagnosing-bugs` | 버그를 수정하기 전에 재현 가능한 pass/fail 루프를 먼저 만든다. |
| `code-review` | 변경사항에서 버그, 리스크, 회귀 가능성, 누락된 테스트를 찾는다. |
| `triage` | 이슈를 분류하고 다음 액션 상태로 이동시킨다. |
| `handoff` | 다음 세션이나 다른 에이전트가 이어받을 수 있도록 요약 문서를 만든다. |
| `domain-modeling` | 프로젝트의 도메인 용어와 중요한 개념을 정리한다. |
| `codebase-design` | 코드 구조, 모듈 경계, 테스트하기 어려운 구조를 개선할 지점을 찾는다. |

### 정리

`mattpocock/skills`는 Codex나 Claude에서 호출해서 쓰는 명령/워크플로우 부품에 가깝다.

예시:

```text
기획을 검증하고 싶다 -> grill-with-docs
기획을 문서화하고 싶다 -> to-spec
작업을 이슈로 나누고 싶다 -> to-tickets
이슈 하나를 구현하고 싶다 -> implement / tdd
버그를 고치고 싶다 -> diagnosing-bugs
변경사항을 검토하고 싶다 -> code-review
다음 세션으로 넘기고 싶다 -> handoff
```

## 2. My 7 Phases Of AI Development

### 역할

`My 7 Phases Of AI Development`는 AI와 개발할 때 어떤 순서로 진행하면 좋은지 설명하는 개발 프로세스 지도다.

직접 실행되는 스킬 모음이라기보다는, AI 개발을 안정적으로 굴리기 위한 큰 흐름에 가깝다.

핵심 단계는 다음 7가지다.

```text
Idea -> Research -> Prototype -> PRD -> Kanban -> Execution -> QA
```

### 7단계 설명

| 단계 | 역할 |
| --- | --- |
| `Idea` | 뭘 만들지, 어떤 문제를 풀지, 어떤 방향으로 갈지 잡는다. |
| `Research` | 외부 API, 기술 제약, 기존 코드, 경쟁 사례, 구현 가능성을 조사한다. |
| `Prototype` | UI, 상태 모델, 핵심 기술 방식 등을 빠르게 실험한다. |
| `PRD` | 최종적으로 사용자가 보게 될 동작과 요구사항을 문서화한다. |
| `Kanban` | PRD를 작은 작업 티켓으로 쪼개고 작업 순서를 정한다. |
| `Execution` | 티켓 단위로 실제 구현을 진행한다. |
| `QA` | 사람이 검증하고, 버그와 개선점을 다시 티켓화한다. |

### 정리

AI Hero의 7단계는 "AI가 알아서 전부 잘 만들게 하는 방법"이 아니다.

사람이 AI 에이전트를 통제하면서 개발을 진행하기 위한 순서에 가깝다.

좋은 AI 개발 흐름은 다음과 같다.

```text
아이디어를 정리한다.
조사한다.
작게 실험한다.
문서화한다.
작은 이슈로 쪼갠다.
이슈 하나씩 구현한다.
검증하고 다시 개선한다.
```

## 3. 두 자료의 관계

두 자료는 서로 경쟁하는 것이 아니라 함께 쓰는 관계다.

| 구분 | 역할 |
| --- | --- |
| AI Hero 7 Phases | 전체 개발 흐름을 잡아주는 운영 프레임워크 |
| mattpocock/skills | 그 흐름을 실제로 수행하게 해주는 에이전트 실행 도구 |

### 단계별 매칭

| AI Hero 단계 | 사용할 수 있는 skill |
| --- | --- |
| `Idea` | `grill-with-docs`, `grill-me` |
| `Research` | `research` |
| `Prototype` | `prototype` |
| `PRD` | `to-spec` |
| `Kanban` | `to-tickets` |
| `Execution` | `implement`, `tdd`, `diagnosing-bugs` |
| `QA` | `code-review`, `triage` |

### 별도 운영 도구

`handoff`는 AI Hero의 7단계 안에 들어가는 공식 단계라기보다는, 세션을 안전하게 넘기기 위한 운영 보조 도구다.

| 상황 | 사용할 skill |
| --- | --- |
| 세션 이동 / 컨텍스트 정리 | `handoff` |
| 도메인 용어 정리 | `domain-modeling` |
| 코드 구조 개선점 찾기 | `codebase-design`, `improve-codebase-architecture` |

### 한 문장 요약

```text
AI Hero 7 Phases는 AI 개발을 어떤 순서로 진행할지 알려주는 운영 프레임워크이고,
mattpocock/skills는 그 각 단계를 실제 Codex/Claude 에이전트에게 수행시키는 실행 도구 모음이다.
```

## 4. 이미 개발된 프로젝트에 적용하는 방법

이미 기획과 개발이 어느 정도 된 프로젝트라면 `Idea`부터 완전히 다시 시작할 필요는 없다.

대신 현재 상태를 기준으로 부족한 점을 찾고, 기획을 다시 정리한 뒤, 개선 작업을 이슈화하는 방식이 좋다.

추천 흐름:

```text
현재 상태 정리
-> 부족한 점 찾기
-> 핵심 리스크 재기획
-> PRD/Spec 작성
-> GitHub Issue로 vertical slice 분해
-> 티켓 단위 구현
-> QA/리뷰
-> 다음 세션용 handoff
```

### 프로젝트 적용표

| 단계 | 목적 | 사용할 skill |
| --- | --- | --- |
| 현재 상태 정리 | 기존 코드, 문서, 배포 상태 파악 | `research`, `codebase-design` |
| 기획 재검토 | 기능 목적, 사용자 흐름, 빠진 정책 확인 | `grill-with-docs` |
| 도메인 정리 | 용어, 중요한 결정, 모호한 개념 정리 | `domain-modeling` |
| 스펙화 | 논의된 내용을 PRD/Spec으로 정리 | `to-spec` |
| 작업 분해 | 구현 가능한 작은 이슈로 나누기 | `to-tickets` |
| 구현 | 이슈 하나씩 테스트 기반으로 개발 | `implement`, `tdd` |
| 버그 수정 | 먼저 재현 루프 만들고 수정 | `diagnosing-bugs` |
| 리뷰 | 구현 후 위험, 누락, 회귀 가능성 확인 | `code-review` |
| 세션 이동 | 다음 AI나 다른 컴퓨터에서 이어받기 | `handoff` |

## 5. Vertical Slice 원칙

AI 에이전트에게 작업을 줄 때 가장 중요한 원칙은 vertical slice다.

작업을 DB, API, UI처럼 레이어별로 나누면 안 된다.

사용자에게 보이는 작은 기능 단위로 나눠야 한다.

### 나쁜 예시

```text
1. DB 테이블 전부 만들기
2. API 전부 만들기
3. 화면 전부 만들기
```

이 방식은 오랫동안 실제로 동작하는 기능이 없고, 중간 검증도 어렵다.

### 좋은 예시

```text
1. 지도 핀 생성 시 JWT 사용자로 작성자 저장
   -> DB/state
   -> API
   -> Flutter 요청
   -> 테스트/검증
```

좋은 vertical slice는 작지만 끝까지 동작해야 한다.

```text
database/state -> backend contract -> frontend integration -> test/check
```

핵심 원칙:

```text
작업은 작게 쪼갠다.
하지만 쪼갠 작업 하나는 끝까지 동작해야 한다.
```

## 6. Handoff를 어디에 남길 것인가

`handoff`는 모든 대화를 프로젝트 문서에 복사해두는 기능이 아니다.

세션이 길어졌거나, 다른 컴퓨터로 이동하거나, 다른 AI 에이전트가 이어받아야 할 때 현재 상태를 요약하는 용도다.

### 권장 기준

| 위치 | 용도 |
| --- | --- |
| `/tmp` handoff | 다음 세션이나 다른 에이전트가 바로 이어받기 위한 임시 요약 |
| `HANDOFF.md` | 현재 운영 리스크, 배포 상태, 바로 다음 작업처럼 팀 전체가 알아야 하는 내용 |
| `CONTEXT.md` | 도메인 용어와 프로젝트 공통 맥락 |
| `docs/adr/*` | 되돌리기 어렵고 중요한 기술/제품 결정 |
| GitHub Issues | 앞으로 해야 할 작업, acceptance criteria, blocking 관계 |
| `docs/*` | API, Socket, 배포, 제품 계약 같은 장기 유지 문서 |

### 핵심 원칙

```text
임시 대화 내용은 handoff
앞으로 할 일은 Issue
오래 유지될 계약은 docs
도메인 용어는 CONTEXT.md
중요한 결정은 ADR
```

프로젝트 안에 모든 대화 내용을 계속 `.md`로 누적하는 것은 좋지 않다.

이유는 다음과 같다.

- 금방 오래된 정보가 된다.
- 기존 문서와 중복된다.
- AI 에이전트가 과거 내용을 최신 사실로 오해할 수 있다.
- 팀원이 봤을 때 source of truth가 불분명해진다.

프로젝트 안에는 계속 유지해야 하는 정보만 남기고, 임시 세션 요약은 handoff로 분리하는 것이 좋다.

## 7. AI 에이전트를 안전하게 쓰는 방법

AI 에이전트를 효율적으로 쓰려면 한 번에 "프로젝트 전체를 완성해줘"라고 맡기면 안 된다.

AI는 강력하지만, 목표가 넓고 모호하면 잘못된 결정을 자신 있게 실행할 수 있다.

### 기본 원칙

1. 항상 좁은 목표를 준다.
2. 먼저 `CONTEXT.md`와 관련 문서만 읽게 한다.
3. 버그는 수정 전에 재현 루프를 만들게 한다.
4. 기능은 PRD/Issue 없이 바로 구현하지 않는다.
5. 구현은 GitHub Issue 하나 단위로 시킨다.
6. 테스트/체크 명령을 반드시 실행하게 한다.
7. 오래 걸리는 세션은 `handoff`로 요약하고 새 세션에서 이어간다.
8. 오래된 문서보다 현재 source of truth 문서를 우선한다.
9. DB, 인증, 배포, 결제 같은 위험 영역은 반드시 테스트/검증 루프를 요구한다.
10. AI가 바꾼 내용을 사람이 최종 검토한다.

### 좋은 요청 방식

나쁜 요청:

```text
이 프로젝트 전체적으로 부족한 거 찾아서 다 고쳐줘.
```

좋은 요청:

```text
Read CONTEXT.md and HANDOFF.md.
Use codebase-design.
Find the top 5 architecture or product-completeness risks.
Do not edit code yet.
Return findings with recommended next issues.
```

나쁜 요청:

```text
이 버그 고쳐줘.
```

좋은 요청:

```text
Read CONTEXT.md and HANDOFF.md.
Use diagnosing-bugs.
First create or identify a tight pass/fail loop.
Do not edit code until the loop exists.

Bug: <버그 설명>
```

나쁜 요청:

```text
이 기능 만들어줘.
```

좋은 요청:

```text
Read CONTEXT.md and docs/PROJECT_OVERVIEW.md.
Use grill-with-docs style.
Feature: <기능명>

Ask one question at a time.
Recommend an answer for each question.
Inspect code before asking if the code can answer it.
```

구현 요청 예시:

```text
Read CONTEXT.md and this GitHub issue.
Use TDD.
Work on this one vertical slice only.
Run the relevant checks before summarizing.
```

## 8. 이 프로젝트에서의 추천 시작점

이미 프로젝트가 어느 정도 구현되어 있으므로, 첫 목표는 새 기능 추가가 아니라 현재 완성도와 리스크를 재정렬하는 것이 좋다.

첫 목표:

```text
현재 제품 상태, 구현 상태, 남은 리스크를 다시 정렬한다.
```

### 1단계: 스킬 환경 설정

먼저 프로젝트가 어떤 이슈 트래커와 문서 구조를 사용할지 정한다.

추천:

```text
Issue tracker: GitHub Issues
Triage labels: 기본 labels
Domain docs: single-context
```

사용할 skill:

```text
setup-matt-pocock-skills
```

### 2단계: 현재 상태 리뷰

목적:

```text
현재 구현된 기능, 운영 리스크, 문서와 코드의 불일치, 출시 전 부족한 부분 찾기
```

사용할 skill:

```text
research
codebase-design
improve-codebase-architecture
```

### 3단계: 기획 재검토

목적:

```text
현재 기능들이 실제 사용자 흐름에서 충분한지 검증
빠진 정책이나 예외 케이스 찾기
```

사용할 skill:

```text
grill-with-docs
domain-modeling
```

### 4단계: Spec과 Issue 생성

목적:

```text
정리된 개선 방향을 PRD/Spec으로 만들고,
구현 가능한 vertical slice 이슈로 쪼개기
```

사용할 skill:

```text
to-spec
to-tickets
```

### 5단계: 구현과 QA

목적:

```text
이슈 하나씩 구현하고 테스트/리뷰를 반복
```

사용할 skill:

```text
implement
tdd
diagnosing-bugs
code-review
triage
```

## 9. 결론

두 자료는 다음처럼 이해하면 된다.

```text
AI Hero 7 Phases = AI 개발을 안정적으로 굴리기 위한 전체 순서
mattpocock/skills = 그 순서를 실제 에이전트 작업으로 바꾸는 실행 도구
```

이미 만들어진 프로젝트에서는 이 흐름을 처음부터 새로 시작하는 용도로 쓰기보다, 현재 상태를 재검토하고 부족한 부분을 찾아 완성도를 높이는 데 사용하는 것이 좋다.

최종 목표:

```text
기획을 명확히 한다.
문서와 코드의 불일치를 줄인다.
작업을 작은 이슈로 나눈다.
이슈 하나씩 테스트 기반으로 구현한다.
리뷰와 QA를 통해 다시 개선한다.
세션 이동은 handoff로 안전하게 처리한다.
```
