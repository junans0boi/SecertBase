import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:secret_base_app/v2/v2.dart';

import '../../core/auth_service.dart';
import '../../core/tarot_api.dart';
import 'relationship_common.dart';
import 'share_card.dart';
import 'widgets/tarot_card_art.dart';

class TarotScreen extends StatefulWidget {
  final TarotApi? api;
  final bool relationshipFirst;
  final VoidCallback? onOpenPartner;

  const TarotScreen({
    super.key,
    this.api,
    this.relationshipFirst = false,
    this.onOpenPartner,
  });

  @override
  State<TarotScreen> createState() => _TarotScreenState();
}

class _TarotScreenState extends State<TarotScreen> {
  late final TarotApi _api;
  late final bool _ownsApi;
  TarotToday? _today;
  TarotApiException? _error;
  bool _loading = true;
  String? _drawingScope;
  String? _drawError;
  late String _scope = widget.relationshipFirst ? 'couple' : 'user';
  final Map<String, String> _selected = {};
  final Set<String> _justDrawn = {};

  @override
  void initState() {
    super.initState();
    _ownsApi = widget.api == null;
    final auth = AuthService();
    _api =
        widget.api ?? TarotApi(baseUrl: auth.baseUrl, token: auth.token ?? '');
    _load();
  }

  @override
  void dispose() {
    if (_ownsApi) _api.close();
    super.dispose();
  }

