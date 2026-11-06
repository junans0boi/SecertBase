# 비밀기지 2.0 디자인 시스템 (`lib/v2`)

Every 2.0 screen is built only from this library. One import:

```dart
import 'package:secret_base_app/v2/v2.dart';
```

Mockup source of truth: `docs/design/v2/mockup/` (`ds.css`, `PLAN.md`, `system.html`).
Live gallery (debug builds only): run the web app and open `/#/v2-gallery`
(`lib/v2/gallery/v2_gallery_screen.dart`).

## 0. Theme: opt in per screen

The global `MaterialApp.theme` is still the legacy `buildAppTheme()`, because
game screens (arcade, play kit, hwatu) rely on it for their dialogs, snackbars
and buttons. **Wrap every 2.0 screen root in `V2Theme`** so plain Material
widgets (TextField, FilledButton, Switch, ListTile...) also look 2.0:

```dart
@override
Widget build(BuildContext context) => V2Theme(
  child: Scaffold(appBar: const V2Header(title: '더보기'), body: ...),
);
// 마음관리 / photo viewer:
V2Theme(dark: true, child: ...)
```

Pages you push are new routes: wrap their root in `V2Theme` too.
`showV2Sheet`, `showV2Dialog`, `showV2Confirm`, `showV2PermissionSheet`,
`showV2ConfirmDestructiveSheet` and `showV2Snack` apply the 2.0 look
themselves and work from anywhere.

## 1. Tokens (`tokens.dart`)

Never write `Color(0x...)` in a 2.0 screen. Use tokens.

| Group | Names |
|---|---|
| Neutral | `V2Colors.bg` `#FFFAFA`, `surface` `#FFFFFF`, `soft` `#FFF2F5`, `soft2` `#FAEAEF`, `line` `#F0DCE3`, `line2` `#E4CBD4`, `fieldBorder`, `control` `#978A9C` (toggle/check borders), `ink` `#211A26`, `sub` `#564B5E`, `muted` `#73687C`, `disabled`, `scrim`, `snack` |
| Rose | `rose` `#FF7FA3` (decor only, never text), `rose600` `#C93468` (buttons, rose text; white 5.03:1), `rose700` `#A3285A` (text on `roseSoft` `#FFE3EB`) |
| Accents | `sage/sky/honey/lilac/peach` + `…Soft` + `…Text` (text is AA on soft) |
| Status | `ok/warn/err` + `…Soft` + `…Text` |
| Dark | `V2DarkColors.*` (same names), or read `V2Palette.of(context)` |
| Shape | `V2Radius.ctl 12 / button 14 / card 20 / sheet 28 / pill`, `V2Radius.cardAll` etc. |
| Space | `V2Space.x1..x12` (4pt grid), `V2Space.page` 20, `V2Space.tap` 44 |
| Shadow | `V2Shadow.level1` (cards), `level2` (sheets, floating) |
| Gradients | `V2Gradients.hero` / `berry` (white text OK, ≥4.5:1), `heroSoft` (ink text), `blossom` (decor only), `dusk` (dark), `placeholder(seed)` |
| Motion | `V2Motion.fast/base/slow`, `V2Motion.of(context, d)` → zero when reduced motion, `V2Motion.reduced(context)` |
| Tones | `V2Tone.{neutral, rose, ok, warn, err, sky, lilac, sage, peach, honey}`, `V2ToneColors.of(tone)` → `base/soft/text` |
| Contrast | `V2Contrast.ratio(a, b)`; `V2Contrast.pairs` is the AA registry tested in `test/v2/v2_contrast_test.dart`. Add any new text/bg pair there. |

Rules: grey text only `sub`/`muted` (`muted` never on `soft2` or darker).
`rose`, `sage`, `sky`, `honey`, `lilac`, `peach` base colors are for icons and
illustrations; for text use the `…Text`/`rose600`/`rose700` variants.

Light/dark aware colors in widgets: `final p = V2Palette.of(context);` then
`p.ink`, `p.sub`, `p.primary`, `p.soft`, …

## 2. Type (`typography.dart`)

Noto Sans KR, six steps. Styles have no color (inherit ink from the theme)
except `cap`, which is `sub`.

| Style | Size | Use |
|---|---|---|
| `V2Text.display` | 28/34 w800 | big page moments |
| `V2Text.title` | 22/28 w800 | tab titles, sheet titles |
| `V2Text.head` | 18/24 w700 | card / dialog titles |
| `V2Text.body` | 15/22 w500 | body |
| `V2Text.bodyStrong` | 15/20 w600 | list-row titles |
| `V2Text.cap` | 13/18 w500 sub | captions, help, subtitles |
| `V2Text.label` | 12/16 w700 | overlines, badges (smallest allowed) |
| `V2Text.button` / `buttonSm` | 16 / 14 w700 | button labels |
| `V2Text.serif(size:, color:)` | Gowun Batang | **only** emotional numbers & result titles: D+412, 궁합 결과 제목 |

