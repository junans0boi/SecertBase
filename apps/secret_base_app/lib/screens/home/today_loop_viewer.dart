import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../core/auth_service.dart';
import '../../core/today_api.dart';
import '../../v2/v2.dart';
import 'home_format.dart';

/// 오늘의 순간 뷰어: the partner's and my moment for today.
///
/// * [reveal]: show the "오늘의 순간이 모였어요" intro the first time a
///   completed day is opened on this device (once per day).
/// * Opening a completed day marks it viewed ([onMarkViewed], defaulting to
///   `POST /api/retention/today/view` with the signed-in session).
class TodayLoopViewer extends StatefulWidget {
  final TodayState state;
  final String baseUrl;
  final String myName;
  final String partnerName;
  final bool reveal;
  final Future<void> Function()? onMarkViewed;
  final VoidCallback? onPoke;

  const TodayLoopViewer({
    super.key,
    required this.state,
    required this.baseUrl,
    this.myName = '나',
    this.partnerName = '짝꿍',
    this.reveal = false,
    this.onMarkViewed,
    this.onPoke,
  });

  @override
  State<TodayLoopViewer> createState() => _TodayLoopViewerState();
}

class _TodayLoopViewerState extends State<TodayLoopViewer> {
  bool? _showIntro;
  bool _marked = false;

  String get _revealKey => 'today_reveal_${widget.state.date}';

  @override
  void initState() {
    super.initState();
    if (widget.reveal && widget.state.status == TodayStatus.complete) {
      _loadRevealFlag();
    } else {
      _showIntro = false;
      _markViewed();
    }
  }

  Future<void> _loadRevealFlag() async {
    var seen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(_revealKey) ?? false;
    } catch (_) {
      seen = false;
    }
    if (!mounted) return;
    setState(() => _showIntro = !seen);
    if (seen) _markViewed();
  }

  Future<void> _openFromIntro() async {
    setState(() => _showIntro = false);
    _markViewed();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_revealKey, true);
    } catch (_) {
      // Showing the intro again next time is acceptable.
    }
  }

  Future<void> _markViewed() async {
    if (_marked || widget.state.status != TodayStatus.complete) return;
    _marked = true;
    try {
      final custom = widget.onMarkViewed;
      if (custom != null) {
        await custom();
        return;
      }
      final auth = AuthService();
      final token = auth.token;
      if (token == null) return;
      final api = TodayApi(baseUrl: auth.baseUrl, token: token);
      try {
        await api.markViewed();
      } finally {
        api.close();
      }
    } catch (_) {
      // Viewed state is best effort; the moments are already on screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    final intro = _showIntro;
    return V2Theme(
      child: AnimatedSwitcher(
        duration: V2Motion.of(context, V2Motion.slow),
        child: intro == null
            ? const Scaffold(key: ValueKey('wait'), body: SizedBox.expand())
            : intro
            ? _RevealIntro(
                key: const ValueKey('intro'),
                myName: widget.myName,
                partnerName: widget.partnerName,
                onOpen: _openFromIntro,
              )
            : _content(),
      ),
    );
  }

  Widget _content() {
    final s = widget.state;
    final day = parseDay(s.date);
    final partnerWaiting =
        s.partnerMoment == null && s.status == TodayStatus.selfWaiting;
    final partnerLocked =
        s.partnerMoment == null && s.status == TodayStatus.partnerWaiting;
    return Scaffold(
      key: const ValueKey('content'),
      appBar: const V2Header(title: '오늘의 순간'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          V2Space.page,
          V2Space.x2,
          V2Space.page,
          V2Space.x8,
        ),
        children: [
          Text(
            day == null ? '오늘' : monthDayWeekday(day),
            textAlign: TextAlign.center,
            style: V2Text.cap,
          ),
          const SizedBox(height: V2Space.x4),
          if (partnerWaiting)
            _StatePanel(
              icon: Icons.hourglass_top_rounded,
              tone: V2Tone.sky,
              title: '${josa(widget.partnerName, '을', '를')} 기다리고 있어요',
              body: '${josa(widget.partnerName, '이', '가')} 남기면 두 순간이 함께 열려요',
            )
          else if (partnerLocked)
            const _StatePanel(
              icon: V2Icons.lock,
              tone: V2Tone.rose,
              title: '내 순간을 남기면 열려요',
              body: '둘 다 남기면 함께 볼 수 있어요',
            )
          else
            _MomentPanel(
              moment: s.partnerMoment,
              name: widget.partnerName,
              isMe: false,
              baseUrl: widget.baseUrl,
            ),
          const SizedBox(height: V2Space.x3),
          _MomentPanel(
            moment: s.myMoment,
            name: widget.myName,
            isMe: true,
            baseUrl: widget.baseUrl,
          ),
          if (partnerWaiting && widget.onPoke != null) ...[
            const SizedBox(height: V2Space.x5),
            V2Button(
              label: '${widget.partnerName}에게 콕 찌르기',
              icon: Icons.touch_app_rounded,
              variant: V2ButtonVariant.soft,
              onPressed: widget.onPoke,
            ),
          ],
          if (s.partnerMoment?.deleted == true) ...[
            const SizedBox(height: V2Space.x4),
            Text(
              '내가 남긴 순간은 그대로 남아 있어요',
              textAlign: TextAlign.center,
              style: V2Text.cap,
            ),
          ],
        ],
      ),
    );
  }
}

class _RevealIntro extends StatelessWidget {
  const _RevealIntro({
    super.key,
    required this.myName,
    required this.partnerName,
    required this.onOpen,
  });

