import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/auth_service.dart';
import '../../core/main_design.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  final _auth = AuthService();
  List<Map<String, dynamic>> _challenges = [];
  bool _loading = true;


  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final res = await http.get(Uri.parse('${_auth.baseUrl}/api/challenges'));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] == true) {
        setState(() {
          _challenges = (data['challenges'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];
        });
      }
    } catch (_) {
      debugPrint('challenge load error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final unitCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kMainPaper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('새 챌린지', style: mainTitle(size: 22)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(titleCtrl, '챌린지 이름', '예: 벤치프레스 100kg'),
              const SizedBox(height: 10),
              _dialogField(descCtrl, '설명 (선택)', '예: 3개월 안에 달성하기'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _dialogField(targetCtrl, '목표 수치', '100', numeric: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _dialogField(unitCtrl, '단위', 'kg')),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: mainBody(size: 14, color: kMainMuted)),
          ),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || targetCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await _createChallenge(
                title: titleCtrl.text.trim(),
                description: descCtrl.text.trim(),
                targetValue: double.tryParse(targetCtrl.text.trim()) ?? 1,
                unit: unitCtrl.text.trim(),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: kMainSky,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('만들기', style: mainBody(size: 14, color: Colors.white, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  TextField _dialogField(TextEditingController ctrl, String label, String hint,
      {bool numeric = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: kMainPaperSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        labelStyle: mainBody(size: 12, color: kMainMuted),
        hintStyle: mainBody(size: 13, color: kMainMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      style: mainBody(size: 14, color: kMainInk),
    );
  }

  Future<void> _createChallenge({
    required String title,
    required String description,
    required double targetValue,
    required String unit,
  }) async {
    final uid = _auth.user?['UserId'];
    if (uid == null) return;
    final today = DateTime.now().toIso8601String().split('T')[0];
    try {
      await http.post(
        Uri.parse('${_auth.baseUrl}/api/challenges'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'description': description.isNotEmpty ? description : null,
          'target_value': targetValue,
          'unit': unit.isNotEmpty ? unit : null,
          'owner_id': uid,
          'start_date': today,
        }),
      );
      await _load();
    } catch (_) {}
  }

  void _showLogDialog(Map<String, dynamic> challenge) {
    final valueCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final unit = challenge['unit'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kMainPaper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('진행 기록', style: mainTitle(size: 22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(challenge['title'] ?? '', style: mainBody(size: 14, color: kMainSub)),
            const SizedBox(height: 12),
            _dialogField(valueCtrl, '추가할 수치${unit.isNotEmpty ? " ($unit)" : ""}', '0', numeric: true),
            const SizedBox(height: 10),
            _dialogField(noteCtrl, '메모 (선택)', ''),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: mainBody(size: 14, color: kMainMuted)),
          ),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(valueCtrl.text.trim());
              if (v == null || v <= 0) return;
              Navigator.pop(ctx);
              await _logProgress(challenge['id'], v, noteCtrl.text.trim());
            },
            style: FilledButton.styleFrom(
              backgroundColor: kMainSage,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('기록', style: mainBody(size: 14, color: Colors.white, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _logProgress(dynamic id, double value, String note) async {
    try {
      await http.post(
        Uri.parse('${_auth.baseUrl}/api/challenges/$id/log'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'value': value, 'note': note.isNotEmpty ? note : null}),
      );
      await _load();
    } catch (_) {}
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
        title: Text('🏆 목표 챌린지', style: mainBody(size: 17, color: kMainInk, weight: FontWeight.w700)),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: kMainSky,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: CozyPage(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                color: kMainSky,
                child: _challenges.isEmpty
                    ? _empty()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
                        itemCount: _challenges.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _challengeCard(_challenges[i]),
                      ),
              ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🏆', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('아직 챌린지가 없어요', style: mainTitle(size: 22)),
          const SizedBox(height: 6),
          Text('+ 버튼으로 첫 번째 목표를 만들어보세요', style: mainBody(size: 13)),
        ],
      ),
    );
  }

  Widget _challengeCard(Map<String, dynamic> c) {
    final current = (c['current_value'] as num?)?.toDouble() ?? 0;
    final target = (c['target_value'] as num?)?.toDouble() ?? 1;
    final progress = (current / target).clamp(0.0, 1.0);
    final isCompleted = c['status'] == 'completed';
    final unit = c['unit'] ?? '';

    return GestureDetector(
      onTap: isCompleted ? null : () => _showLogDialog(c),
      child: MainCard(
        color: isCompleted ? kMainSageSoft : kMainPaper,
        borderColor: isCompleted ? kMainSage.withAlpha(100) : kMainLine,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c['title'] ?? '',
                    style: mainBody(size: 16, color: kMainInk, weight: FontWeight.w800),
                  ),
                ),
                if (isCompleted) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kMainSage,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('완료 ✓', style: mainBody(size: 11, color: Colors.white, weight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
            if ((c['description'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(c['description'], style: mainBody(size: 12, color: kMainMuted)),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${current.toStringAsFixed(current % 1 == 0 ? 0 : 1)} / ${target.toStringAsFixed(target % 1 == 0 ? 0 : 1)}${unit.isNotEmpty ? ' $unit' : ''}',
                  style: mainBody(size: 13, color: kMainSub, weight: FontWeight.w700),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: mainBody(size: 13, color: kMainSky, weight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: kMainLine,
                valueColor: AlwaysStoppedAnimation(isCompleted ? kMainSage : kMainSky),
                minHeight: 8,
              ),
            ),
            if (!isCompleted) ...[
              const SizedBox(height: 8),
              Text('탭하여 진행 기록', style: mainBody(size: 11, color: kMainMuted)),
            ],
          ],
        ),
      ),
    );
  }
}
