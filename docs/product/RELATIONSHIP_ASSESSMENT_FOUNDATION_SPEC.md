# Secret Base 관계 이해 기반 스펙

## 문서 상태

이 문서는 관계 이해 기능의 제품 스펙과 결정 사항을 보존한다. 현재 구현 현황, 파일 위치, 엔드포인트, 배포 주의사항은 [관계 이해 기능 구현 정리](./RELATIONSHIP_UNDERSTANDING_IMPLEMENTATION.md)를 기준으로 확인한다.
운세 분리·마음관리·검사 UX 확장 요구사항은 [운세·마음관리 확장 스펙](./FORTUNE_AND_MINDCARE_EXPANSION_SPEC.md)에서 별도로 관리한다.

## 초기 설계 브리프

이 기능은 아래의 초기 협업 기준에서 출발했다. 이후 세부 결정이 바뀌더라도
현재 적용된 결정은 이 문서의 `Implementation Decisions`와 ADR을 우선한다.

### 기술 기준

- 앱: Flutter
- 백엔드: Node.js, Socket.IO, REST API
- 데이터베이스: MariaDB
- LLM: 무료 API를 검토하되, 핵심 기능은 LLM 없이 동작하고 provider는 고정하지 않음

### 설계·구현 순서

1. 기존 `routes.js`와 `schema.sql` 및 현재 운영 구조를 먼저 파악한다.
2. 데이터 모델을 정한다.
3. REST API 엔드포인트를 정한다.
4. Flutter 연동을 구현한다.
5. grilling으로 요구사항을 압박 검토하고 `CONTEXT.md`와 필요한 ADR을 갱신한다.
6. 큰 작업은 스펙과 작은 티켓으로 분해한 뒤, 티켓 단위로 TDD·코드 리뷰·API 테스트·Playwright 검증을 반복한다.
7. 구현 완료 후 전체 검증을 하고, 마지막으로 사용자가 실제 환경에서 직접 테스트한다.

이 브리프의 `PostgreSQL`, 특정 Anthropic 모델, LLM 필수 처리 같은 초기 가정은
현재 운영 구조와 합의된 결정에 따라 MariaDB, 선택적 무료 provider, 결정론적
핵심 로직으로 정정되었다.

## Problem Statement

Secret Base는 커플이 함께 사용하는 앱이지만, 두 사람이 자신의 감정·유대·의존·갈등 패턴을 안전하게 이해할 수 있는 공통 언어가 없다. 한 사용자의 개인적 경향과 두 사람의 관계 역학을 구분하지 않으면 개인 결과가 파트너에게 과도하게 노출되거나, 관계 문제를 누가 옳고 그른지의 판정으로 바꾸기 쉽다.

초기 설계 시 앱에는 관계 이해를 위한 버전 있는 심리검사·결과·궁합 분석 흐름이 없었다. 이 기능은 LLM이 해석을 도울 수 있더라도 점수와 권한이 모델 출력에 종속되지 않아야 한다는 원칙에서 출발했다.

## Solution

사용자의 출생 정보를 확장하고, 개인 심리검사 4종과 커플 심리검사 3종을 버전 관리한다. 모든 검사는 5점 리커트 응답을 사용하며, 서버가 고정된 점수 규칙으로 차원별 점수와 전체 경향을 계산한다.

개인 심리검사의 원문 응답과 개인 결과는 본인만 볼 수 있다. 커플 분석에는 개인 결과의 허용된 차원별 요약만 사용한다. 커플 심리검사는 두 사람이 각각 응답하지만 개별 응답은 공개하지 않고, 두 사람의 응답 조합으로 계산한 관계 결과만 공유한다.

LLM은 검사 결과와 궁합 분석의 자연어 설명을 보조하는 선택적 계층으로만 사용한다. 점수·판정·권한은 결정론적 로직이 소유하며, 무료 API의 장애나 한도 초과 시 고정 템플릿 설명으로 완전한 결과를 제공한다. 특정 무료 공급자는 제품 계약에 고정하지 않고 서버 provider adapter 설정으로 선택한다.

## User Stories

