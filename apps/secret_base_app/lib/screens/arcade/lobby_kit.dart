/// 해적 룰렛·제로·그림 맞히기·고스톱 대기실이 같이 쓰는 모던 클래식 부품.
///
/// 게임마다 팔레트([LobbyPalette])와 서체만 다르고 뼈대는 같다: 얇은 상단바(뒤로/제목/규칙/소리),
/// 가운데 무대, 두 사람 캡슐, 하단 단일 주 버튼. 로비 상태(방장·준비·카운트다운)는
/// `GameLobbyScreen`이 들고 있고, 여기서는 값을 받아 그리기만 한다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/game_sfx/game_sfx.dart';

typedef LobbyTextFn =
    TextStyle Function(
      double size, {
      Color? color,
      FontWeight? weight,
      double? height,
      double spacing,
    });

/// 게임 하나의 로비 색·서체.
@immutable
class LobbyPalette {
  final bool dark;
  final Color bg;
  final Color panel;
  final Color line;
  final Color ink;
  final Color sub;
  final Color accent;
  final Color accentInk;
  final Color me;
  final Color meInk;
  final Color opp;
  final Color oppInk;

  /// "준비 완료" 글자·점 색.
  final Color ok;

  /// 카드에 까는 한 겹 그림자(어두운 판은 비운다).
  final List<BoxShadow> shadow;

  /// 본문·UI 서체(Noto Sans KR).
  final LobbyTextFn ui;

  /// 제목·숫자에 쓰는 게임별 포인트 서체 하나.
  final LobbyTextFn display;

  const LobbyPalette({
    required this.dark,
    required this.bg,
    required this.panel,
    required this.line,
    required this.ink,
    required this.sub,
    required this.accent,
    required this.accentInk,
    required this.me,
    required this.meInk,
    required this.opp,
    required this.oppInk,
    required this.ok,
    required this.ui,
    required this.display,
    this.shadow = const [],
  });

  /// 선택된 칸의 옅은 바탕.
  Color get accentWash => accent.withValues(alpha: dark ? 0.16 : 0.10);

  BoxDecoration card({double radius = 20, Color? color}) => BoxDecoration(
    color: color ?? panel,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: line),
    boxShadow: shadow,
  );
}

/// Noto Sans KR. 내려받는 굵기를 400/500/700 셋으로만 쓴다(한글 글꼴은 한 벌이 무겁다).
TextStyle lobbyNoto(
  double size, {
  required Color color,
  FontWeight? weight,
  double? height,
  double spacing = 0,
}) {
  final w = weight?.value ?? 500;
  return GoogleFonts.notoSansKr(
    fontSize: size,
    color: color,
    fontWeight: w <= 400
        ? FontWeight.w400
        : w <= 500
        ? FontWeight.w500
        : FontWeight.w700,
    height: height,
    letterSpacing: spacing * size,
  );
}

/// 로비에서 보여 줄 한 사람.
@immutable
class LobbySeat {
  final String name;
  final bool present;
  final bool isMe;
  final bool isHost;
  final String status;
  final bool ready;

  const LobbySeat({
    required this.name,
    required this.present,
    required this.isMe,
    required this.isHost,
    required this.status,
    required this.ready,
  });

  const LobbySeat.empty()
    : name = '비어 있음',
      present = false,
      isMe = false,
      isHost = false,
      status = '기다리는 중',
      ready = false;

  String get initial =>
      present && name.isNotEmpty ? String.fromCharCode(name.runes.first) : '…';

  String get semanticLabel =>
      '$name${isHost ? ', 방장' : ''}, $status${isMe ? ', 나' : ''}';
}

/// 왼쪽은 항상 나, 오른쪽은 상대.
@immutable
class LobbySeats {
  final LobbySeat left;
  final LobbySeat right;

  const LobbySeats(this.left, this.right);

  /// [needsAgree]이면 방장이 아닌 사람은 동의(준비 완료)를 눌러야 "준비 완료"로 보인다.
  factory LobbySeats.resolve({
    required List<String> players,
    required String? host,
    required String? me,
    required Map<String, String> nicknames,
    required Map<String, bool> ready,
    bool needsAgree = false,
  }) {
    final mine = me != null && players.contains(me)
        ? me
        : (players.isNotEmpty ? players.first : null);
    final other = players.where((p) => p != mine).firstOrNull;
    LobbySeat seat(String? id) {
      if (id == null) return const LobbySeat.empty();
      final nick = nicknames[id];
      final isMe = id == me;
      final name = isMe ? '나' : (nick == null || nick.isEmpty ? '상대' : nick);
      final isHost = id == host;
      final done = isHost || !needsAgree || (ready[id] ?? false);
      return LobbySeat(
        name: name,
        present: true,
        isMe: isMe,
        isHost: isHost,
        status: done ? '준비 완료' : '동의 대기 중',
        ready: done,
      );
    }

    return LobbySeats(seat(mine), seat(other));
  }
}

