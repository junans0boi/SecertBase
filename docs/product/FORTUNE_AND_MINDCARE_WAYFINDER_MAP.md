# Wayfinder Map: 운세 분리·마음관리·검사 UX 고도화

## Destination

운세, 관계 이해 허브, 선택지 기반 마음관리, 상황별 안전 안내가 서로의 목적과
권한을 침범하지 않으면서 실제 사용자 흐름으로 동작하는 구현 스펙과 실행 가능한
vertical-slice 티켓을 확정한다.

## Notes

- 기준 스펙: [운세·마음관리·검사 UX 고도화 Spec #123](https://github.com/junans0boi/SecertBase/issues/123)
- 도메인 용어는 `CONTEXT.md`와 ADR 0009·0010·0011·0012·0013을 따른다.
- 기본 테스트 seam은 인증된 REST API와 Flutter의 주입 가능한 HTTP client/widget 동작이다.
- 첨부 Trost 이미지는 감정 선택, 콘텐츠 카드, 섹션 구조의 UX 참고 자료일 뿐 자산·문구·복제 요구사항이 아니다.
- 지도 단계에서는 결정을 확정하고, 실제 구현은 지도에서 결정이 끝난 뒤 spec/tickets 흐름으로 넘긴다.

## Decisions so far

- 운세는 홈에서 사주 페이지와 타로 페이지로 각각 진입하며 관계 이해 허브의 검사 탭과 분리한다.
- 사주 페이지와 타로 페이지는 각각 `나의 운세`를 먼저, 활성 Couple이 있으면 `우리의 관계 운세`를 이어서 보여준다.
- 사주는 [프로젝트 참조 PDF](./reference/saju/23-saju-120-day-challenge.pdf)의 년주·월주·일주·시주, 입춘·입절, 자시 경계와 한국 표준시 보정 규칙을 기준으로 실제 계산한다. 쉬운 해석과 전문 용어 보기는 같은 계산 결과를 표현하는 두 층이며, 사실 예측·진단 버전은 제공하지 않는다.
- 생년월일·달력 유형·시간대가 없으면 사주를 시작하지 않는다. 출생 시각·출생지가 없으면 누락을 고지하고 `출생정보 수정하기` 또는 `제한된 정보로 보기`를 선택하게 하며, 없는 값을 임의로 채우지 않는다.
- 타로는 개인별 하루 한 장과 Couple별 공유 하루 한 장을 카드 버전·날짜에 고정하고, 같은 날 다시 뽑기와 스프레드는 제공하지 않는다.
- 개인검사 4개와 커플검사 3개는 동일한 진행률·완료일·history·새 검사·최근 2회 변화 비교 UX를 사용한다.
- 검사 변화 비교는 인증된 REST API가 같은 버전의 최근 두 완료 기록만 계산한다. 개인검사는 본인 결과를, 커플검사는 같은 Couple의 공유 결과를 비교한다.
- 개인 차원 점수와 커플 `pairScore`를 주 변화 지표로 사용하고, 커플 `alignmentScore`는 별도 보조 행으로 표시한다. 이전·현재·변화량은 텍스트로도 제공하며 성격 라벨이나 개선·악화 판정은 붙이지 않는다.
- 커플 구성원이 새 같은 버전 시도를 완료하면 시도 ID 조합을 새 공유 기록으로 확정하고, 같은 조합은 중복 생성하지 않는다. 한 건뿐이면 `이 검사를 한 번 더 완료하면 최근 변화를 볼 수 있어요.`와 `다시 검사하기`를 보여준다.
- 변화 카드는 기존 둥근 카드와 부드러운 색상 토큰을 사용하며 막대 또는 꺾은선 같은 귀여운 시각화는 접근성 텍스트를 보조한다.
- 사람 상담사 검색·예약·결제 marketplace는 제외하고, AI 마음관리 가이드가 따뜻한 존댓말의 말풍선과 빠른 선택지를 제공한다.
- 마음관리는 선택지와 선택적 자유 입력을 섞은 10~12회 개인 비공개 채팅으로 진행한다. 감정 8개, 상황 6개, 필요 6개, 텍스트·체크 기반 작은 행동 24개를 버전 관리한다.
- AI는 고정 단계와 콘텐츠가 결정한 내용을 다듬을 뿐 위험도·진단·치료·행동·공유 권한을 결정하지 않는다. 최근 미완료 세션 하나를 재개한다.
- 자해·자살·폭력 위협·심각한 공황 등 위험 가능성은 안전 확인 → 즉시 도움 → 신뢰할 사람 → 전문·응급 리소스 순서로 안내한다. 위치 권한이 허용되면 국가·행정지역만 일시 사용하고, 거부되면 일반 안전 안내만 제공한다.

## Open decision tickets

- 없음. #125·#126·#127·#128 결정 완료.

## Not yet specified

- 실제 구현 티켓별 상세 wire shape와 운영 배포 일정

## Resolved decision tickets

- [검사 기록 변화 비교 모바일 표현 #125](https://github.com/junans0boi/SecertBase/issues/125): 같은 버전의 최근 두 기록을 서버에서 비교하고, 개인·커플 범위와 커플 점수 지표를 분리한다. 비교 불가 상태는 `이 검사를 한 번 더 완료하면 최근 변화를 볼 수 있어요.`로 안내한다.
- [오늘의 운세 시각 구조와 사주·타로 정보 계약 #127](https://github.com/junans0boi/SecertBase/issues/127): 사주와 타로를 독립 페이지로 나누고, 각 페이지에서 개인 결과와 Couple 공유 결과를 구분한다. 실제 사주 계산은 사용자 제공 문서의 계산 기준을 버전화하고, 타로는 개인·Couple 범위별 하루 한 장을 저장하며 재추첨하지 않는다.
- [마음관리 감정·상황·필요·작은 행동 콘텐츠 taxonomy #126](https://github.com/junans0boi/SecertBase/issues/126): AI 가이드 채팅이 감정 8개·상황 6개·필요 6개를 거쳐 텍스트·체크 기반 행동 24개를 제안한다. 개인 비공개 세션은 10~12회 응답과 최근 미완료 1개 재개를 지원한다.
- [위험 신호별 안전 안내와 지역 리소스 정책 #128](https://github.com/junans0boi/SecertBase/issues/128): 위험 가능성은 안전 확인을 먼저 묻고, 위치 권한이 있으면 국가·행정지역만 일시 사용해 한국 버전 JSON 리소스를 고른다. 권한 거부 시 일반 안전 안내만 제공하며 자동 신고·파트너 통보는 하지 않는다.

## Implementation tickets

- [사주 출생 프로필·윤달·지원 범위 #129](https://github.com/junans0boi/SecertBase/issues/129) — 코드·fixture 완료; 인증 통합 fixture는 테스트 환경 제공 시 실행
- [사주 계산 wrapper와 REST #130](https://github.com/junans0boi/SecertBase/issues/130) — 코드·unit/REST fixture 완료; 인증 통합 fixture는 테스트 환경 제공 시 실행
- [개인 사주 Flutter 화면 #131](https://github.com/junans0boi/SecertBase/issues/131) — 코드·API/widget 완료
- [관계 사주 요약 #132](https://github.com/junans0boi/SecertBase/issues/132) — 코드·unit/REST fixture 완료; 인증 통합 fixture는 테스트 환경 제공 시 실행
- [타로 카탈로그·일일 저장 #133](https://github.com/junans0boi/SecertBase/issues/133) — 코드·unit/REST fixture 완료; 인증 통합 fixture는 테스트 환경 제공 시 실행
- [타로 Flutter 화면 #134](https://github.com/junans0boi/SecertBase/issues/134) — 코드·API/widget 완료
- [AI 마음관리 채팅 세션·콘텐츠 #135](https://github.com/junans0boi/SecertBase/issues/135) — 코드·unit/REST fixture·Flutter 말풍선 완료; 인증 통합 fixture는 테스트 환경 제공 시 실행
- [위험 표현·안전 리소스 #136](https://github.com/junans0boi/SecertBase/issues/136) — 서버 고정 표현·한국 행정지역 JSON·권한 거부 fallback·Flutter 위치 권한/지역 카드 완료
- [확장 vertical slice 접근성·통합 검증 #137](https://github.com/junans0boi/SecertBase/issues/137) — 관련 API/widget 테스트·접근성 label·analyze 완료; 인증 REST smoke는 환경 대기

## Out of scope

- 상담사 marketplace, 예약, 결제
- 의료 진단·임상 검사·치료 계획·자동 위기 개입
- 자동 위치 추적, 파트너 자동 통보, 자동 신고
- 자유 대화형 LLM 상담을 기본 흐름으로 삼는 것
- Trost의 이미지·문구·브랜드를 복제하는 것
