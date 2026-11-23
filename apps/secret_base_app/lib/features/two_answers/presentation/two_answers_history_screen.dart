import 'package:flutter/material.dart';

import '../../../v2/v2.dart';
import '../data/two_answers_repository.dart';
import '../domain/two_answer.dart';

/// 함께 연 지난 카드와, 놓쳐서 나중에 답할 수 있는 질문.
/// 놓친 질문에는 벌점도 독촉 문구도 없다.
class TwoAnswersHistoryScreen extends StatefulWidget {
  final TwoAnswersRepository repository;

  const TwoAnswersHistoryScreen({super.key, required this.repository});

  @override
  State<TwoAnswersHistoryScreen> createState() =>
      _TwoAnswersHistoryScreenState();
}

class _TwoAnswersHistoryScreenState extends State<TwoAnswersHistoryScreen> {
  final List<TwoAnswerCard> _items = [];
  List<TwoAnswerCard> _missed = const [];
  int? _next;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await widget.repository.history();
      final missed = await widget.repository.missed();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _next = page.nextCursor;
        _missed = missed;
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

  Future<void> _more() async {
    final cursor = _next;
    if (cursor == null) return;
    try {
      final page = await widget.repository.history(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _next = page.nextCursor;
      });
    } catch (_) {
      if (mounted) showV2Snack(context, '더 불러오지 못했어요', tone: V2Tone.err);
    }
  }

  Future<void> _answerLate(TwoAnswerCard card) async {
    final text = await showV2Sheet<String>(
      context,
      title: '나중에 답하기',
      builder: (sheet) => _LateAnswerForm(question: card.question),
    );
    if (text == null || text.isEmpty) return;
    try {
      await widget.repository.answerLate(card.id, text);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        showV2Snack(context, '답변을 저장하지 못했어요', tone: V2Tone.err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      appBar: const V2Header(title: '지난 카드'),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _failed
            ? Center(
                child: V2Button(
                  label: '다시 불러오기',
                  variant: V2ButtonVariant.soft,
                  fullWidth: false,
                  onPressed: _load,
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(V2Space.page),
                children: [
                  if (_missed.isNotEmpty) ...[
                    Text('아직 답하지 않은 질문', style: V2Text.head),
                    const SizedBox(height: V2Space.x2),
                    for (final card in _missed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: V2Space.x2),
                        child: V2Card(
                          variant: V2CardVariant.soft,
                          onTap: () => _answerLate(card),
                          semanticLabel:
                              '${card.businessDate}, ${card.question}, 답하기',
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      card.businessDate,
                                      style: V2Text.cap.copyWith(color: p.sub),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(V2Text.keepAll(card.question)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: V2Space.x2),
                              Text(
                                '답하기',
                                style: V2Text.cap.copyWith(color: p.primary),
                              ),
                              Icon(V2Icons.chevron, color: p.sub, size: 20),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: V2Space.x4),
                  ],
                  Text('함께 연 카드', style: V2Text.head),
                  const SizedBox(height: V2Space.x2),
                  if (_items.isEmpty)
                    Text(
                      '둘 다 답한 질문이 여기에 쌓여요',
                      style: V2Text.cap.copyWith(color: p.sub),
                    ),
                  for (final card in _items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: V2Space.x3),
                      child: V2Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${card.businessDate} · ${twoAnswerCategoryLabel(card.category)}',
                              style: V2Text.cap.copyWith(color: p.sub),
                            ),
                            const SizedBox(height: V2Space.x1),
                            Text(
                              V2Text.keepAll(card.question),
                              style: V2Text.bodyStrong,
                            ),
                            const SizedBox(height: V2Space.x2),
                            Text('나  ${card.myBody ?? ''}'),
                            const SizedBox(height: 2),
                            Text('상대  ${card.partnerBody ?? ''}'),
                          ],
                        ),
                      ),
                    ),
                  if (_next != null)
                    V2Button(
                      label: '더 보기',
                      variant: V2ButtonVariant.text,
                      onPressed: _more,
                    ),
                ],
              ),
      ),
    );
  }
}

class _LateAnswerForm extends StatefulWidget {
  final String question;

  const _LateAnswerForm({required this.question});

  @override
  State<_LateAnswerForm> createState() => _LateAnswerFormState();
}

class _LateAnswerFormState extends State<_LateAnswerForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(V2Text.keepAll(widget.question), style: V2Text.bodyStrong),
        const SizedBox(height: V2Space.x3),
        V2TextField(
          label: '내 답변',
          controller: _controller,
          maxLines: 4,
          maxLength: 500,
        ),
        const SizedBox(height: V2Space.x3),
        V2Button(
          label: '답변 보내기',
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        ),
      ],
    );
  }
}