/// 화면 뼈대: 배경 + 상단바 + 스크롤되는 가운데 + 고정 하단 버튼.
class LobbyScaffold extends StatelessWidget {
  final LobbyPalette palette;

  /// 게임 배경(질감·조명). 자식을 감싸서 돌려준다.
  final Widget Function(Widget child) backdrop;
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onHelp;

  /// 가운데 내용. 세로 공간이 모자라면 `compact`가 true.
  final Widget Function(BuildContext context, bool compact) body;

  /// 하단 영역(힌트 문장 + 주 버튼).
  final Widget bottom;

  const LobbyScaffold({
    super.key,
    required this.palette,
    required this.backdrop,
    required this.title,
    required this.onBack,
    required this.body,
    required this.bottom,
    this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Scaffold(
      backgroundColor: p.bg,
      body: backdrop(
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  LobbyTopBar(
                    palette: p,
                    title: title,
                    onBack: onBack,
                    onHelp: onHelp,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final compact = box.maxHeight < 560;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: math.max(0, box.maxHeight - 16),
                            ),
                            child: body(context, compact),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      math.max(
                        20,
                        MediaQuery.viewPaddingOf(context).bottom + 12,
                      ),
                    ),
                    child: bottom,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 얇은 상단바: 뒤로 / 가운데 제목 / 규칙 / 소리.
class LobbyTopBar extends StatelessWidget {
  final LobbyPalette palette;
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onHelp;

  const LobbyTopBar({
    super.key,
    required this.palette,
    required this.title,
    required this.onBack,
    this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 96),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: p.display(19, color: p.ink),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                _BarButton(
                  palette: p,
                  tooltip: '게임 나가기',
                  icon: Icons.chevron_left_rounded,
                  size: 30,
                  onPressed: onBack,
                ),
                const Spacer(),
                if (onHelp != null)
                  _BarButton(
                    palette: p,
                    tooltip: '규칙 보기',
                    icon: Icons.help_outline_rounded,
                    size: 22,
                    onPressed: onHelp,
                  ),
                _MuteButton(palette: p),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final LobbyPalette palette;
  final String tooltip;
  final IconData icon;
  final double size;
  final VoidCallback? onPressed;

  const _BarButton({
    required this.palette,
    required this.tooltip,
    required this.icon,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: size, color: palette.sub),
        onPressed: onPressed,
      ),
    );
  }
}

class _MuteButton extends StatefulWidget {
  final LobbyPalette palette;

  const _MuteButton({required this.palette});

  @override
  State<_MuteButton> createState() => _MuteButtonState();
}

class _MuteButtonState extends State<_MuteButton> {
  @override
  void initState() {
    super.initState();
    // 저장된 음소거 설정만 읽어 온다(소리는 미리 만들지 않는다).
    GameSfx.instance.init(const []).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final sfx = GameSfx.instance;
    return _BarButton(
      palette: widget.palette,
      tooltip: sfx.muted ? '소리 켜기' : '소리 끄기',
      icon: sfx.muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
      size: 22,
      onPressed: () async {
        await sfx.setMuted(!sfx.muted);
        if (!sfx.muted) sfx.play(GameSound.tap);
        if (mounted) setState(() {});
      },
    );
  }
}

/// 두 사람 캡슐 한 쌍(나 | 상대).
class LobbySeatRow extends StatelessWidget {
  final LobbyPalette palette;
  final LobbySeats seats;
  final double radius;

  const LobbySeatRow({
    super.key,
    required this.palette,
    required this.seats,
    this.radius = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LobbySeatPill(
            palette: palette,
            seat: seats.left,
            radius: radius,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LobbySeatPill(
            palette: palette,
            seat: seats.right,
            radius: radius,
          ),
        ),
      ],
    );
  }
}

class LobbySeatPill extends StatelessWidget {
  final LobbyPalette palette;
  final LobbySeat seat;
  final double radius;

  const LobbySeatPill({
    super.key,
    required this.palette,
    required this.seat,
    this.radius = 32,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final fill = seat.isMe ? p.me : p.opp;
    final inkOn = seat.isMe ? p.meInk : p.oppInk;
    return Semantics(
      container: true,
      label: seat.semanticLabel,
      excludeSemantics: true,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: p.panel,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: seat.present && seat.isMe ? p.accent : p.line,
            width: seat.present && seat.isMe ? 1.4 : 1,
          ),
          boxShadow: p.shadow,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: seat.present
                  ? BoxDecoration(shape: BoxShape.circle, color: fill)
                  : BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: p.line, width: 1.5),
                    ),
              child: Text(
                seat.initial,
                style: seat.present
                    ? p.ui(17, color: inkOn, weight: FontWeight.w700)
                    : p.ui(17, color: p.sub),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          seat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: p.ui(
                            15,
                            color: seat.present ? p.ink : p.sub,
                            weight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (seat.isHost) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: p.line),
                          ),
                          child: Text(
                            '방장',
                            style: p.ui(
                              11,
                              color: p.sub,
                              weight: FontWeight.w700,
                              height: 16 / 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    seat.status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: p.ui(
                      12,
                      color: seat.present && seat.ready ? p.ok : p.sub,
                      weight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "제목  힌트" 한 줄.
class LobbySectionHead extends StatelessWidget {
  final LobbyPalette palette;
  final String title;
  final String? hint;
  final EdgeInsetsGeometry padding;

  const LobbySectionHead({
    super.key,
    required this.palette,
    required this.title,
    this.hint,
    this.padding = const EdgeInsets.only(bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: p.ui(14, color: p.ink, weight: FontWeight.w700),
          ),
          if (hint != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                hint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: p.ui(12, color: p.sub, weight: FontWeight.w400),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 라벨 + 문장 규칙 줄(얇은 선으로 나눔).
class LobbyRuleRows extends StatelessWidget {
  final LobbyPalette palette;
  final List<(String, String)> rows;

  const LobbyRuleRows({super.key, required this.palette, required this.rows});

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Column(
      children: [
        for (final (label, text) in rows)
          Container(
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.line)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    label,
                    style: p.ui(12, color: p.sub, weight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: p.ui(
                      13,
                      color: p.ink,
                      weight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 누를 수 있는 칸의 공통 접근성: 방장만 누르고, 이미 고른 칸은 다시 안 눌린다.
/// 스크린리더가 눌러도 같은 동작이 되도록 Semantics에도 onTap을 건다.
class LobbyTapTarget extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  const LobbyTapTarget({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final fire = enabled && !selected ? onTap : null;
    // 방장이 아니면 고르지 않은 칸을 흐리게 해서 "방장이 이걸 골랐다"가 바로 보이게 한다.
    final dimmed = !enabled && !selected;
    return Semantics(
      button: enabled,
      selected: selected,
      label: label,
      onTap: fire,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: fire,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: dimmed ? 0.5 : 1,
          child: child,
        ),
      ),
    );
  }
}

enum LobbyButtonStyle { primary, ghost, off }

/// 하단 단일 주 버튼(단색). [onPressed]가 없으면 비활성 톤.
class LobbyMainButton extends StatelessWidget {
  final LobbyPalette palette;
  final String label;
  final VoidCallback? onPressed;
  final LobbyButtonStyle style;

  const LobbyMainButton({
    super.key,
    required this.palette,
    required this.label,
    this.onPressed,
    this.style = LobbyButtonStyle.primary,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final enabled = onPressed != null && style != LobbyButtonStyle.off;
    final ghost = style == LobbyButtonStyle.ghost;
    final fill = enabled && !ghost ? p.accent : Colors.transparent;
    final fg = !enabled
        ? p.sub
        : ghost
        ? p.accent
        : p.accentInk;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? onPressed : null,
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Material(
          color: !enabled ? p.panel : fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: !enabled
                ? BorderSide(color: p.line)
                : ghost
                ? BorderSide(color: p.accent, width: 1.4)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.ui(17, color: fg, weight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 규칙 한 장(팔레트 색의 단순한 대화상자).
Future<void> showLobbyHowTo(
  BuildContext context, {
  required LobbyPalette palette,
  required String title,
  required List<String> lines,
}) {
  final p = palette;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: p.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: p.display(22)),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final line in lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: p.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                line,
                                style: p.ui(
                                  14,
                                  color: p.ink,
                                  weight: FontWeight.w400,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            LobbyMainButton(
              palette: p,
              label: '알겠어요',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 시작 카운트다운(어두운 막 + 큰 숫자). 게임 서체로 그린다.
class LobbyCountdown extends StatelessWidget {
  final LobbyPalette palette;
  final int seconds;

  const LobbyCountdown({
    super.key,
    required this.palette,
    required this.seconds,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.72),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$seconds', style: p.display(96, color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  '게임 시작!',
                  style: p.ui(
                    20,
                    color: Colors.white70,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 방장이 아니면 읽기 전용이라는 힌트.
String lobbyOptionHint({required bool isHost}) =>
    isHost ? '방장이 선택' : '방장이 고른 설정';

/// 방장이 아닌 사람의 기본 하단 버튼 문구.
const kLobbyGuestWaitLabel = '방장이 시작할 때까지 기다려 주세요';
