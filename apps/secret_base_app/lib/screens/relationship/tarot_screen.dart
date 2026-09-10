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
                  '카드는 오늘 하루의 자기 성찰을 돕는 작은 질문이에요.',
                  style: mainBody(size: 13, color: kMainSub),
                ),
                const SizedBox(height: 18),
                if (_today!.personal != null)
                  _card(
                    _today!.personal!,
                    key: const Key('tarot_personal_card'),
                  ),
                if (_today!.relationship != null) ...[
                  const SizedBox(height: 14),
                  Text('우리의 관계 타로', style: mainTitle(size: 22)),
                  const SizedBox(height: 8),
                  _card(
                    _today!.relationship!,
                    key: const Key('tarot_relationship_card'),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  '하루 한 장만 제공하며 오늘은 다시 뽑을 수 없어요.',
                  textAlign: TextAlign.center,
                  style: mainBody(size: 12, color: kMainMuted),
                ),
              ],
            ),
    );
  }

  Widget _card(TarotReading reading, {required Key key}) {
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
          Text(
            reading.card.title,
            style: mainTitle(size: 29, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text('정방향', style: mainBody(size: 12, color: Colors.white)),
          const SizedBox(height: 14),
          Text(
            reading.card.plain,
            style: mainBody(size: 14, color: Colors.white, height: 1.5),
          ),
          const SizedBox(height: 12),
          Text(
            reading.card.reflection,
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
