import 'package:flutter/material.dart';

import '../../../v2/v2.dart';
import '../application/two_answers_events.dart';
import '../data/two_answers_repository.dart';
import '../domain/two_answer.dart';
import 'two_answers_history_screen.dart';

const twoAnswersMaxLength = 500;

/// 마주 열기: 오늘의 질문에 답하고, 둘 다 답하면 봉인이 풀려 서로의 답을 본다.
class TwoAnswersScreen extends StatefulWidget {
  final TwoAnswersRepository repository;
  final TwoAnswersEventSource? events;

  const TwoAnswersScreen({super.key, required this.repository, this.events});

  @override
  State<TwoAnswersScreen> createState() => _TwoAnswersScreenState();
}

class _TwoAnswersScreenState extends State<TwoAnswersScreen> {
  final _text = TextEditingController();
  TwoAnswerCard? _card;
  bool _loading = true;
  bool _failed = false;
  bool _saving = false;
  bool _momentSaved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final card = await widget.repository.today();
      if (!mounted) return;
      setState(() {
        _card = card;
        _text.text = card.myBody ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// 소켓 이벤트·포그라운드 복귀: 스피너 없이 다시 조회한다. 입력 중인 글은 지우지 않는다.
  Future<void> _refresh() async {
    if (_loading || _saving) return;
    try {
      final card = await widget.repository.today();
      if (!mounted) return;
      setState(() {
        _card = card;
        if (_text.text.isEmpty) _text.text = card.myBody ?? '';
      });
    } catch (_) {
      // 조용히 넘어간다. 다음 이벤트나 복귀 때 다시 시도한다.
    }
  }

  Future<void> _submit() async {
    final body = _text.text.trim();
    if (body.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final card = await widget.repository.answerToday(body);
      if (!mounted) return;
      setState(() {
        _card = card;
        _saving = false;
      });
    } on TwoAnswersException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.reason == 'already_open'
            ? '이미 열린 질문이라 고칠 수 없어요'
            : '답변을 저장하지 못했어요. 잠시 후 다시 해 보세요';
      });
      if (e.reason == 'already_open') _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '답변을 저장하지 못했어요. 잠시 후 다시 해 보세요';
      });
    }
  }

  Future<void> _saveMoment() async {
    final card = _card;
    if (card == null) return;
    try {
      await widget.repository.saveAsMoment(card);
      if (!mounted) return;
      setState(() => _momentSaved = true);
      showV2Snack(context, '기록으로 남겼어요');
    } catch (_) {
      if (mounted) {
        showV2Snack(context, '기록으로 남기지 못했어요', tone: V2Tone.err);
      }
    }
  }

  void _openHistory() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TwoAnswersHistoryScreen(repository: widget.repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return TwoAnswersRefresher(
      events: widget.events,
      onRefresh: _refresh,
      child: _scaffold(p),
    );
  }

  Widget _scaffold(V2Palette p) {
    return Scaffold(
      backgroundColor: p.bg,
      appBar: V2Header(
        title: '마주 열기',
        actions: [
          TextButton(onPressed: _openHistory, child: const Text('지난 카드')),
        ],
      ),
      body: SafeArea(child: _body(p)),
    );
  }

  Widget _body(V2Palette p) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final card = _card;
    if (_failed || card == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(V2Space.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('오늘의 질문을 불러오지 못했어요', style: V2Text.head),
              const SizedBox(height: V2Space.x4),
              V2Button(
                label: '다시 불러오기',
                variant: V2ButtonVariant.soft,
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(V2Space.page),
      children: [
        Row(
          children: [
            V2Chip(label: twoAnswerCategoryLabel(card.category)),
            const Spacer(),
            if (card.streak > 0)
              Text(
                '${card.streak}일 연속',
                key: const ValueKey('two-answers-streak'),
                style: V2Text.cap.copyWith(color: p.primary),
              ),
          ],
        ),
        const SizedBox(height: V2Space.x4),
        Text(
          V2Text.keepAll(card.question),
          key: const ValueKey('two-answers-question'),
          style: V2Text.title.copyWith(color: p.ink),
        ),
        const SizedBox(height: V2Space.x6),
        if (card.isOpen)
          TwoAnswersReveal(
            key: ValueKey('reveal-${card.id}'),
            mine: card.myBody ?? '',
            partner: card.partnerBody ?? '',
          )
        else
          ..._answerForm(card, p),
        if (card.isOpen) ...[
          const SizedBox(height: V2Space.x6),
          V2Button(
            label: _momentSaved ? '기록으로 남겼어요' : '우리의 기록으로 남기기',
            icon: V2Icons.record,
            variant: V2ButtonVariant.soft,
            onPressed: _momentSaved ? null : _saveMoment,
          ),
        ],
      ],
    );
  }

  List<Widget> _answerForm(TwoAnswerCard card, V2Palette p) {
    final waiting = card.status == TwoAnswerStatus.waiting;
    return [
      if (waiting)
        V2Banner(
          message: '상대가 답하면 봉인이 풀려요. 그때까지는 내 답을 고칠 수 있어요.',
          icon: V2Icons.lock,
        )
      else if (card.partnerAnswered)
        V2Banner(message: '상대가 먼저 답했어요. 나도 답하면 함께 열려요.', icon: V2Icons.heart),
      const SizedBox(height: V2Space.x4),
      V2TextField(
        label: '내 답변',
        controller: _text,
        maxLines: 5,
        maxLength: twoAnswersMaxLength,
        hint: '떠오르는 대로 적어 보세요',
        error: _error,
      ),
      const SizedBox(height: V2Space.x4),
      V2Button(
        label: waiting ? '답변 고치기' : '답변 보내기',
        loading: _saving,
        onPressed: _saving ? null : _submit,
      ),
    ];
  }
}

