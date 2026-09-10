# 운세 분리·마음관리·관계 이해 UX 고도화 스펙

기준일: 2026-09-10
상태: grilling 합의 후 스펙화
관련 문서: [관계 이해 기반 스펙](./RELATIONSHIP_ASSESSMENT_FOUNDATION_SPEC.md), [구현 정리](./RELATIONSHIP_UNDERSTANDING_IMPLEMENTATION.md), [ADR 0009](../adr/0009-fortune-and-mind-care-are-separate-surfaces.md), [ADR 0010](../adr/0010-assessment-change-comparison-contract.md), [ADR 0011](../adr/0011-saju-and-tarot-page-contract.md), [ADR 0012](../adr/0012-ai-mindcare-guided-chat.md), [ADR 0013](../adr/0013-safety-location-and-resource-contract.md)

## Problem Statement

현재 관계 이해 화면의 개인 영역에 운세가 함께 들어 있어 운세, 검사, 궁합 분석의 목적이 섞인다. 검사 카드는 기능을 직접 눌러야 다음 동작을 알 수 있고, 완료 여부·기록·재검사·변화가 한눈에 설명되지 않는다.

또한 사용자가 기분 저하, 짜증, 무기력, 불안, 공황과 같은 상태를 느낄 때 선택할 수 있는 작은 행동과 안전 안내가 없다. 앱이 의료 진단이나 상담을 대신하면 안 되지만, 사용자가 지금 자신의 상태를 확인하고 다음 행동을 고르는 낮은 마찰의 흐름은 필요하다.

## Solution

홈에서 `오늘의 운세`와 `관계 이해`를 독립 카드로 유지한다. 운세는 사주·타로를 사용해 오늘 하루의 흐름을 자세히 읽는 화면으로 발전시키고, 관계 이해 허브는 개인검사와 커플검사에 집중한다.

관계 이해 허브는 개인·커플 상단 탭과 검사별 프로세스 바로 구성한다. 완료된 검사는 `완료 · 며칠 전`과 현재 상태만 카드에 표시하고, 선택하면 과거 이력과 상단의 `새 검사하기`를 보여준다. 재검사 결과는 기존 기록을 수정하지 않으며 최근 2회 결과의 차원별 변화와 중립적 설명을 제공한다.

마음관리는 사람 상담사 marketplace가 아닌 AI 마음관리 가이드 채팅으로 시작한다. 따뜻한 존댓말의 말풍선과 빠른 선택지를 기본으로 하고, 선택적 자유 입력을 섞어 감정·상황·필요·작은 행동·완료 확인을 10~12회 응답으로 진행한다. 위험 가능성이 표시되면 일반 콘텐츠보다 안전 안내를 먼저 보여준다.

## User Stories