  final String myName;
  final String partnerName;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: V2Gradients.heroSoft),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(V2Space.x6),
            child: Column(
              children: [
                const Spacer(),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: V2Motion.of(
                    context,
                    const Duration(milliseconds: 700),
                  ),
                  curve: Curves.elasticOut,
                  builder: (context, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: const V2SceneIllustration(V2Scene.hearts, width: 200),
                ),
                const SizedBox(height: V2Space.x6),
                Text(
                  V2Text.keepAll('오늘의 순간이 모였어요'),
                  textAlign: TextAlign.center,
                  style: V2Text.serif(size: 26, color: p.ink),
                ),
                const SizedBox(height: V2Space.x3),
                Text(
                  V2Text.keepAll(
                    '${josa(myName, '과', '와')} '
                    '${josa(partnerName, '이', '가')} 각자 남긴 하루를 이제 함께 열어 볼 수 있어요',
                  ),
                  textAlign: TextAlign.center,
                  style: V2Text.body.copyWith(color: p.sub),
                ),
                const Spacer(),
                V2Button(label: '열어 보기', onPressed: onOpen),
                const SizedBox(height: V2Space.x2),
                V2Button(
                  label: '건너뛰기',
                  variant: V2ButtonVariant.text,
                  onPressed: onOpen,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final V2Tone tone;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return V2Card(
      variant: V2CardVariant.soft,
      padding: const EdgeInsets.symmetric(
        horizontal: V2Space.x5,
        vertical: V2Space.x8,
      ),
      child: Column(
        children: [
          V2Art(icon: icon, tone: tone),
          const SizedBox(height: V2Space.x3),
          Text(
            V2Text.keepAll(title),
            textAlign: TextAlign.center,
            style: V2Text.head,
          ),
          const SizedBox(height: V2Space.x1),
          Text(V2Text.keepAll(body), textAlign: TextAlign.center, style: V2Text.cap),
        ],
      ),
    );
  }
}

class _MomentPanel extends StatelessWidget {
  final TodayMoment? moment;
  final String name;
  final bool isMe;
  final String baseUrl;

  const _MomentPanel({
    required this.moment,
    required this.name,
    required this.isMe,
    required this.baseUrl,
  });

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final value = moment;
    if (value == null) {
      return const _StatePanel(
        icon: V2Icons.offline,
        tone: V2Tone.neutral,
        title: '순간을 불러오지 못했어요',
        body: '네트워크를 확인하고 다시 시도해 주세요',
      );
    }
    if (value.deleted) {
      return _StatePanel(
        icon: Icons.hide_source_rounded,
        tone: V2Tone.neutral,
        title: isMe ? '내가 지운 순간이에요' : '${josa(name, '이', '가')} 이 순간을 지웠어요',
        body: '지운 순간은 다시 볼 수 없어요',
      );
    }
    final time = clockLabel(value.capturedAt ?? value.takenAt);
    return V2Card(
      padding: const EdgeInsets.all(V2Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              V2Avatar(
                name: name,
                size: V2AvatarSize.sm,
                color: isMe ? V2Avatar.meColor : V2Avatar.partnerColor,
              ),
              const SizedBox(width: V2Space.x2),
              Expanded(
                child: Text(
                  time == null ? name : '$name · $time',
                  style: V2Text.bodyStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: V2Space.x3),
          _TodayMedia(moment: value, baseUrl: baseUrl),
          if (value.caption != null) ...[
            const SizedBox(height: V2Space.x3),
            Text(value.caption!, style: V2Text.body.copyWith(color: p.ink)),
          ],
          if (value.linkedPlaceName != null) ...[
            const SizedBox(height: V2Space.x3),
            V2Chip(
              label: value.linkedPlaceName!,
              icon: V2Icons.location,
              tone: V2Tone.sage,
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayMedia extends StatelessWidget {
  final TodayMoment moment;
  final String baseUrl;

  const _TodayMedia({required this.moment, required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    final rawUrl = moment.mediaUrl;
    if (rawUrl == null || moment.mediaType == 'text') {
      return const SizedBox.shrink();
    }
    final url = rawUrl.startsWith('http') ? rawUrl : '$baseUrl$rawUrl';
    if (moment.mediaType == 'video') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _TodayVideoPlayer(url: url),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          semanticLabel: '오늘의 순간 사진',
          errorBuilder: (_, _, _) =>
              V2PhotoPlaceholder(seed: moment.id, icon: Icons.broken_image_rounded),
        ),
      ),
    );
  }
}

class _TodayVideoPlayer extends StatefulWidget {
  final String url;

  const _TodayVideoPlayer({required this.url});

  @override
  State<_TodayVideoPlayer> createState() => _TodayVideoPlayerState();
}

class _TodayVideoPlayerState extends State<_TodayVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() => setState(() {
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
  });

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const V2PhotoPlaceholder(
        aspectRatio: 16 / 9,
        icon: Icons.videocam_off_rounded,
        semanticLabel: '영상을 불러오지 못했어요',
      );
    }
    if (!_ready) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: V2Shimmer(child: V2SkeletonBox(height: double.infinity)),
      );
    }
    final playing = _controller.value.isPlaying;
    return Semantics(
      button: true,
      label: playing ? '영상 일시정지' : '영상 재생',
      onTap: _toggle,
      child: GestureDetector(
        onTap: _toggle,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
            if (!playing)
              const Icon(
                Icons.play_circle_fill_rounded,
                color: V2Colors.surface,
                size: 52,
              ),
          ],
        ),
      ),
    );
  }
}