1. As a user, I want to save my solar or lunar birth calendar choice, so that future fortune features can interpret my birth information correctly.
2. As a user, I want to save my birth date, so that my relationship profile is complete.
3. As a user, I want to leave birth time empty when I do not know it, so that missing birth information does not block the feature.
4. As a user, I want to save an optional birth place and timezone, so that future date-based interpretations have enough context without requiring information I may not know.
5. As a user, I want to edit my birth information later, so that the profile can be corrected without deleting my psychological assessment history.
6. As a user, I want to see which individual assessments I have not started, so that I know what remains to complete.
7. As a user, I want to see which individual assessments are in progress, so that I can resume without losing answers.
8. As a user, I want to answer individual assessment questions using the same five-point scale, so that the response experience is consistent.
9. As a user, I want my individual assessment answers to be saved while I progress, so that a temporary app close does not erase my work.
10. As a user, I want to submit an individual assessment only after all active questions are answered, so that the score is not calculated from incomplete data.
11. As a user, I want to see dimension scores and an overall tendency for each individual assessment, so that I can understand patterns rather than receive a single fixed label.
12. As a user, I want to see a non-clinical explanation of my individual result, so that I can use it for self-reflection without mistaking it for a medical diagnosis.
13. As a user, I want my individual answers and result to remain visible only to me, so that personal self-reflection does not become an unintended partner disclosure.
14. As a user, I want to retake an individual assessment, so that I can compare my current pattern with a later attempt.
15. As a user, I want previous individual attempts to remain available to me, so that changes over time are not erased.
16. As a user, I want the newest completed assessment result to be clearly identified as current, so that I know which result is used for relationship analysis.
17. As a user, I want to open a previous result and see the questions and answers I selected at that time, so that a score can be understood from the original responses.
18. As a couple member, I want to see which couple assessments require my partner's completion, so that I understand why a shared result is not ready yet.
19. As a user, I want to answer couple assessment questions privately, so that my raw answers are not exposed to my partner.
20. As a couple member, I want a couple assessment result to appear only after both people complete the same version, so that the result represents both sides of the relationship.
21. As a couple member, I want the shared couple result to describe relationship patterns rather than blame either person, so that we can use it as a conversation aid.
22. As a couple member, I want the shared result to avoid showing my partner's raw answers or private individual result, so that the couple space does not bypass personal privacy.
23. As a couple member, I want the shared compatibility screen to show which assessment-level analyses are ready, so that one unfinished assessment does not hide every completed result.
24. As a couple member, I want a compatibility analysis to update when either person's current result changes, so that the shared result reflects the latest same-version inputs.
25. As a couple member, I want the deterministic score and relationship interpretation to be reproducible, so that the same inputs produce the same core result.
26. As a user, I want a natural-language explanation when the configured free LLM provider is available, so that the structured result is easier to understand.
27. As a user, I want to receive a valid fixed-template explanation when the LLM provider is unavailable, so that a provider outage does not make my result unusable.
28. As a user, I want the LLM to receive only dimension summaries and limited metadata, so that individual question wording and raw answers are not sent for optional explanation.
29. As a user, I want an LLM explanation to be regenerated only when I explicitly request it, so that generation is predictable and does not silently change my result.
30. As a user, I want the app to label results as non-clinical self-understanding content, so that I do not mistake them for hospital diagnosis or treatment.
31. As a user, I want to enter the feature from a home card, so that I can find relationship understanding without changing the existing bottom navigation.
32. As a user, I want one dedicated relationship understanding screen for profile, individual assessments, couple assessments, and compatibility, so that the feature has a coherent home.
33. As a user, I want to resume an unfinished assessment from the dedicated screen, so that I do not have to search for it again.
34. As a user, I want the app to explain why a shared result is pending, so that incomplete partner participation is not presented as an error.
35. As an active couple member, I want shared results to be unavailable after separation, so that inactive couples cannot continue accessing the shared space.
36. As a reunited couple member, I want the existing Couple identity and its data lifecycle to be respected, so that reunion does not accidentally create a second relationship record.
37. As a user, I want account deletion and couple separation to preserve the distinction between my personal history and shared couple data, so that privacy behavior is understandable.
38. As a maintainer, I want each assessment definition and question set to have an immutable version, so that old results remain interpretable after future question changes.
39. As a maintainer, I want reverse-scored questions to be declared in the question definition, so that scoring rules are explicit and testable.
40. As a maintainer, I want the LLM provider to be replaceable through a server adapter, so that a free provider's quota or availability does not force a product rewrite.
41. As a maintainer, I want API and Flutter tests to exercise public behavior, so that refactoring internal scoring or storage does not invalidate tests unnecessarily.