/// 봉인이 풀리는 짧은 연출. 끝난 뒤에만 상대 답변을 보여 준다.
/// 모션 줄이기 설정이면 연출 없이 바로 보여 준다.
class TwoAnswersReveal extends StatefulWidget {
  final String mine;
  final String partner;

  const TwoAnswersReveal({
    super.key,
    required this.mine,
    required this.partner,
  });

  @override
  State<TwoAnswersReveal> createState() => _TwoAnswersRevealState();
}

class _TwoAnswersRevealState extends State<TwoAnswersReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _opened = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _opened = true;
      return;
    }
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _opened = true);
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _opened
          ? Column(
              key: const ValueKey('two-answers-opened'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AnswerBlock(label: '내 답변', body: widget.mine, accent: false),
                const SizedBox(height: V2Space.x3),
                _AnswerBlock(
                  label: '상대 답변',
                  body: widget.partner,
                  accent: true,
                ),
              ],
            )
          : AnimatedBuilder(
              key: const ValueKey('two-answers-seal'),
              animation: _controller,
              builder: (context, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: V2Space.x8),
                  child: Transform.scale(
                    scale: 1 + _controller.value * 0.4,
                    child: Opacity(
                      opacity: 1 - _controller.value * 0.6,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(V2Icons.lock, size: 48, color: p.primary),
                          const SizedBox(height: V2Space.x3),
                          Text(
                            '봉인이 풀리고 있어요',
                            style: V2Text.bodyStrong.copyWith(color: p.ink),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _AnswerBlock extends StatelessWidget {
  final String label;
  final String body;
  final bool accent;

  const _AnswerBlock({
    required this.label,
    required this.body,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return V2Card(
      variant: accent ? V2CardVariant.soft : V2CardVariant.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: V2Text.cap.copyWith(color: p.sub)),
          const SizedBox(height: V2Space.x1),
          Text(body, style: V2Text.body.copyWith(color: p.ink)),
        ],
      ),
    );
  }
}