1. As a user, I want to enter daily fortune from the Home card, so that fortune does not compete with my relationship assessment flow.
2. As a user, I want separate Saju and Tarot pages, so that I can focus on one reading style at a time.
3. As a user, I want a detailed daily reading covering overall flow, emotional flow, relationship flow, energy/focus, and one small suggestion, so that “today’s fortune” feels useful rather than like a single vague sentence.
4. As a user, I want to see the date, profile inputs used, interpretation basis, and content version, so that I understand what the reading represents.
5. As a user, I want the same date and content version to return the same reading, so that repeated visits do not create unexplained contradictions.
6. As a user, I want fortune language to be framed as self-reflection rather than fact, diagnosis, or treatment, so that I do not mistake it for professional advice.
7. As a user, I want the relationship hub to show separate personal and couple tabs, so that I know which results are private and which are shared.
8. As a user, I want a four-step progress indicator for personal assessments, so that I understand how much of my self-understanding path is complete.
9. As a couple member, I want a three-step progress indicator for couple assessments, so that I understand which shared areas are still pending.
10. As a user, I want a completed assessment card to show its completion state and relative date without ambiguous action labels, so that I do not accidentally start a new assessment.
11. As a user, I want to open a completed assessment and see its past attempts, so that I can understand my history without editing it.
12. As a user, I want `새 검사하기` to be visible at the top of the assessment history, so that starting a retake is an intentional action.
13. As a user, I want a read-only history detail to show the original questions and selected Likert answers, so that I can understand how the result was produced.
14. As a user, I want the latest two completed attempts compared by dimension, so that I can see change over time without being assigned a new personality label.
15. As a user, I want change to be shown with simple horizontal bars, previous/current scores, and neutral wording, so that the comparison is readable on mobile.
16. As a user, I want to start a private emotion check-in from a mind-care surface, so that I can name what is happening without writing a long explanation.
17. As a user, I want to choose the situation and what I need next, so that the app can suggest a small action that matches my current state.
18. As a user, I want the suggested action to be concrete and finishable, so that the app does not give me another vague instruction to “try harder.”
19. As a user, I want to record whether I completed the small action, so that the flow supports follow-through without pretending to replace treatment.
20. As a user, I want optional free text, so that I can add context when choices are not enough without making writing mandatory.
21. As a user selecting a serious safety signal, I want safety guidance to appear before ordinary recommendations, so that the app responds to the situation appropriately.
22. As a user, I want safety guidance to ask whether I am currently safe and offer trusted-person, professional, and local emergency support routes, so that I can choose an appropriate next step.
23. As a user, I want safety guidance not to automatically notify my partner, so that privacy is preserved unless I explicitly choose to share.
24. As a maintainer, I want mind-care content and safety resources versioned, so that updates to wording and local support information are traceable.
25. As a maintainer, I want the fortune, assessment, and mind-care core flows to work with disabled or unavailable LLM providers, so that the product remains usable without token generation.

## Implementation Decisions

- `오늘의 운세` is a Home entry point and a separate navigation surface. It is removed from the relationship hub's personal tab.
- The fortune area has separate Saju and Tarot pages. Each page shows the user's reading first and the active Couple's shared relationship reading second.
- Saju uses the [project reference PDF](./reference/saju/23-saju-120-day-challenge.pdf) for a versioned Four Pillars calculation: Ipchun year boundaries, seasonal-term month boundaries, Korean 135° standard-time and 00:30 child-hour handling, boundary-time and historical daylight-saving corrections. The product exposes a plain-language reading and a technical-term view of the same result. It does not provide a factual-prediction or medical-diagnosis mode.
- Saju requires birth date, calendar type, and timezone. Missing birth time or place prevents a complete chart; the user may explicitly choose a limited reading that marks the missing pillar or location-sensitive interpretation. The app never invents missing values.
- Tarot is one versioned daily card per user and one shared daily card per Couple. The first draw is persisted by date and content version; the same day has no redraw and v1 has no spreads. A birth profile is optional for Tarot.
- Fortune content is dated and versioned for the relevant personal or Couple scope. Personal dates use the stored IANA timezone; responses include the content date, scope, mode, input summary, calculation or interpretation basis, and content version.
- The relationship hub contains no daily fortune section. It retains the personal/couple top tabs and focuses on assessments, compatibility, and their states.
- The personal catalog has four progress steps and the couple catalog has three. A completed card shows completion status/date and opens history; it does not make the whole card an implicit new-attempt button.
- History is append-only and read-only. The history detail shows score, dimensions, original question text, selected five-point response, and the attempt timestamp.
- The change view compares the two newest completed attempts of the same assessment version. An authenticated REST change endpoint selects the pair and returns structured previous/current scores and deltas; Flutter does not recalculate them. Individual comparisons use the user's results, while couple comparisons use the same Couple's immutable shared-result records. Couple `pairScore` is the primary change metric and `alignmentScore` is a separate supporting metric. The mobile card may use a soft bar or line treatment, but always includes text such as `이전 42점 → 현재 58점 · 16점 높아짐`, `변화 없음`, or `16점 낮아짐` without labeling change as improvement or deterioration. If only one same-version result exists, it shows `이 검사를 한 번 더 완료하면 최근 변화를 볼 수 있어요.` and links to `다시 검사하기`; a different-version result cannot substitute for the missing comparison.
- Mind-care v1 is a private, user-scoped AI guide chat. It uses warm honorific Korean, quick choices, optional free text, 10–12 user responses, and resumes one latest incomplete session. It does not become shared counseling or a partner notification.
- The guided chat uses this state progression: `emotion selected → situation selected → need selected → small action selected → completion recorded`. The catalog starts with 8 emotions, 6 situations, 6 needs, and 24 text-and-check actions.
- Mind-care content is curated and versioned. The AI may polish already-selected copy or summarize user-requested free text, but fixed content determines the next step, action, safety state, and privacy scope. No counselor marketplace, booking, or payment is included.
- A server-side Korean phrase dictionary marks possible safety language and asks for explicit current-safety confirmation. It does not infer a clinical risk score.
- Safety guidance follows `current safety → immediate help → trusted person → professional/emergency resources`. Location permission is requested for a one-time country/administrative-region lookup; coordinates and movement history are not stored. Permission denial returns general safety guidance.
- Safety resources are versioned JSON for Korean administrative regions with a general fallback. The product never infers current location from birth place.
- LLM remains optional. It cannot select risk level, determine treatment, change a score, or create an automatic share.
- The primary test seam remains authenticated REST behavior plus Flutter's injected HTTP client and widget behavior. Content rules are observed through API responses and visible UI, not private database inspection.