## Implementation Decisions

- The current runtime database is MariaDB/MySQL. The feature follows the existing ordered migration system; it does not migrate the project to PostgreSQL.
- Existing user birth date data remains usable. Additional birth profile data adds calendar type (`solar` or `lunar`), nullable local birth time, IANA timezone, and nullable birth place. Birth profile edits do not reset psychological assessments or compatibility analyses.
- The feature distinguishes `Individual Assessment` from `Couple Assessment`.
- The four initial individual assessments are attachment pattern, social bonding pattern, emotional regulation pattern, and relationship deficiency awareness.
- The three initial couple assessments are conflict and repair pattern, togetherness versus personal-time balance, and affection-expression versus expectation alignment.
- Every assessment uses a five-point Likert response. A question may declare `reverse_scored`.
- Each assessment version contains a candidate question pool of 24 questions. The active release displays 12–16 questions, with three dimensions and at least four active questions per dimension. Candidate and active status are versioned so later calibration can change the active set without rewriting prior results.
- Question order is fixed for a version. The client may save progress and resume an attempt.
- Each attempt stores its assessment version, user, optional Couple scope, status, answers, deterministic dimension scores, overall tendency, and timestamps. Attempts are append-only from the user's perspective; retakes create new attempts.
- The newest completed attempt for a user and assessment version is the current personal result. Older completed attempts remain accessible only to that user.
- Each completed personal result keeps the link to its source attempt and question answers. The history list opens a read-only detail view so users can inspect the questions, dimensions, and Likert choices that produced that result.
- Individual attempt answers and personal results are user-scoped. They are never returned through a partner-facing or shared compatibility response.
- Couple attempts are authored separately by each user. A shared couple result becomes ready only when both active Couple members have completed the same couple-assessment version. Each member's raw responses remain private.
- Compatibility analysis is produced per assessment code/version as its source pair becomes complete, rather than blocking the entire compatibility area until all seven assessments are done. The screen aggregates ready and pending analysis cards.
- A compatibility analysis may consume only the allowed dimension summaries from individual results and the pairwise scores from the couple assessment. It does not consume raw answers.
- Core scoring and compatibility rules are deterministic and return structured dimension scores, score differences, labels, and fixed conversation prompts. These values are the source of truth.
- Optional natural-language explanations are generated after the deterministic result. The LLM receives only the assessment version, structured scores, limited metadata, and (for compatibility) pairwise differences and relationship patterns.
- The LLM integration is behind a server-side provider adapter. The provider, base URL, model, and credentials are deployment configuration rather than Flutter configuration. No provider-specific choice is required for the deterministic core.
- LLM explanation status is separate from the core result. The states are equivalent to pending, available, fallback, and failed; a failed or disabled provider returns the fixed-template explanation.
- The LLM cannot modify scores, labels, access scope, completion status, or Couple membership.
- Daily fortune, emotional-flow, and relationship-fortune content is persisted by date and content version. A couple fortune is generated once for the active Couple scope and is identical for both members; regeneration requires an explicit user action.
- Counseling is split into private and shared sessions. Private raw messages are owner-only through the user API. Shared counseling uses only shared messages, structured relationship summaries, and explicitly approved shareable insights; private raw messages never move automatically.
- The current provider configuration is opt-in. A disabled or failed free provider produces deterministic fortune content or a fixed counseling fallback, and records provider/model/prompt/context metadata when generated.
- The REST API follows the existing `{ ok: true, ... }` and `{ ok: false, reason: ... }` response convention and authenticates every feature request with the existing JWT middleware.
- The REST surface provides: birth profile read/update; dated fortune read and explicit regeneration; private/shared counseling session creation, message exchange, archive, and read; explicit shareable-insight approval/revocation; assessment catalog and progress; assessment detail with active questions; attempt start/resume; answer save; attempt submit; personal result read; compatibility status and result read; and explicit explanation regeneration.
- Shared compatibility endpoints resolve the active Couple from the authenticated user. Client-supplied user IDs and Couple IDs are not trusted for authorization.
- A user without an active Couple may manage individual assessments and birth profile, but cannot start couple assessments or read shared compatibility results.
- Separation immediately removes access to shared compatibility and couple-assessment results through active-Couple authorization. Personal assessment history remains user-scoped according to existing account lifecycle policy.
- Flutter adds a dedicated relationship-understanding flow reachable from a Home card. It does not add a bottom-navigation destination in this scope.
- Flutter uses a dedicated API client with injectable `http.Client`, typed response models, progress/resume state, explicit privacy labels, and fallback rendering for unavailable explanations.
- The personal assessment catalog uses explicit actions (`start`, `resume`, `retake`, and `view history`) instead of making the entire card an ambiguous new-assessment trigger. The relationship hub separates personal and couple areas with top tabs.
- Private-counseling at-rest encryption and operator access audit logs are not in this release. The current operational policy allows DB operators to inspect raw private rows, while partner and general authenticated API paths remain blocked.
- Streaming responses, background generation, push notification, premium gate, and clinical diagnosis are out of scope.

