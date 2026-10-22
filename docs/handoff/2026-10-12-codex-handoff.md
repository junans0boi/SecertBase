# Codex 인수인계: MomentLoop·비밀지도·런칭 준비 (2026-10-12)

이 문서만 읽어도 이어서 작업할 수 있게 썼다. Codex는 이전 대화를 전혀 모른다고 가정한다.

## 0. Codex에게 전할 말 (이 블록을 첫 프롬프트로 붙여 넣기)

```text
너는 Secret Base 저장소(/Users/junzzang/BACKUP/workspace/SecertBase)에서 이어서 작업한다.
먼저 아래 순서로 읽어라. 다 읽기 전에는 코드를 수정하지 마라.
  1. CLAUDE.md, CONTEXT.md
  2. docs/AI_AGENT_WORKFLOW.md
  3. docs/handoff/2026-10-12-codex-handoff.md (이 문서 전체)
  4. docs/product/RESEARCH_2026-10_*.md 3개 (git에 아직 untracked 상태, 파일은 존재함)
  5. 작업할 이슈 본문: gh issue view <번호> --comments  (부모 스펙과 Wayfinder 맵 #138 포함)
규칙:
  - 이슈 하나당 수직 슬라이스 하나, 실패하는 테스트 먼저(TDD), 최소 수정.
  - 사용자가 명시적으로 승인하기 전에는 git push, 운영 배포, 운영 DB 접근, 이슈 close를 하지 않는다.
    main에 push하면 GitHub Actions가 운영 서버에 자동 배포된다.
  - 비밀번호·키스토어·서비스 계정 JSON은 절대 커밋하지 않는다.
  - 못 해본 검증은 "검증 못 함"이라고 그대로 적는다. 통과했다고 단정하지 않는다.
  - 한 번에 하나만 하고, 끝날 때마다 이 문서 8장의 체크리스트를 갱신한다.
첫 작업: 8장의 "작업 순서" 1번부터. 시작 전에 각 worktree의 git status/log를 직접 확인해라(3장).
```

## 1. 프로젝트 요약

- Secret Base: 커플용 Flutter 앱(웹 + Android)과 15개 미니게임.
- 스택: Flutter(`apps/secret_base_app`), Node.js/Express/Socket.IO(`services/realtime-server`), Redis, MariaDB/MySQL. 예전 로그의 PostgreSQL 언급은 낡은 정보.
- 배포: `main` push → `.github/workflows/deploy-to-server.yml` → 운영 서버(Tailscale)에서 웹 빌드 후 `/var/www/secretbase`로 rsync. 스테이징(`test.…`)은 지금 운영과 같은 백엔드를 가리킴(분리 필요, 아직 안 함).
- 디자인: 따뜻한 로즈 톤. `lib/core/main_design.dart`(토큰), `lib/core/main_hero.dart`(MainHero, MainTabHeader). 새 화면도 이 토큰을 쓴다.
- 이슈 트래커: GitHub Issues(`gh` CLI). 라벨 `ready-for-agent`, `wayfinder:launch` 등. 규칙은 `docs/agents/*.md`.

## 2. 목표와 확정된 결정

