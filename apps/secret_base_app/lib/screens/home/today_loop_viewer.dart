import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/main_design.dart';
import '../../core/today_api.dart';

class TodayLoopViewer extends StatelessWidget {
  final TodayState state;
  final String baseUrl;

  const TodayLoopViewer({
    super.key,
    required this.state,
    required this.baseUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        surfaceTintColor: Colors.transparent,
        title: Text('오늘의 루프', style: mainTitle(size: 23)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
        children: [
          Text(
            state.date,
            textAlign: TextAlign.center,
            style: mainBody(size: 13, color: kMainMuted),
          ),
          const SizedBox(height: 16),
          _TodayMomentPanel(
            moment: state.myMoment,
            fallbackName: '나',
            baseUrl: baseUrl,
          ),
          const SizedBox(height: 14),
          _TodayMomentPanel(
            moment: state.partnerMoment,
            fallbackName: '상대',
            baseUrl: baseUrl,
            waiting: state.status == TodayStatus.selfWaiting,
          ),
        ],
      ),
    );
  }
}

class _TodayMomentPanel extends StatelessWidget {
  final TodayMoment? moment;
  final String fallbackName;
  final String baseUrl;
  final bool waiting;

  const _TodayMomentPanel({
    required this.moment,
    required this.fallbackName,
    required this.baseUrl,
    this.waiting = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = moment;
    final name = value?.userName ?? fallbackName;
    return MainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: mainBody(weight: FontWeight.w900, color: kMainInk),
          ),
          const SizedBox(height: 12),
          if (waiting && value == null)
            _NeutralState(
              icon: Icons.hourglass_empty_rounded,
              label: '상대의 순간을 기다리고 있어요',
            )
          else if (value == null)
            const _NeutralState(
              icon: Icons.cloud_off_outlined,
              label: '순간을 불러오지 못했어요',
            )
          else if (value.deleted)
            const _NeutralState(
              icon: Icons.hide_source_rounded,
              label: '삭제된 오늘의 순간이에요',
            )
          else ...[
            _TodayMedia(moment: value, baseUrl: baseUrl),
            if (value.caption != null) ...[
              const SizedBox(height: 12),
              Text(
                value.caption!,
                style: mainBody(size: 15, color: kMainInk, height: 1.55),
              ),
            ],
            if (value.linkedPlaceName != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.place_rounded, size: 17, color: kMainSage),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      value.linkedPlaceName!,
                      style: mainBody(
                        size: 12,
                        color: kMainSage,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _NeutralState extends StatelessWidget {
  final IconData icon;
  final String label;

  const _NeutralState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: kMainPaperSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: kMainMuted),
          const SizedBox(height: 8),
          Text(label, style: mainBody(color: kMainMuted)),
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
          errorBuilder: (_, _, _) => const ColoredBox(
            color: kMainPaperSoft,
            child: Center(
              child: Icon(Icons.broken_image_outlined, color: kMainMuted),
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: kMainPaperSoft,
          child: Center(
            child: Icon(Icons.videocam_off_outlined, color: kMainMuted),
          ),
        ),
      );
    }
    if (!_ready) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator(color: kMainRose)),
      );
    }
    return GestureDetector(
      onTap: () => setState(() {
        _controller.value.isPlaying ? _controller.pause() : _controller.play();
      }),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          if (!_controller.value.isPlaying)
            const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 52,
            ),
        ],
      ),
    );
  }
}