## Testing Decisions

- Tests verify externally observable behavior through the highest agreed seams. They do not inspect private functions, database rows directly, or reimplement the scoring algorithm inside assertions.
- The primary server seam is the authenticated REST API through the existing integration test server. Tests create isolated users and couples rather than depending on shared manual test accounts.
- Server integration tests cover birth profile persistence and validation, individual privacy, couple scope, versioned attempts, resume/save behavior, deterministic submit results, retakes, same-version completion gating, separation access revocation, and LLM fallback behavior.
- Server tests use a deterministic fake LLM provider at the provider boundary so explanation success, disabled, timeout, and failure behavior can be tested without a real external API.
- Flutter API tests use an injected `http.Client` to assert request method, URL, authorization header, JSON payload, response parsing, and error reasons.
- Flutter widget tests cover the relationship-understanding entry card, assessment progress/resume, personal result privacy labels, pending couple result state, ready couple result state, and fallback explanation state.
- Flutter widget tests also cover read-only assessment history, opening a result row, and rendering the stored question-level answers.
- Existing Node integration tests using `createApiTestServer` and existing Flutter API tests using mock HTTP clients are the prior art for these seams.
- LLM output wording is not asserted as an exact string. Tests assert status, presence of a bounded explanation, deterministic fallback behavior, and that structured scores remain unchanged.

## Out of Scope

- Medical diagnosis, clinical treatment, crisis assessment, or claims that the custom tests are equivalent to hospital counseling.
- Adoption, licensing, or validation of an external clinical instrument.
- Factual prediction, clinical diagnosis, or claims that the policy-versioned Four Pillars calculation is scientifically verified. The #127 Saju decision and its calculation boundary are recorded in [ADR 0011](../adr/0011-saju-and-tarot-page-contract.md); implementation remains a separate vertical slice.
- Private-counseling at-rest encryption and operator audit logs.
- Automatic use of MomentLoop, Today Loop, Secret Map, game, or other app history as LLM context.
- Streaming LLM responses, autonomous app actions, notifications, and background generation.
- Premium billing, quota monetization, provider marketplace, or a guaranteed free-provider SLA.
- Randomized question order, adaptive testing, or analytics-based psychometric calibration beyond versioned question-pool support.

## Further Notes

- The current implementation has both legacy bootstrap schema and runtime schema repair. New feature tables and columns should use ordered migrations and avoid adding new request-time schema creation.
- The manual test accounts supplied during design are for human smoke testing only. Automated tests must use isolated test data.
- The feature should visibly state that results are for non-clinical self-understanding and relationship conversation.
- The vertical slices are now present in the repository: birth profile, four individual assessments, three couple assessments, compatibility gating, fortune, counseling, history detail, and optional explanation generation. Use the implementation document for the current release boundary instead of treating this spec as a deployment checklist.
