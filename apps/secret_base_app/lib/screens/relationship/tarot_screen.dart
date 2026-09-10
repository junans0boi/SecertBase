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
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
              children: [
                Text('나의 타로', style: mainTitle(size: 27)),
                const SizedBox(height: 6),
                Text(
                  '마음이 끌리는 카드 한 장을 직접 골라 오늘의 질문으로 받아들여봐요.',
                  style: mainBody(size: 13, color: kMainSub),
                ),
                const SizedBox(height: 18),
                if (_today!.personal != null)
                  _readingSection(_today!.personal!),
                if (_today!.relationship != null) ...[
                  const SizedBox(height: 14),
                  Text('우리의 관계 타로', style: mainTitle(size: 22)),
                  const SizedBox(height: 8),
                  _readingSection(_today!.relationship!),
                ],
                const SizedBox(height: 14),
                Text(
                  '하루 한 장만 고를 수 있고, 선택한 카드는 오늘의 카드로 잠겨요.',
                  textAlign: TextAlign.center,
                  style: mainBody(size: 12, color: kMainMuted),
                ),
              ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reading.scope == 'couple' ? '우리의 카드를 골라주세요' : '나의 카드를 골라주세요',
            style: mainBody(weight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '마음 가는 카드 한 장을 골라주세요. 고른 뒤에는 오늘 하루 동안 바뀌지 않아요.',
            key: Key('tarot_${reading.scope}_pick_help'),
            style: mainBody(size: 13, color: kMainSub, height: 1.5),
          ),
          const SizedBox(height: 14),
          if (busy)
            const Center(child: CircularProgressIndicator(color: kMainLilac))
          else
            GridView.builder(
              key: Key('tarot_${reading.scope}_deck'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reading.cards.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final choice = reading.cards[index];
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
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [Color(0xff7667c9), Color(0xffb69be5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '✦\n${choice.position.toString().padLeft(2, '0')}',
                            textAlign: TextAlign.center,
                            style: mainBody(
                              size: 15,
                              color: Colors.white,
                              weight: FontWeight.w800,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _card(TarotReading reading, {required Key key}) {
    final card = reading.card!;
    return MainCard(
      key: key,
      gradient: kRoseGrad,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reading.scope == 'couple' ? '우리의 카드' : '나의 카드',
            style: mainBody(size: 12, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(card.title, style: mainTitle(size: 29, color: Colors.white)),
          const SizedBox(height: 4),
          Text('정방향', style: mainBody(size: 12, color: Colors.white)),
          const SizedBox(height: 14),
          Text(
            card.plain,
            style: mainBody(size: 14, color: Colors.white, height: 1.5),
          ),
          const SizedBox(height: 12),
          Text(
            card.reflection,
            style: mainBody(size: 13, color: Colors.white, height: 1.5),
          ),
        ],
      ),
    );
  }

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
