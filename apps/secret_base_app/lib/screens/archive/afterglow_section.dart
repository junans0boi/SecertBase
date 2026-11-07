import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/afterglow_api.dart';
import '../../v2/v2.dart';

/// "우리의 여운": what each of us felt after the same visit.
///
/// The server returns one slot per person (me first). The section turns that
/// into four partner-aware states:
///  * nothing yet     - nobody left a scene; CTA to write the first one
///  * I wrote         - waiting for the partner; their slot stays closed
///  * partner wrote   - my turn; their scene stays closed until I write mine
///  * both done       - both scenes are opened
///
/// [currentUserId] is optional: without it the first slot is treated as mine
/// (the server always lists the caller first).
class AfterglowSection extends StatelessWidget {
  final AfterglowState state;
  final String baseUrl;
  final VoidCallback? onContribute;
  final int? currentUserId;

  const AfterglowSection({
    super.key,
    required this.state,
    required this.baseUrl,
    this.onContribute,
    this.currentUserId,
  });

  AfterglowContribution? get _mine {
    final list = state.contributions;
    if (list.isEmpty) return null;
    if (currentUserId != null) {
      for (final item in list) {
        if (item.userId == currentUserId) return item;
      }
    }
    return list.first;
  }

  AfterglowContribution? get _partner {
    final mine = _mine;
    for (final item in state.contributions) {
      if (!identical(item, mine)) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mine = _mine;
    final partner = _partner;
    final mineDone = mine?.contributed ?? false;
    final partnerDone = partner?.contributed ?? false;
    final partnerName = _name(partner);

    final _Phase phase = switch ((mineDone, partnerDone)) {
      (true, true) => _Phase.both,
      (true, false) => _Phase.mineOnly,
      (false, true) => _Phase.partnerOnly,
      _ => _Phase.none,
    };

    final p = V2Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  '우리의 여운',
                  style: V2Text.head.copyWith(color: p.ink),
                ),
              ),
            ),
            _statusChip(phase, partnerName),
          ],
        ),
        const SizedBox(height: V2Space.x1),
        Text(_subtitle(), style: V2Text.cap.copyWith(color: p.sub)),
        const SizedBox(height: V2Space.x3),
        ..._body(phase, mine, partner, partnerName),
        if (onContribute != null) ...[
          const SizedBox(height: V2Space.x2),
          _cta(phase),
        ],
      ],
    );
  }

  String _name(AfterglowContribution? partner) {
    final name = partner?.userName.trim();
    return (name == null || name.isEmpty) ? '상대' : name;
  }

  String _subtitle() {
    final date = state.visit?.visitDate ?? '';
    final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(date);
    if (match == null) return '같은 데이트, 서로 다른 장면을 모아요';
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    return '$month월 $day일에 다녀왔어요';
  }

  Widget _statusChip(_Phase phase, String partnerName) {
    return switch (phase) {
      _Phase.none => const V2Chip(label: '아직 없어요'),
      _Phase.mineOnly => V2Chip(
        label: '$partnerName 기다리는 중',
        tone: V2Tone.honey,
        icon: V2Icons.lock,
      ),
      _Phase.partnerOnly => const V2Chip(
        label: '내 차례예요',
        tone: V2Tone.rose,
        icon: V2Icons.sparkle,
      ),
      _Phase.both => const V2Chip(
        label: '함께 열렸어요',
        tone: V2Tone.ok,
        icon: V2Icons.ok,
      ),
    };
  }

  List<Widget> _body(
    _Phase phase,
    AfterglowContribution? mine,
    AfterglowContribution? partner,
    String partnerName,
  ) {
    switch (phase) {
      case _Phase.none:
        return [
          _InfoCard(
            icon: V2Icons.camera,
            title: '아직 아무도 남기지 않았어요',
            body:
                '다녀온 날의 마음을 한 장면으로 남겨 보세요. '
                '$partnerName도 남기면 서로의 여운이 함께 열려요.',
          ),
        ];
      case _Phase.mineOnly:
        return [
          _scene(mine!, isMine: true),
          if (partner != null) ...[
            const SizedBox(height: V2Space.x2),
            _InfoCard(
              key: ValueKey('afterglow-${partner.userId}'),
              icon: V2Icons.lock,
              title: '$partnerName의 여운을 기다리고 있어요',
              body: '$partnerName도 남기면 서로의 여운이 함께 열려요.',
            ),
          ],
        ];
      case _Phase.partnerOnly:
        return [
          _InfoCard(
            key: ValueKey('afterglow-${partner!.userId}'),
            icon: V2Icons.heart,
            tone: V2Tone.rose,
            title: '$partnerName의 여운이 도착했어요',
            body: '내 여운을 남기면 $partnerName의 장면이 함께 열려요.',
          ),
          const SizedBox(height: V2Space.x2),
          _InfoCard(
            key: ValueKey('afterglow-${mine!.userId}'),
            icon: V2Icons.edit,
            title: '내 여운은 아직이에요',
            body: '그날 어땠는지 한 장면만 남겨 보세요.',
          ),
        ];
      case _Phase.both:
        return [
          _scene(mine!, isMine: true),
          const SizedBox(height: V2Space.x2),
          _scene(partner!, isMine: false),
        ];
    }
  }

  Widget _cta(_Phase phase) {
    switch (phase) {
      case _Phase.none:
        return V2Button(
          label: '첫 여운 남기기',
          icon: V2Icons.camera,
          onPressed: onContribute,
        );
      case _Phase.partnerOnly:
        return V2Button(
          label: '내 여운 남기기',
          icon: V2Icons.camera,
          onPressed: onContribute,
        );
      case _Phase.mineOnly:
      case _Phase.both:
        return V2Button(
          label: '내 여운 다시 남기기',
          icon: V2Icons.edit,
          variant: V2ButtonVariant.soft,
          onPressed: onContribute,
        );
    }
  }

  Widget _scene(AfterglowContribution item, {required bool isMine}) {
    final mediaUrl = item.mediaUrl == null
        ? null
        : (item.mediaUrl!.startsWith('http')
              ? item.mediaUrl!
              : '$baseUrl${item.mediaUrl}');
    final owner = isMine ? '나' : _name(item);
    return Builder(
      builder: (context) {
        final p = V2Palette.of(context);
        return V2Card(
          key: ValueKey('afterglow-${item.userId}'),
          variant: V2CardVariant.flat,
          padding: const EdgeInsets.all(V2Space.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  V2Avatar(
                    name: owner,
                    size: V2AvatarSize.sm,
                    color: isMine ? V2Avatar.meColor : V2Avatar.partnerColor,
                  ),
                  const SizedBox(width: V2Space.x2),
                  Expanded(
                    child: Text(
                      isMine ? '나의 여운' : '$owner의 여운',
                      style: V2Text.bodyStrong.copyWith(color: p.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: V2Space.x2),
              if (!item.contributed)
                Text(
                  '아직 남긴 장면이 없어요',
                  style: V2Text.body.copyWith(color: p.muted),
                )
              else if (item.deleted)
                Text('삭제된 순간이에요', style: V2Text.body.copyWith(color: p.muted))
              else ...[
                if (mediaUrl != null && item.mediaType == 'image')
                  Padding(
                    padding: const EdgeInsets.only(bottom: V2Space.x2),
                    child: _AfterglowImage(url: mediaUrl, owner: owner),
                  )
                else if (mediaUrl != null && item.mediaType == 'video')
                  Padding(
                    padding: const EdgeInsets.only(bottom: V2Space.x2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(V2Radius.ctl),
                      child: _AfterglowVideoPlayer(url: mediaUrl),
                    ),
                  ),
                if (item.caption != null)
                  Text(
                    item.caption!,
                    style: V2Text.bodyStrong.copyWith(color: p.ink),
                  )
                else if (item.momentCaption != null)
                  Text(
                    item.momentCaption!,
                    style: V2Text.body.copyWith(color: p.ink),
                  ),
                if (item.emotionTag != null) ...[
                  const SizedBox(height: V2Space.x2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: V2Chip(
                      label: '#${item.emotionTag}',
                      tone: V2Tone.rose,
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

enum _Phase { none, mineOnly, partnerOnly, both }

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.tone = V2Tone.neutral,
  });

  final IconData icon;
  final String title;
  final String body;
  final V2Tone tone;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return V2Card(
      variant: V2CardVariant.soft,
      padding: const EdgeInsets.all(V2Space.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V2Art(
            icon: icon,
            size: 48,
            tone: tone == V2Tone.neutral ? V2Tone.rose : tone,
          ),
          const SizedBox(width: V2Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: V2Text.bodyStrong.copyWith(color: p.ink)),
                const SizedBox(height: V2Space.x1),
                Text(body, style: V2Text.cap.copyWith(color: p.sub)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AfterglowImage extends StatelessWidget {
  const _AfterglowImage({required this.url, required this.owner});

  final String url;
  final String owner;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(V2Radius.ctl),
      child: Image.network(
        url,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        semanticLabel: '$owner의 여운 사진',
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const V2Shimmer(
                child: V2SkeletonBox(height: 160, radius: V2Radius.ctl),
              ),
        errorBuilder: (context, error, stack) =>
            const _MediaFallback(message: '사진을 불러오지 못했어요'),
      ),
    );
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback({required this.message, this.icon = V2Icons.image});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.soft,
        borderRadius: BorderRadius.circular(V2Radius.ctl),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: p.muted),
          const SizedBox(height: V2Space.x1),
          Text(message, style: V2Text.cap.copyWith(color: p.sub)),
        ],
      ),
    );
  }
}

class _AfterglowVideoPlayer extends StatefulWidget {
  final String url;

  const _AfterglowVideoPlayer({required this.url});

  @override
  State<_AfterglowVideoPlayer> createState() => _AfterglowVideoPlayerState();
}

class _AfterglowVideoPlayerState extends State<_AfterglowVideoPlayer> {
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
          if (mounted) setState(() => _ready = true);
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const _MediaFallback(
        message: '동영상을 불러오지 못했어요',
        icon: V2Icons.video,
      );
    }
    if (!_ready) {
      return const V2Shimmer(
        child: V2SkeletonBox(height: 160, radius: V2Radius.ctl),
      );
    }
    final playing = _controller.value.isPlaying;
    return Semantics(
      button: true,
      label: playing ? '동영상 일시정지' : '동영상 재생',
      onTap: _toggle,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio == 0
                ? 1
                : _controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller),
                if (!playing)
                  Icon(
                    Icons.play_circle_fill_rounded,
                    size: 56,
                    color: V2Colors.surface,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
