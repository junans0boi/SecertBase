import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/main_design.dart';
import '../../core/tarot_api.dart';

class TarotScreen extends StatefulWidget {
  final TarotApi? api;

  const TarotScreen({super.key, this.api});

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

  Future<void> _draw(TarotReading reading, TarotDeckCard choice) async {
    setState(() {
      _drawingScope = reading.scope;
      _error = null;
    });
    try {
      final today = await _api.drawToday(
        scope: reading.scope,
        cardKey: choice.key,
      );
      if (!mounted) return;
      setState(() {
        _today = today;
        _drawingScope = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _drawingScope = null;
        _error = error is TarotApiException
            ? error
            : const TarotApiException('unknown_error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        title: Text('오늘의 타로', style: mainTitle(size: 22)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainLilac))
          : _today == null
          ? _errorState()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _today!.date,
                    style: mainBody(
                      size: 12,
                      color: kMainSub,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text('오늘의 한 장', style: mainTitle(size: 30)),
                  const SizedBox(height: 5),
                  Text(
                    '카드가 답을 정해주기보다, 지금의 마음을 바라볼 질문을 건네요.',
                    style: mainBody(size: 13, color: kMainSub, height: 1.55),
                  ),
                  if (_today!.catalogVersion.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '메이저 아르카나 22장 · ${_today!.catalogVersion}',
                      style: mainBody(size: 11, color: kMainMuted),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text('나의 타로', style: mainTitle(size: 25)),
                  const SizedBox(height: 8),
                  if (_today!.personal != null)
                    _readingSection(_today!.personal!),
                  if (_today!.relationship != null) ...[
                    const SizedBox(height: 28),
                    Text('우리의 관계 타로', style: mainTitle(size: 23)),
                    const SizedBox(height: 8),
                    _readingSection(_today!.relationship!),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    '하루 한 장만 고를 수 있고, 선택한 카드는 오늘 하루 동안 바뀌지 않아요.',
                    textAlign: TextAlign.center,
                    style: mainBody(size: 12, color: kMainMuted),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _readingSection(TarotReading reading) {
    if (!reading.drawn || reading.card == null) {
      return _pickCard(reading);
    }
    return _card(reading, key: Key('tarot_${reading.scope}_card'));
  }

  Widget _pickCard(TarotReading reading) {
    final busy = _drawingScope == reading.scope;
    return MainCard(
      key: Key('tarot_${reading.scope}_picker'),
      color: kMainPaper,
      padding: const EdgeInsets.fromLTRB(14, 17, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reading.scope == 'couple' ? '우리의 마음이 끌리는 한 장' : '마음이 끌리는 한 장',
            style: mainBody(size: 16, color: kMainInk, weight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            '카드 뭉치에서 한 장을 골라 오늘의 질문을 받아보세요.',
            key: Key('tarot_${reading.scope}_pick_help'),
            style: mainBody(size: 13, color: kMainSub, height: 1.5),
          ),
          const SizedBox(height: 12),
          if (busy)
            const SizedBox(
              height: 238,
              child: Center(
                child: CircularProgressIndicator(color: kMainLilac),
              ),
            )
          else
            _fanDeck(reading),
          const SizedBox(height: 2),
          Center(
            child: Text(
              '카드를 눌러 한 장 뽑기',
              style: mainBody(
                size: 12,
                color: kMainLilac,
                weight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fanDeck(TarotReading reading) {
    final count = reading.cards.length;
    if (count == 0) {
      return const SizedBox(height: 238);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = (width * 0.14).clamp(44.0, 52.0).toDouble();
        final cardHeight = cardWidth * 1.42;
        final step = count == 1 ? 0.0 : (width - cardWidth) / (count - 1);
        final startLeft = count == 1 ? (width - cardWidth) / 2 : 0.0;
        return SizedBox(
          key: Key('tarot_${reading.scope}_arc_deck'),
          height: 238,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 8,
                right: 8,
                bottom: 7,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: kMainLilacSoft,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              ...reading.cards.asMap().entries.map((entry) {
                final index = entry.key;
                final choice = entry.value;
                final progress = count == 1 ? 0.0 : index / (count - 1);
                final curve = (progress * 2) - 1;
                final angle = curve * 0.78;
                final top = 20 + curve.abs() * 67;
                return Positioned(
                  left: startLeft + step * index,
                  top: top,
                  child: Transform.rotate(
                    angle: angle,
                    alignment: Alignment.bottomCenter,
                    child: _faceDownCard(
                      reading: reading,
                      choice: choice,
                      width: cardWidth,
                      height: cardHeight,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _faceDownCard({
    required TarotReading reading,
    required TarotDeckCard choice,
    required double width,
    required double height,
  }) {
    return Semantics(
      button: true,
      label: '타로 카드 ${choice.position}번 선택',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('tarot_pick_${reading.scope}_${choice.key}'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => _draw(reading, choice),
          child: Ink(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xff514382), Color(0xff9e83d3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withAlpha(170),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withAlpha(110)),
                ),
                child: Center(
                  child: Text(
                    '✦\n${choice.position.toString().padLeft(2, '0')}',
                    textAlign: TextAlign.center,
                    style: mainBody(
                      size: 12,
                      color: Colors.white,
                      weight: FontWeight.w800,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(TarotReading reading, {required Key key}) {
    final card = reading.card!;
    final isCouple = reading.scope == 'couple';
    return MainCard(
      key: key,
      color: kMainPaper,
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardArtwork(card),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCouple ? '우리의 오늘의 카드' : '나의 오늘의 카드',
                      style: mainBody(
                        size: 12,
                        color: kMainLilac,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(card.title, style: mainTitle(size: 29)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: kMainLilacSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '정방향 · 오늘의 메시지',
                        style: mainBody(
                          size: 11,
                          color: kMainLilac,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: kMainLine, height: 1),
          const SizedBox(height: 16),
          Text(
            '핵심 메시지',
            style: mainBody(size: 12, color: kMainSub, weight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          KeyedSubtree(
            key: Key('tarot_${reading.scope}_result_message'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              decoration: BoxDecoration(
                color: kMainRoseSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                card.plain,
                style: mainBody(
                  size: 15,
                  color: kMainInk,
                  height: 1.6,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '오늘의 질문',
            style: mainBody(size: 12, color: kMainSub, weight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          KeyedSubtree(
            key: Key('tarot_${reading.scope}_result_question'),
            child: Text(
              card.reflection,
              style: mainBody(size: 14, color: kMainInk, height: 1.6),
            ),
          ),
          const SizedBox(height: 13),
          Text(
            reading.disclaimer,
            style: mainBody(size: 11, color: kMainMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _cardArtwork(TarotCard card) {
    return Container(
      width: 76,
      height: 106,
      decoration: BoxDecoration(
        gradient: kRoseGrad,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: kMainRose.withAlpha(45),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_symbolFor(card.key), size: 34, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            'MAJOR ARCANA',
            textAlign: TextAlign.center,
            style: mainBody(
              size: 7,
              color: Colors.white,
              weight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  IconData _symbolFor(String key) => switch (key) {
    'the_fool' => Icons.explore_outlined,
    'the_magician' => Icons.auto_fix_high_outlined,
    'the_high_priestess' => Icons.nightlight_outlined,
    'the_empress' => Icons.spa_outlined,
    'the_emperor' => Icons.shield_outlined,
    'the_hierophant' => Icons.menu_book_outlined,
    'the_lovers' => Icons.favorite_border,
    'the_chariot' => Icons.navigation_outlined,
    'strength' => Icons.favorite_rounded,
    'the_hermit' => Icons.lightbulb_outline,
    'wheel_of_fortune' => Icons.sync,
    'justice' => Icons.balance,
    'the_hanged_man' => Icons.flip_camera_android_outlined,
    'death' => Icons.restart_alt,
    'temperance' => Icons.water_drop_outlined,
    'the_devil' => Icons.link_outlined,
    'the_tower' => Icons.flash_on_outlined,
    'the_star' => Icons.star_outline,
    'the_moon' => Icons.dark_mode_outlined,
    'the_sun' => Icons.wb_sunny_outlined,
    'judgement' => Icons.campaign_outlined,
    'the_world' => Icons.public_outlined,
    _ => Icons.auto_awesome,
  };

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: MainCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: kMainSub, size: 34),
            const SizedBox(height: 10),
            Text(
              _error?.reason == 'network_error'
                  ? '네트워크 연결을 확인하고 다시 시도해주세요.'
                  : '오늘의 타로를 불러오지 못했어요.',
              textAlign: TextAlign.center,
              style: mainBody(size: 14, height: 1.5),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      ),
    ),
  );
}