목표(Wayfinder 맵 #138): **지인 비공개 테스트에서 모든 기능이 정상 동작**하고, 그다음 Google Play 비공개 테스트 트랙을 열 수 있는 상태. 순서는 지인 테스트 → Play 비공개 테스트 → iOS+Android 출시. 지인 테스트부터 기능이 다 돼야 한다는 것이 사용자의 요구다.

그릴링으로 확정된 것:
- 기록 날짜 = 사진 EXIF 촬영일 자동 설정 (이미 구현·배포됨, 커밋 c312eb2).
- 격자 피드는 서버 썸네일 없이 **업로드 전 클라이언트 압축**(긴 변 1920px, JPEG 85%, `flutter_image_compress`)으로 간다.
- 업로드 큐 1단계는 **앱 안 영구 큐(outbox)** + 실패 시 임시저장 + 로컬 알림. OS 백그라운드 업로드(`background_downloader`)는 다음 단계.
- 서버 변경: `position`, `client_request_id`(멱등성). 웹 푸시 포함 FCM은 Android+웹 먼저, iOS는 나중.
- 비밀지도: 이번엔 비모달 3단 시트 + 필터 1줄화. **리스트/컬렉션은 다음 스프린트**(상태 칩을 대체할지 병행할지 아직 미정, 별도 그릴링 필요). 마커 클러스터링은 flutter_map 업그레이드 후 별도.
- 마케팅 푸시는 만들지 않는다(서비스성 알림 3종만: 상대 기록, 오늘의 루프 공개, 게임 초대).

미결정(사용자 확인 필요): 비밀지도 리스트 도입 방식, 사진 수 상한(현재 10장), 임시저장 보관 정책, 신고·차단 기능 필요 여부, 알림 방해금지 기본 시간.

## 3. 읽을 문서

| 문서 | 내용 |
|---|---|
| `docs/product/RESEARCH_2026-10_MAP_UX.md` | 지도 앱 UX 조사, 비밀지도 격차 |
| `docs/product/RESEARCH_2026-10_MOMENTLOOP_COMPOSER.md` | 순서 변경, 백그라운드 업로드, 수정, 격자. 현재 코드 사실과 줄 번호 포함 |
| `docs/product/RESEARCH_2026-10_LAUNCH_READINESS.md` | 푸시/스토어 요건/규제/경쟁앱 갭 |
| GitHub #138 | Wayfinder 맵(목적지, 결정, 범위 밖) |
| GitHub #139~#144 | 스펙 6개 |
| GitHub #145~#158 | 티켓 14개 |
| 런칭 체크리스트(웹) | https://claude.ai/artifact/2rotLyGcApbtkYdUZgY7iq |
| 진행 현황 페이지 | https://claude.ai/artifact/2eLutDCBg7ugTutLwf8z4y (상태가 낡았음, 아래 표가 더 정확) |

리서치 3개는 `docs/product/` 아래 untracked다. 필요하면 커밋을 사용자에게 제안한다(임의로 커밋하지 말 것).

## 4. 중단 시점 코드 상태 (worktree별 snapshot)

모든 작업은 `/Users/junzzang/BACKUP/workspace/SecertBase/.claude/worktrees/` 아래 격리 worktree의 로컬 브랜치에 있고, **main에는 아무것도 병합되지 않았다.** push도 하지 않았다. 에이전트가 사용자 요청으로 중간에 중단됐으므로, 아래는 중단 시점 관찰값이다. 시작 전에 `git -C <경로> status`와 `git -C <경로> log main..HEAD`로 반드시 다시 확인한다.

| worktree | 브랜치 | 이슈 | 상태 |
|---|---|---|---|
| `agent-afaf5365dc15fbef3` | worktree-agent-afaf5365dc15fbef3 | #149 게임 버그 | **완료**, 커밋 5개, 작업 트리 깨끗 |
| `agent-ae1ab562a897009e6` | worktree-agent-ae1ab562a897009e6 | #148 → #150 → #151 | #148만 커밋됨(dca1068). #150, #151은 시작 전 |
| `agent-a78544b03a2a769ef` | worktree-agent-a78544b03a2a769ef | #146 → #147 → #145 | #146/#147 커밋됨. #145 서명 설정 커밋 `74b0186`, 작업 트리 clean |
| `agent-aaacd793cdc9c212d` | worktree-agent-aaacd793cdc9c212d | #157 → #158 | #157 커밋됨(b6f26fb, flutter_map 6.2.1→8.3.2). #158 완료·커밋(ac04f45), 작업 트리 clean |
| `agent-a25a8616c845f10fc` | worktree-agent-a25a8616c845f10fc | #155 → #156 | #155 서버 커밋 `6b03ac4`, #156 클라이언트 커밋 `2f5931d`, 작업 트리 clean |
| `agent-a3127643304f3a2ae`, `agent-a721eb6b6b282089c` | | | 이번 작업과 무관한 예전 worktree. 건드리지 말 것 |

### 2026-10-12 Codex 재확인

`git status --short --branch`와 `git log --oneline main..HEAD`로 다시 확인했다.
아래는 체크리스트 1을 시작하기 전의 상태 스냅샷이다. 이후 #158 변경은 아래 완료 기록과 체크리스트 상태를 따른다.

- #149 `agent-afaf5365dc15fbef3`: clean, main보다 5개 커밋 앞섬.
- #148 `agent-ae1ab562a897009e6`: `dca1068` 1개 커밋, `services/realtime-server/node_modules`만 untracked.
- #145 묶음 `agent-a78544b03a2a769ef`: #146/#147 커밋 2개, `android/app/build.gradle.kts` 수정 1개.
- #158 `agent-aaacd793cdc9c212d`: #157 커밋 1개, `map_screen.dart`와 `map_screen_test.dart` 수정, `test/tmp_dbg_test.dart` untracked.
- #156 `agent-a25a8616c845f10fc`: #155 커밋 1개, 핸드오프에 적힌 클라이언트 파일 수정·추가 상태.
- 무관한 `agent-a3127643304f3a2ae`, `agent-a721eb6b6b282089c`: clean, main보다 앞선 커밋 없음.
- 저장소 main worktree: main보다 앞선 커밋 없음. 이 핸드오프와 리서치 3개는 untracked.
- 표 밖의 `copilot-worktrees/.../junans0boi-congenial-couscous`: clean, `045dcde` 1개 커밋 앞섬; 이번 작업에서는 건드리지 않는다.
- 등록된 `SecertBase.worktrees/handoff-context-reading`은 git이 prunable로 표시하고 디렉터리도 없어 status/log를 읽을 수 없다. 정리하지 않았다.

### 2026-10-12 체크리스트 4 이후 현재 상태

- #149, #148, #146/#147/#145, #157/#158, #155/#156을 handoff 6장 순서대로 main에 로컬 병합했다. merge commits: `b577af8`, `4893e21`, `953eb8c`, `5da9492`, `bbb5b2f`. 자동 병합되어 충돌은 없었다.
- main은 `origin/main`보다 18개 커밋 앞서 있다. **push하지 않았다.** 기존 untracked handoff와 리서치 문서 3개도 그대로 보존했다.
- 각 작업 브랜치 tip은 main의 조상임을 확인했다. worktree를 삭제하거나 키/데이터를 정리하지 않았다.
- #155의 `0043_push_notifications.sql`이 존재한다. 이어서 #150 마이그레이션을 만들 때 다음 번호 `0044`를 사용한다.
- 병합 후 `flutter analyze` 통과, `flutter test` 206개 통과, 서버 `npm test` 299개(259 통과, 40 skip, 0 실패), `npm run check` 통과. Flutter 테스트 중 off-screen tap 경고 1건이 출력됐지만 전체 테스트는 통과했다.

### 이슈별 세부

- **#149 (완료)**: 마블 winReason(클라가 서버 값 `tourist/double/line_monopoly`에 맞춤), 마블 HUD 자산(서버 `assets` 전송, 클라 자체 계산 삭제), 윷놀이 `caughtOpponentThisTurn` 리셋, 볼링·패널티킥 `grantGameXpAndMissions`, 폭탄 재접속 `currentPlayer`. **텔레파시는 부분 수정**: 이슈는 "만료 시 기존 선택으로 결과 emit"인데 구현은 세션 TTL 60초→3600초로 늘리는 것뿐. 볼링·패널티킥 XP는 Redis/DB 없이 단위 테스트가 불가능해 자동 테스트가 없다. 게임별 수동 확인은 안 했다.
- **#148 (커밋됐지만 원인 미확정)**: 에이전트 결론은 "체크 안 하면 `today_moment`를 보내지 않고, 서버도 명시적 true일 때만 지정한다. 자동 지정 경로는 없다. 켜짐 상태가 연한 색이라 모르고 켰을 가능성뿐"이었다. 그래서 스위치 ON 트랙을 진한 로즈로 바꾸고 클라이언트/서버 테스트를 추가했다. **사용자가 본 증상은 재현하지 못했다.** 사용자에게 "어느 화면(홈 카드, MomentLoop 피드, 상세)에서 보였는지, 과거 날짜로 올렸는지"를 물어보고, 홈의 오늘의 루프 카드와 `today_moments` 조회 경로(`GET` 쪽)도 추가로 확인할 것. 이 이슈는 닫지 않는다.
- **#150**: 시작 전. 마이그레이션 번호 충돌 주의: #155 서버 커밋이 `services/realtime-server/migrations/0043_push_notifications.sql`을 이미 썼다. #150은 병합 시점의 다음 번호를 쓴다.
- **#146/#147**: 정적 페이지 `web/privacy.html`, `web/terms.html`, `web/account-deletion.html`, `lib/core/legal_urls.dart`, 설정 화면 링크, 가입 동의 체크박스까지 커밋됨. 페이지 문구는 법률 검토가 안 된 초안이다(푸터에 명시하도록 지시함, 확인할 것). 실제 운영 URL에서 `.html` 직접 접근이 되는지는 **검증 못 함**(SPA 라우팅과 nginx 설정 확인 필요).
- **#145 (완료, 로컬 커밋 `74b0186`)**: `build.gradle.kts`가 `android/key.properties`, 이슈의 `KEYSTORE_PATH`/`KEYSTORE_PASSWORD`/`KEY_ALIAS`/`KEY_PASSWORD`, 또는 기존 `RELEASE_*` 환경변수에서 서명 값을 읽고, 없으면 debug 서명으로 대체한다. keystore와 `key.properties`는 모두 gitignore 확인됨. `:app:signingReport`가 release keystore/alias `secretbase`를 읽었고 SHA-1은 `F9:A2:6D:4E:43:45:93:0A:CB:F8:AD:31:5E:83:D4:79:B5:83:37:36`. `flutter build apk --release` 성공(100.6 MB), `apksigner verify --verbose --print-certs` 통과 및 동일 SHA-1 확인. **키스토어는 이 worktree 안에만 있다. worktree 삭제 전에 사용자가 안전한 위치에 백업해야 한다.** Google Cloud Console OAuth 클라이언트 등록과 실제 기기 release Google 로그인은 아직 확인하지 않았다.
- **#157**: 커밋됨. 분석은 통과했다고 보고됨. 지도 화면이 실제로 뜨는지는 시각 확인 못 함.
- **#158**: 완료·커밋 `ac04f45`. `DraggableScrollableSheet` 3단 시트, 인라인 장소 상세/추가 폼, 필터 버튼을 마무리했다. 시트 패널을 교체한 직후 같은 이벤트에서 애니메이션하면 스냅이 적용되지 않아 다음 프레임에 스냅하도록 고쳤다. 테스트 Mock 응답은 UTF-8 bytes로 만들고 `test/tmp_dbg_test.dart`는 삭제했다. `flutter analyze` 통과, `flutter test test/map_screen_test.dart` 11개 및 전체 `flutter test` 196개 통과. 에뮬레이터에서 실제 OSM 타일 로딩·시각 동작은 검증하지 않았다.
- **#155 (서버)**: `device_tokens`, `notification_prefs` 마이그레이션, `notifier.js`, `/api/device-token` 라우터, 스케줄러, 테스트 2개 커밋됨. Firebase 자격 증명이 없으면 no-op이 되도록 설계됨. 실제 FCM 발송은 검증 못 함.
- **#156 (클라이언트, 로컬 커밋 `2f5931d`)**: Android 권한/FCM 초기화, 푸시 토큰 등록·폐기, 딥링크, 알림 설정 UI, 웹 서비스 워커를 추가했다. ignored 파일까지 포함해 `google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`가 없는 상태를 확인했다. `flutter analyze` 통과, 전체 `flutter test` 196개 통과(설정 누락 시 PushService 비활성화 테스트 포함), `flutter build web --release` 성공. Web 빌드 중 `socket_io_common`의 Wasm dry-run lint 경고가 있었지만 일반 Web 빌드는 성공했다. Android debug 빌드는 Gradle에서 218초간 진행 출력이 없어 이 실행만 취소했다(검증 못 함). Android 실제 기동, 권한 UI, FCM 발송/탭, 브라우저의 실제 서비스 워커 등록·백그라운드 수신은 확인하지 않았다. #156의 2인 수동 수신, cron, Firebase 실설정 검증도 남아 있다.

## 5. 남은 티켓 (아직 시작 안 함)

의존: #150 → #151, #152, #153, #154.

- **#152 업로드 큐**: 저장 즉시 화면 닫힘, 큐가 백그라운드 업로드, 실패 시 임시저장 + 로컬 알림(탭하면 초안 열기), 파일별 `client_request_id`로 재시도 중복 방지, 오늘의 순간 플래그 규칙(첫 파일만, 과거 날짜 불가) 유지. 파일은 앱 문서 디렉터리로 복사해 둘 것(캐시 파일은 사라질 수 있음).
- **#153 전체 수정**: 사진 추가/삭제/순서, 글, 날짜, 위치를 한 화면에서. 서버에 그룹 단위 수정과 순서 저장 API 필요. `session_id`는 불변(이모지 반응이 `session_id` 기준). 오늘의 순간이 공개된 뒤에는 사진 추가·삭제 불가.
- **#154 격자 피드 + 압축**: 3열 격자와 목록 토글(`SharedPreferences`에 저장), 그룹 대표 사진 + 장수 배지, 업로드 전 압축. 서버 썸네일과 페이지네이션은 범위 밖.

## 6. 병합 계획과 예상 충돌

권장 병합 순서(main 기준, 작은 것부터): #149 → MomentLoop(#148, #150, #151) → 법적(#146, #147, #145) → 지도(#157, #158) → 푸시(#155, #156). 병합은 로컬에서만 하고 push하지 않는다.

예상 충돌 지점:
- `pubspec.yaml`, `pubspec.lock`: 지도(flutter_map), 푸시(firebase 등), 법적(url_launcher 가능성).
- `settings_screen.dart`: 법적 링크와 푸시 알림 설정 진입이 둘 다 수정.
- `moment_loop_screen.dart`: #148과 #151, 이후 #152~#154가 모두 건드림. #152~#154는 병합 후 새 브랜치에서 순서대로 한다.
- `services/realtime-server/migrations/`: 번호 중복(0043). `schema-readiness.js`도 같이 확인.
- `services/realtime-server/package-lock.json`: 푸시 쪽이 1,700줄 변경. 충돌하면 병합 후 `npm install`로 재생성.

병합 후 반드시 실행: `cd apps/secret_base_app && flutter analyze && flutter test`, `cd services/realtime-server && node --test`.

## 7. 사람이 직접 해야 하는 일

| 항목 | 이유 |
|---|---|
| 새 SHA-1을 Google Cloud Console Android OAuth 클라이언트에 등록 | 코드로 할 수 없음. 안 하면 release APK에서 Google 로그인 실패 |
| 키스토어 백업 보관 | 분실 시 업데이트 불가 |
| Firebase 프로젝트 생성, `google-services.json`, 웹 VAPID 키, 서버용 서비스 계정 JSON 제공 | 푸시 실제 동작에 필요 |
| 개인정보 처리방침·이용약관 문구 검토 | 에이전트가 쓴 초안 |
| 운영 배포 승인 (DB 마이그레이션 포함) | 운영 데이터에 영향 |
| 실제 기기 확인: 푸시 수신, release APK 로그인, 비밀지도 시트 조작, 사진 업로드/순서 | 자동 테스트로 못 봄 |
| #148 증상 재현 정보 제공 | 아직 원인 미확정 |
| Play 개발자 계정 유형 결정 | 개인 계정이면 12명 14일 비공개 테스트 필요(리서치 문서 참고) |

## 8. 작업 순서와 체크리스트

Codex가 위에서부터 진행하고 `[x]`로 갱신한다.

- [x] 0. 각 worktree 상태 재확인(`git status`, `git log main..HEAD`), 이 문서와 다르면 문서를 고친다
- [x] 1. #158 이어서 마무리: analyze + 테스트 통과시키고 `tmp_dbg_test.dart` 삭제, 커밋
- [x] 2. #145 서명 설정 커밋, SHA-1 및 release APK 서명 검증
- [x] 3. #156 클라이언트 정리: 설정 파일 없이 analyze/test 통과, Web 빌드, 로컬 커밋
- [x] 4. 완료된 브랜치를 6장 순서로 로컬 병합, Flutter/서버 전체 테스트·검사 통과 (main은 아직 push하지 않음)
- [x] 5. #150 마이그레이션 + 멱등성 + `position` 서버 구현 (0044 migration, 격리 MariaDB 마이그레이션/동시 재시도 테스트 통과)
- [x] 6. #151 순서 변경 UI (드래그 UI + 순서 저장 테스트)
- [x] 7. #153 전체 수정 (세션 범위 수정 API, 날짜/공개 잠금, 권한·검증 테스트)
- [x] 8. #152 업로드 큐 (내구성 outbox, 재시도/체크포인트/완료 파일 정리 테스트)
- [x] 9. #154 격자 + 압축 (3열/목록 전환·설정 저장, 이미지 리사이즈 압축 테스트)
- [ ] 10. #148 증상 재현 정보를 받아 원인 확정
- [ ] 11. 사용자에게 배포 승인 요청(마이그레이션 영향 설명 포함), 승인 후에만 push
- [ ] 12. 이슈 close는 사용자 확인 후, 각 이슈에 검증 결과 코멘트

2026-10-12 Codex 후속 검증: Flutter analyze 통과, Flutter 테스트 243개 통과, 웹 알림 워커 테스트 7개 통과, 웹 릴리스 빌드 성공. 서버 `npm run check` 및 `git diff --check` 통과. 전체 서버 `npm test` 재실행 결과 360개 중 358개 통과·실패 0·알림 전용 환경 미설정으로 2개 제외. 제외된 알림 통합 테스트 2개는 별도 격리 MariaDB/Redis에서 실행해 모두 통과했다. 첫 실행에서 migration CLI fixture에 0043–0045가 빠진 결함을 발견해 수정했고 해당 통합 테스트 3개도 통과했다. #148은 사용자 증상 원인 미확정이며 10번 미완료 유지. Firebase 실제 수신·OAuth 실기기·약관 법률 검토·운영 URL은 확인하지 못했다. push·운영 배포·이슈 close는 수행하지 않았다. 상세 근거와 미확인 항목은 [구현·검증 현황](2026-10-12-implementation-status.md)을 참조한다.

## 9. 테스트·로컬 환경 메모

- Flutter: `cd apps/secret_base_app && flutter analyze && flutter test`
- 서버: `cd services/realtime-server && node --test`. 통합 테스트는 `TEST_DATABASE_ADMIN_URL`, `TEST_REDIS_URL`이 없으면 건너뛴다. 테스트 도우미가 관리자 URL의 로컬 포트 형식을 검사하므로, 로컬 MariaDB/Redis를 직접 띄워야 할 수 있다. 서버 환경변수 `JWT_SECRET`은 32자 이상.
- 이전 세션에서는 임시 MariaDB(포트 3399)와 Redis(포트 6399)를 `/tmp`에 띄워 포트 4200 백엔드로 종단 확인을 했고, 끝난 뒤 모두 정리했다. 필요하면 같은 방식으로 다시 만든다.
- 에뮬레이터: `Medium_Phone_API_37.0`(소프트웨어 렌더링이라 느림). Android Google 로그인 테스트는 사용자 기기에서 하는 편이 낫다.
- 이 세션에서 Claude 에이전트는 격리 worktree 안에서만 작업했다. Codex도 같은 방식(브랜치/worktree)을 쓰면 서로 덮어쓰지 않는다.

## 10. 알려진 위험 한 줄 요약

- #148은 원인 미확정인데 "수정됨"으로 오해하기 쉽다.
- #158은 자동 분석·테스트가 통과했지만, 실제 에뮬레이터에서 OSM 타일이 로딩되는지는 확인하지 않았다.
- 키스토어가 worktree 안에만 있다.
- 텔레파시 수정은 이슈 요구보다 약하다.
- 법적 문서는 초안이다.
- 푸시는 Firebase 설정 전까지 실제 동작을 검증할 수 없다.
- main push = 운영 자동 배포 + DB 마이그레이션.