```dart
Text('D+412', style: V2Text.serif(size: 40, color: Colors.white))
Text('3분 전', style: V2Text.cap.copyWith(color: p.muted))
```
Never below 12px. Don't hard-cap text scaling; layouts must survive 130%.

Korean wrapping: Flutter may break inside a word ("드려\n요."). For short
centered copy use `Text(V2Text.keepAll('알림을 보내 드려요'))` (lines break only
at spaces; tests must then `find.text(V2Text.keepAll(...))`).

## 3. Components (`widgets/`)

Icons: `V2Icons.*` (rounded Material Symbols). **No emoji as UI icons**
(emoji are content only).

```dart
// Header (Scaffold.appBar). Tab root / sub page / large title.
V2Header(title: '기록', actions: [V2IconButton(icon: V2Icons.add, tooltip: '기록 추가', onPressed: add)])
V2Header(title: '알림 설정')                      // back auto-shown when route can pop
V2Header(title: '개인정보·권한', showBack: true, large: true, subtitle: '언제든 바꿀 수 있어요')

// Icon button — 44px, tooltip is the screen-reader label (Korean).
V2IconButton(icon: V2Icons.bell, tooltip: '알림', dot: hasNew, onPressed: open)

// Buttons — primary (one per screen) / soft / ghost / text / danger / dangerSoft; md 52 full width, sm 44.
V2Button(label: '기록 남기기', onPressed: save)
V2Button(label: '저장', size: V2ButtonSize.sm, loading: saving, onPressed: save)
V2Button(label: '나중에', variant: V2ButtonVariant.text, onPressed: close)
V2Button(label: '사진 고르기', icon: V2Icons.gallery, variant: V2ButtonVariant.soft, onPressed: pick)
V2Button(label: '입력을 마쳐 주세요', onPressed: null)   // disabled

// Cards
V2Card(child: ...)                                   // raised
V2Card(variant: V2CardVariant.soft, onTap: open, child: ...)
V2Card(gradient: V2Gradients.hero, child: ...)

// Section label + optional action
V2Section(title: '우리 이야기', actionLabel: '전체 보기', onAction: all, child: V2List(children: [...]))

// Lists
V2List(children: [
  V2ListTile(icon: V2Icons.event, title: '기념일', subtitle: '88일 남음', onTap: open),
  V2ListTile(icon: V2Icons.bell, tone: V2Tone.lilac, title: '알림 받기',
      trailing: V2Toggle(value: on, onChanged: setOn)),
  V2ListTile(icon: V2Icons.logout, title: '로그아웃', destructive: true, onTap: logout),
])

// Chips — filter (selected = ink) or status tone
V2Chip(label: '가 본 곳', selected: f == 1, onTap: () => pick(1))
V2Chip(label: '연결됨', tone: V2Tone.ok, icon: V2Icons.ok)

// Badge / avatar
V2Badge(count: 3)  V2Badge.dot()
V2Avatar(name: '서윤', color: V2Avatar.partnerColor, size: V2AvatarSize.lg)
V2AvatarPair(me: '민지', partner: '서윤')

// Inputs
V2TextField(label: '이메일', hint: 'name@example.com', controller: c, keyboardType: TextInputType.emailAddress)
V2TextField(label: '비밀번호', password: true, error: errorText)
V2TextField(label: '한마디', maxLines: 4, help: '서윤에게만 보여요')
V2Toggle(value: v, onChanged: set, semanticLabel: '알림 받기')
V2Segmented<int>(segments: const [V2Segment(value: 0, label: '나'), V2Segment(value: 1, label: '우리')],
    selected: mode, onChanged: setMode)
V2Check(value: agree, onChanged: setAgree, label: '(필수) 이용약관에 동의해요')

// Bottom tabs (widget only — the shell owns navigation)
V2BottomTabBar(currentIndex: i, onTap: go, badges: const {1: 2}, dots: const {4})

// Banner
V2Banner(tone: V2BannerTone.warn, message: '위치 권한이 꺼져 있어요', actionLabel: '설정 열기', onAction: openSettings)
V2Banner.offline()

// Overlays
await showV2Sheet<T>(context, title: '장소 추가', builder: (ctx) => ..., actions: [V2Button(...)]);
await showV2Dialog<T>(context, title: '저장했어요', message: '...', actions: const [V2DialogAction(label: '확인')]);
if (await showV2Confirm(context, title: '기록을 지울까요?', message: '지운 기록은 되돌릴 수 없어요.',
    confirmLabel: '지우기', destructive: true)) { ... }
showV2Snack(context, '기록을 지웠어요', actionLabel: '되돌리기', onAction: undo);
showV2Snack(context, '저장하지 못했어요', tone: V2Tone.err);
await showV2ConfirmDestructiveSheet(context, title: '정말 탈퇴할까요?',
    consequences: ['서윤과의 연결이 끊어져요'], acknowledgement: '확인했어요', confirmLabel: '탈퇴하기');

// Permission: purpose sheet BEFORE the OS prompt; denied → 설정 열기 guidance.
final c = await showV2PermissionSheet(context, V2PermissionKind.location);   // .camera .photos .notification
if (c == V2PermissionChoice.allow) { /* request OS permission */ }
final d = await showV2PermissionSheet(context, V2PermissionKind.location, denied: true);
if (d == V2PermissionChoice.openSettings) { /* open app settings */ }
// Inline denied state on a screen: V2PermissionSheet(kind: ..., denied: true, onChoice: ...)

// States
V2EmptyState(illustration: const V2SceneIllustration(V2Scene.hearts), title: '아직 남긴 기록이 없어요',
    body: '오늘의 순간을 서윤과 나눠 보세요.', actionLabel: '첫 기록 남기기', onAction: compose)
V2EmptyState.unpaired(onAction: goPairing)
V2ErrorState(onRetry: reload)            V2ErrorState.offline(onRetry: reload)
const V2SkeletonList(count: 4)           const V2SkeletonCard()
V2Shimmer(child: Column(children: [V2SkeletonBox(height: 160, radius: 20), V2SkeletonLine(width: 120)]))

// Progress / illustration
V2ProgressRing(value: .7, semanticLabel: '이번 주 기록', center: Text('70%', style: V2Text.label))
V2ProgressBar(value: 3 / 5, semanticLabel: '5단계 중 3단계')
V2PhotoPlaceholder(seed: record.id, aspectRatio: 1)
V2Art(icon: V2Icons.camera)              V2SceneIllustration(V2Scene.map)   // hearts couple map photo offline letter calendar
```

