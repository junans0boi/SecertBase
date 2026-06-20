import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/app_theme.dart';
import '../../core/auth_service.dart';
import '../../core/main_design.dart';

class QaScreen extends StatefulWidget {
  const QaScreen({super.key});

  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen> {
  final _auth = AuthService();
  final _answerCtrl = TextEditingController();

  Map<String, dynamic>? _question;
  List<Map<String, dynamic>> _answers = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(Uri.parse('${_auth.baseUrl}/api/qa/today'));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] == true) {
        setState(() {
          _question = data['question'] as Map<String, dynamic>?;
          _answers = (data['answers'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];
        });
      }
    } catch (_) {
      setState(() => _error = '불러오기 실패');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final text = _answerCtrl.text.trim();
    if (text.isEmpty || _question == null) return;
    final uid = _auth.user?['UserId'];
    if (uid == null) return;

    setState(() => _submitting = true);
    try {
      final res = await http.post(
        Uri.parse('${_auth.baseUrl}/api/qa/answer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'question_id': _question!['id'],
          'user_id': uid,
          'answer': text,
        }),
      );
      if (res.statusCode == 200) {
        _answerCtrl.clear();
        await _load();
      }
    } catch (_) {
      setState(() => _error = '제출 실패');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool get _myAnswered {
    final myId = _auth.user?['UserId']?.toString();
    return _answers.any((a) => a['user_id']?.toString() == myId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        foregroundColor: kMainInk,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('❓ 오늘의 질문', style: mainBody(size: 17, color: kMainInk, weight: FontWeight.w700)),
        elevation: 0,
      ),
      body: CozyPage(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                color: kMainHoney,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _questionCard(),
                      const SizedBox(height: 20),
                      if (!_myAnswered) _answerInput(),
                      if (_answers.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('답변', style: mainBody(size: 14, color: kMainSub, weight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        ..._answers.map(_answerCard),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: mainBody(size: 13, color: kError)),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _questionCard() {
    if (_question == null) {
      return MainCard(
        color: kMainHoneySoft,
        borderColor: kMainHoney.withAlpha(100),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text('오늘의 질문이 없어요', style: mainBody(size: 15, color: kMainSub)),
          ),
        ),
      );
    }
    return MainCard(
      color: kMainHoneySoft,
      borderColor: kMainHoney.withAlpha(120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('오늘의 질문', style: mainBody(size: 12, color: kMainHoney, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
            _question!['question'] ?? '',
            style: mainTitle(size: 22, color: kMainInk),
          ),
        ],
      ),
    );
  }

  Widget _answerInput() {
    return MainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('내 답변', style: mainBody(size: 13, color: kMainSub, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          TextField(
            controller: _answerCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '솔직하게 적어봐요 :)',
              hintStyle: mainBody(size: 14, color: kMainMuted),
              filled: true,
              fillColor: kMainPaperSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
            style: mainBody(size: 14, color: kMainInk),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: kMainHoney,
                foregroundColor: kMainInk,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('답변 제출', style: mainBody(size: 15, color: kMainInk, weight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _answerCard(Map<String, dynamic> answer) {
    final myId = _auth.user?['UserId']?.toString();
    final isMe = answer['user_id']?.toString() == myId;
    final userName = isMe ? (_auth.user?['UserName'] ?? '나') : (answer['UserName'] ?? '상대방');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MainCard(
        color: isMe ? kMainSageSoft : kMainSkySoft,
        borderColor: (isMe ? kMainSage : kMainSky).withAlpha(100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMe ? '나 ($userName)' : userName,
              style: mainBody(
                size: 12,
                color: isMe ? kMainSage : kMainSky,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(answer['answer'] ?? '', style: mainBody(size: 14, color: kMainInk, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