  void _openPartner() =>
      (widget.onOpenPartner ?? () => openPartnerConnection(context))();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final today = await _api.fetchToday();
      if (!mounted) return;
      setState(() {
        _today = today;
        _loading = false;
        if (_scope == 'couple' && today.relationship == null) _scope = 'user';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is TarotApiException
            ? error
            : const TarotApiException('unknown_error');
        _loading = false;
      });
    }
  }

  Future<void> _draw(TarotReading reading) async {
    final key = _selected[reading.scope];
    if (key == null || _drawingScope != null) return;
    setState(() {
      _drawingScope = reading.scope;
      _drawError = null;
    });
    try {
      final today = await _api.drawToday(scope: reading.scope, cardKey: key);
      if (!mounted) return;
      setState(() {
        _today = today;
        _drawingScope = null;
        _justDrawn.add(reading.scope);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _drawingScope = null;
        _drawError =
            error is TarotApiException && error.reason == 'network_error'
            ? '네트워크 연결을 확인하고 다시 시도해 주세요. 고른 카드는 그대로예요.'
            : '카드를 뒤집지 못했어요. 다시 시도해 주세요.';
      });
    }
  }

  TarotReading? get _reading =>
      _scope == 'couple' ? _today?.relationship : _today?.personal;

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Scaffold(
        appBar: V2Header(
          title: widget.relationshipFirst ? '우리의 관계 타로' : '오늘의 타로',
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(V2Space.page),
        child: V2SkeletonList(count: 2),
      );
    }
    final today = _today;
    if (today == null) return _errorState();
    final reading = _reading;
    final hasCouple = today.relationship != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(V2Space.page, 4, V2Space.page, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(today.date, style: V2Text.cap),
              const SizedBox(height: 4),
              Text(
                _scope == 'couple' ? '우리의 오늘의 한 장' : '오늘의 한 장',
                style: V2Text.title,
              ),
              const SizedBox(height: 4),
              Text('카드가 답을 정해 주기보다, 지금의 마음을 바라볼 질문을 건네요.', style: V2Text.cap),
              const SizedBox(height: 14),
              if (hasCouple)
                V2Segmented<String>(
                  segments: const [
                    V2Segment(value: 'user', label: '나'),
                    V2Segment(value: 'couple', label: '우리'),
                  ],
                  selected: _scope,
                  onChanged: (v) => setState(() => _scope = v),
                ),
              const SizedBox(height: 18),
              if (reading == null)
                V2Card(
                  key: const Key('tarot_missing_reading'),
                  variant: V2CardVariant.soft,
                  child: Text('타로를 준비하지 못했어요. 다시 시도해 주세요.', style: V2Text.body),
                )
              else if (!reading.drawn || reading.card == null)
                _picker(reading)
              else
                _TarotResult(
                  key: Key('tarot_${reading.scope}_card'),
                  reading: reading,
                  flip: _justDrawn.contains(reading.scope),
                ),
              if (!hasCouple) ...[
                const SizedBox(height: 20),
                V2Card(
                  variant: V2CardVariant.soft,
                  child: Row(
                    children: [
                      const V2Art(icon: V2Icons.couple, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('우리의 타로도 뽑아 볼까요?', style: V2Text.bodyStrong),
                            const SizedBox(height: 2),
                            Text(
                              '파트너와 연결하면 둘을 위한 한 장이 열려요.',
                              style: V2Text.cap,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                V2Button(
                  label: '파트너 연결하기',
                  variant: V2ButtonVariant.soft,
                  onPressed: _openPartner,
                ),
              ],
              const SizedBox(height: 20),
              Text(
                '하루에 한 장만 고를 수 있고, 고른 카드는 오늘 하루 바뀌지 않아요.',
                textAlign: TextAlign.center,
                style: V2Text.cap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _picker(TarotReading reading) {
    final busy = _drawingScope == reading.scope;
    final selected = _selected[reading.scope];
    final p = V2Palette.of(context);
    return Column(
      key: Key('tarot_${reading.scope}_picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          reading.scope == 'couple' ? '우리의 마음이 끌리는 한 장' : '마음이 끌리는 한 장',
          style: V2Text.head,
        ),
        const SizedBox(height: 4),
        Text(
          '카드 뭉치를 옆으로 넘기며 한 장을 골라 보세요.',
          key: Key('tarot_${reading.scope}_pick_help'),
          style: V2Text.cap,
        ),
        const SizedBox(height: 14),
        if (reading.cards.isEmpty)
          V2Card(
            key: Key('tarot_${reading.scope}_empty_deck'),
            variant: V2CardVariant.soft,
            child: Text(
              '오늘 고를 수 있는 카드가 아직 없어요. 잠시 뒤 다시 와 주세요.',
              style: V2Text.body,
            ),
          )
        else
          SizedBox(
            height: 232,
            child: ListView.separated(
              key: Key('tarot_${reading.scope}_card_strip'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              itemCount: reading.cards.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final deckCard = reading.cards[i];
                final isSel = selected == deckCard.key;
                return Semantics(
                  button: true,
                  selected: isSel,
                  label: '${i + 1}번째 카드${isSel ? ', 선택됨' : ''}',
                  onTap: busy
                      ? null
                      : () => setState(
                          () => _selected[reading.scope] = deckCard.key,
                        ),
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      key: Key('tarot_pick_${reading.scope}_${deckCard.key}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: busy
                          ? null
                          : () => setState(
                              () => _selected[reading.scope] = deckCard.key,
                            ),
                      child: AnimatedContainer(
                        duration: V2Motion.of(context, V2Motion.base),
                        transform: Matrix4.translationValues(
                          0,
                          isSel ? -10 : 0,
                          0,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? p.primary : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSel ? V2Shadow.level2 : V2Shadow.level1,
                        ),
                        child: const TarotCardBack(
                          width: 112,
                          excludeSemantics: true,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (_drawError != null) ...[
          const SizedBox(height: 8),
          V2Banner(tone: V2BannerTone.err, message: _drawError!),
        ],
        const SizedBox(height: 14),
        V2Button(
          label: selected == null ? '카드를 한 장 골라 주세요' : '이 카드 뒤집기',
          loading: busy,
          onPressed: selected == null || busy ? null : () => _draw(reading),
        ),
      ],
    );
  }

  Widget _errorState() {
    final needsPartner = _error?.reason == 'active_couple_required';
    return Column(
      children: [
        Expanded(
          child: _error?.reason == 'network_error'
              ? V2ErrorState.offline(onRetry: _load)
              : V2ErrorState(title: '오늘의 타로를 불러오지 못했어요', onRetry: _load),
        ),
        if (needsPartner)
          Padding(
            padding: const EdgeInsets.all(V2Space.page),
            child: V2Button(
              label: '파트너 연결하기',
              variant: V2ButtonVariant.soft,
              onPressed: _openPartner,
            ),
          ),
      ],
    );
  }
}

/// The drawn card: flips from back to face once (skipped for reduced motion
/// and for cards drawn earlier today), then the reading.
class _TarotResult extends StatefulWidget {
  const _TarotResult({super.key, required this.reading, required this.flip});

  final TarotReading reading;
  final bool flip;

  @override
  State<_TarotResult> createState() => _TarotResultState();
}

class _TarotResultState extends State<_TarotResult>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final d = V2Motion.of(context, const Duration(milliseconds: 700));
    _c.duration = d;
    if (widget.flip && d > Duration.zero) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _share(TarotCard card) {
    showShareCardSheet(
      context,
      fileName: 'secretbase-tarot.png',
      caption: '오늘의 타로 · ${card.title}\n${card.plain}\n- 비밀기지',
      card: ShareCard(
        kind: '오늘의 타로',
        title: card.title,
        line: card.reflection.isNotEmpty ? card.reflection : card.plain,
        gradient: V2Gradients.berry,
        art: TarotCardFace(cardKey: card.key, title: card.title, width: 92),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reading = widget.reading;
    final card = reading.card!;
    final isCouple = reading.scope == 'couple';
    final info = tarotCardInfo(card.key);
    final p = V2Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: V2Chip(
            label: isCouple ? '우리 둘의 관계 카드' : '나만 보는 카드',
            tone: isCouple ? V2Tone.lilac : V2Tone.rose,
            icon: isCouple ? V2Icons.couple : V2Icons.person,
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_c.value);
              final angle = t * math.pi;
              final showFront = t >= 0.5;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(showFront ? angle - math.pi : angle),
                child: showFront
                    ? DecoratedBox(
                        decoration: BoxDecoration(boxShadow: V2Shadow.level2),
                        child: TarotCardFace(
                          cardKey: card.key,
                          title: card.title,
                          width: 168,
                        ),
                      )
                    : const TarotCardBack(width: 168),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isCouple ? '우리의 오늘의 카드' : '나의 오늘의 카드',
          textAlign: TextAlign.center,
          style: V2Text.label.copyWith(color: p.primary, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(
          card.title,
          textAlign: TextAlign.center,
          style: V2Text.serif(size: 30, color: p.ink),
        ),
        if (info != null) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final k in info.keywords)
                V2Chip(label: k, tone: V2Tone.lilac),
            ],
          ),
        ],
        const SizedBox(height: 18),
        Text('핵심 메시지', style: V2Text.cap),
        const SizedBox(height: 6),
        KeyedSubtree(
          key: Key('tarot_${reading.scope}_result_message'),
          child: V2Card(
            color: p.primarySoft,
            child: Text(
              card.plain,
              style: V2Text.body.copyWith(color: p.onPrimarySoft),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('오늘의 질문', style: V2Text.cap),
        const SizedBox(height: 6),
        KeyedSubtree(
          key: Key('tarot_${reading.scope}_result_question'),
          child: Text(card.reflection, style: V2Text.body),
        ),
        if (!widget.flip) ...[
          const SizedBox(height: 14),
          const V2Chip(
            label: '오늘 이미 뽑은 카드예요',
            tone: V2Tone.neutral,
            icon: V2Icons.check,
          ),
        ],
        const SizedBox(height: 16),
        V2Button(
          label: '카드로 공유',
          icon: V2Icons.share,
          variant: V2ButtonVariant.soft,
          onPressed: () => _share(card),
        ),
        if (reading.disclaimer.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(reading.disclaimer, style: V2Text.cap),
        ],
      ],
    );
  }
}
