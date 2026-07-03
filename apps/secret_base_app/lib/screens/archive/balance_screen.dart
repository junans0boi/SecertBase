import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/auth_service.dart';
import '../../core/main_design.dart';

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  final _auth = AuthService();
  Map<String, dynamic>? _question;
  Map<String, dynamic>? _status;
  List<Map<String, dynamic>> _answers = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${_auth.baseUrl}/api/balance/today?user_id=$uid'),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] == true && mounted) {
        setState(() {
          _question = data['question'] == null
              ? null
              : Map<String, dynamic>.from(data['question'] as Map);
          _status = data['status'] == null
              ? null
              : Map<String, dynamic>.from(data['status'] as Map);
          _answers = (data['answers'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _answer(String choice) async {
    final uid = _auth.user?['UserId'] ?? _auth.user?['id'];
    final qid = _question?['id'];
    if (uid == null || qid == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await http.post(
        Uri.parse('${_auth.baseUrl}/api/balance/answer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': uid,
          'question_id': qid,
          'choice': choice,
        }),
      );
      await _load();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reveal = _status?['revealAvailable'] == true;
    final matched = _status?['matched'] == true;
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        foregroundColor: kMainInk,
        title: Text(
          '커플 밸런스',
          style: mainBody(size: 17, color: kMainInk, weight: FontWeight.w800),
        ),
      ),
      body: CozyPage(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                  children: [
                    MainCard(
                      gradient: kSkyGrad,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '오늘의 밸런스',
                            style: mainTitle(size: 28, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '둘 다 골라야 결과가 열려요',
                            style: mainBody(
                              size: 14,
                              color: Colors.white.withAlpha(220),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _choiceCard(
                            'A',
                            '${_question?['optionA'] ?? '-'}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _choiceCard(
                            'B',
                            '${_question?['optionB'] ?? '-'}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_status?['myAnswered'] == true && !reveal)
                      MainCard(
                        child: Text(
                          '상대가 고르면 결과가 열려요',
                          style: mainBody(size: 14, color: kMainSub),
                        ),
                      ),
                    if (reveal)
                      MainCard(
                        color: matched ? kMainSageSoft : kMainRoseSoft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              matched ? '오늘은 마음이 통했어요' : '오늘은 취향이 갈렸어요',
                              style: mainTitle(
                                size: 24,
                                color: matched ? kMainSage : kMainRose,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ..._answers.map((answer) {
                              final name =
                                  answer['Nickname'] ??
                                  answer['UserName'] ??
                                  '상대';
                              final choice = answer['choice'] == 'A'
                                  ? (_question?['optionA'] ?? '')
                                  : (_question?['optionB'] ?? '');
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Text(
                                  '$name: $choice',
                                  style: mainBody(size: 14, color: kMainInk),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _choiceCard(String choice, String label) {
    final selected = _answers.any((answer) {
      final myId = '${_auth.user?['UserId'] ?? _auth.user?['id']}';
      return '${answer['user_id']}' == myId && answer['choice'] == choice;
    });
    return GestureDetector(
      onTap: _submitting ? null : () => _answer(choice),
      child: MainCard(
        color: selected ? kMainSkySoft : kMainPaper,
        borderColor: selected ? kMainSky : kMainLine,
        child: SizedBox(
          height: 110,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: mainBody(
                size: 18,
                color: kMainInk,
                weight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