## 4. Copy rules (PLAN.md §2)

- 해요체 everywhere: "~해요", "~할까요?", "~해 주세요". No 합니다/반말.
- Use the partner's **name** ("서윤이 기록을 남겼어요") or "우리". Never "연인", "상대방".
- **No English UI copy** (MomentLoop → "기록", OK → "확인").
- No internal terms: 활성 커플, user_code, 해시, 방 코드, Ping, 소켓, 에러 코드.
- Buttons are verbs: "기록 남기기", "다시 시도", "설정 열기". Cancel = "취소" / "나중에" / "닫기".
- Errors say what happened + what to do: "사진을 올리지 못했어요. 다시 시도해 주세요."
- One primary action per screen.

## 5. State completeness (required on every screen)

Each data screen must handle, where applicable:

1. **empty** → `V2EmptyState` (with a CTA when the user can fix it)
2. **loading** → skeleton (`V2SkeletonList` / `V2SkeletonCard` / `V2Shimmer`), not a bare spinner
3. **error** → `V2ErrorState(onRetry:)` (or `V2Banner(tone: err)` for partial failure)
4. **offline** → `V2ErrorState.offline` / `V2Banner.offline()`
5. **unpaired** → `V2EmptyState.unpaired(onAction:)`
6. **permission denied** → `V2PermissionSheet(denied: true)` inline or `showV2PermissionSheet(..., denied: true)`

## 6. Accessibility rules

- Tap targets ≥ 44px (all components comply; keep it in custom layouts).
- Prefer Material widgets (`InkWell`, `TextButton`, `IconButton`) for semantics.
- **If you ever wrap a tappable in `Semantics(button: true, ...)` with
  `ExcludeSemantics` inside, pass the same `onTap` to `Semantics`.** Otherwise
  taps are ignored on Flutter web when semantics are enabled (real bug we hit).
- Icon-only buttons need a Korean `tooltip`.
- Respect reduced motion: use `V2Motion.of(context, ...)` for durations.
- Text contrast: only token pairs from `V2Contrast.pairs`.

## 7. Testing tips

- `V2Shimmer` animates forever → use `tester.pump(duration)`, not
  `pumpAndSettle`, while a skeleton is on screen (or set
  `MediaQueryData(disableAnimations: true)`).
- Semantic tap helper pattern: see `test/v2/v2_widgets_test.dart` (`_semanticTap`).
