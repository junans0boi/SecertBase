import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/afterglow_api.dart';
import '../../core/main_design.dart';

class AfterglowSection extends StatelessWidget {
  final AfterglowState state;
  final String baseUrl;
  final VoidCallback? onContribute;

  const AfterglowSection({
    super.key,
    required this.state,
    required this.baseUrl,
    this.onContribute,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('우리의 여운', style: mainTitle(size: 18)),
        const SizedBox(height: 4),
        Text(
          '${state.visit?.visitDate ?? ''} · 같은 데이트, 서로 다른 장면',
          style: mainBody(size: 12, color: kMainMuted),
        ),
        const SizedBox(height: 10),
        ...state.contributions.map(_card),
        if (onContribute != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onContribute,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('내 한 장 남기기'),
            ),
          ),
      ],
    );
  }

  Widget _card(AfterglowContribution item) {
    final mediaUrl = item.mediaUrl == null
        ? null
        : (item.mediaUrl!.startsWith('http')
              ? item.mediaUrl!
              : '$baseUrl${item.mediaUrl}');
    return Container(
      key: ValueKey('afterglow-${item.userId}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kMainPaper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kMainLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.userName,
            style: mainBody(size: 12, color: kMainSub, weight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          if (!item.contributed)
            Text('아직 남긴 장면이 없어요', style: mainBody(size: 13, color: kMainMuted))
          else if (item.deleted)
            Text('삭제된 순간이에요', style: mainBody(size: 13, color: kMainMuted))
          else ...[
            if (mediaUrl != null && item.mediaType == 'image')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    mediaUrl,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else if (mediaUrl != null && item.mediaType == 'video')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _AfterglowVideoPlayer(url: mediaUrl),
                ),
              ),
            if (item.caption != null)
              Text(
                item.caption!,
                style: mainBody(
                  size: 14,
                  color: kMainInk,
                  weight: FontWeight.w700,
                ),
              )
            else if (item.momentCaption != null)
              Text(
                item.momentCaption!,
                style: mainBody(size: 14, color: kMainInk),
              ),
            if (item.emotionTag != null) ...[
              const SizedBox(height: 6),
              Text(
                '#${item.emotionTag}',
                style: mainBody(
                  size: 12,
                  color: kMainRose,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ],
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

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Icon(Icons.videocam_off_outlined, color: kMainMuted),
        ),
      );
    }
    if (!_ready) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator(color: kMainRose)),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying
              ? _controller.pause()
              : _controller.play();
        });
      },
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio == 0
            ? 1
            : _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            if (!_controller.value.isPlaying)
              const Icon(
                Icons.play_circle_fill_rounded,
                size: 46,
                color: Colors.white,
              ),
          ],
        ),
      ),
    );
  }
}