## Testing Decisions

- Fortune tests verify separate Saju/Tarot page contracts, actual calculation fixture inputs from the reference policy, missing-input limited mode, same-day persisted Tarot draws for personal and Couple scopes, no-redraw behavior, input/basis metadata, and privacy through the REST API.
- Relationship hub widget/API tests verify that fortune is absent from the personal assessment tab, personal/couple progress counts are correct, completed cards show date/state, history opens read-only detail, and the new-attempt action is explicit.
- History tests verify original question/answer visibility and the two-attempt dimension comparison, including the one-attempt empty-comparison state.
- Change API tests verify same-version selection, personal versus Couple scope, duplicate prevention for the same couple-attempt pair, `ready` and `insufficient_history` statuses, and the structured deltas consumed by Flutter.
- Mind-care tests verify the 10–12-response chat progression, choice-specific fixed content, optional free text, session resume, completion recording, and that private entries are not returned to partner/shared endpoints.
- Safety tests verify server phrase-dictionary prompts, explicit safety confirmation, location permission allow/deny fallback, region resource selection, and that no auto-share or private message exposure occurs.
- Tests assert structured statuses, content categories, authorization behavior, and bounded copy presence. They do not assert an LLM's exact prose or query database rows directly.
- Existing authenticated REST integration tests and Flutter injectable-client/widget tests remain the prior art.

## Out of Scope

- Counselor search, appointment booking, payments, human therapist marketplace, or Trost content copying.
- Medical diagnosis, clinical screening claims, treatment plans, medication guidance, or automated crisis intervention.
- Continuous location tracking, automatic partner notification, auto-reporting, or using birth place as current location.
- Unbounded free-form LLM counseling as the primary path, streaming generation, or sending raw assessment answers to an LLM.
- Full clinical validation of the custom assessments.
- Tarot spreads, real-time events, push notifications, and recommendation personalization beyond the versioned deterministic content needed for v1.

## Further Notes

- The attached Trost screenshots are treated as UX references for emotion chips, content sections, cards, and guided selection—not as assets, copy, or requirements to reproduce.
- The implementation should be split into vertical slices: fortune separation and daily detail, assessment history/progress/change UX, mind-care check-in, safety guidance, then optional natural-language assistance.
- Before production release, safety resource copy and locale coverage need explicit human review.

## Implementation tickets

The approved vertical slices are tracked in #129–#137, starting with personal Saju REST and Flutter behavior. Each ticket requires authenticated REST and/or Flutter injected-client tests before implementation and does not authorize deployment.
