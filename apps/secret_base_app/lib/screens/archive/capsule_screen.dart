import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/auth_service.dart';
import '../../core/main_design.dart';

class CapsuleScreen extends StatefulWidget {
  const CapsuleScreen({super.key});

  @override
  State<CapsuleScreen> createState() => _CapsuleScreenState();
}

class _CapsuleScreenState extends State<CapsuleScreen> {
  final _auth = AuthService();
  List<Map<String, dynamic>> _capsules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('${_auth.baseUrl}/api/capsules'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['ok'] == true && mounted) {
          setState(() {
            _capsules =
                (data['capsules'] as List?)
                    ?.map((e) => Map<String, dynamic>.from(e as Map))
                    .toList() ??
                [];
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openCapsule(Map<String, dynamic> capsule) async {
    final id = capsule['id'];
    try {
      final res = await http.patch(
        Uri.parse('${_auth.baseUrl}/api/capsules/$id/open'),
      );
      if (res.statusCode == 200) {
        await _load();
        if (mounted) _showOpenedDialog(capsule);
      }
    } catch (_) {}
  }

  void _showOpenedDialog(Map<String, dynamic> capsule) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kMainPaper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text('🕯️', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            Text(
              capsule['title'] ?? '',
              style: mainTitle(size: 22, color: kMainHoney),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kMainHoneySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                capsule['message'] ?? '(내용 없음)',
                style: mainBody(size: 15, color: kMainInk, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${capsule['created_by']} 이/가 보낸 편지',
              style: mainBody(size: 12, color: kMainMuted),
            ),
          ],
        ),
        actions: [
          Center(
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: kMainHoney,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '닫기',
                style: mainBody(
                  size: 14,
                  color: Colors.white,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    DateTime? openDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: kMainPaper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text('🕯️ 타임캡슐 만들기', style: mainTitle(size: 20)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(titleCtrl, '제목', '예: 1년 후의 우리에게'),
                const SizedBox(height: 12),
                TextField(
                  controller: msgCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: '미래의 우리에게 전하고 싶은 말을 적어요...',
                    filled: true,
                    fillColor: kMainPaperSoft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    hintStyle: mainBody(size: 13, color: kMainMuted),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  style: mainBody(size: 14, color: kMainInk),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime(now.year, now.month + 1, now.day),
                      firstDate: DateTime(now.year, now.month, now.day + 1),
                      lastDate: DateTime(now.year + 10),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: kMainHoney,
                            onPrimary: Colors.white,
                            surface: kMainPaper,
                            onSurface: kMainInk,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setDlg(() => openDate = picked);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: openDate != null ? kMainHoneySoft : kMainPaperSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: openDate != null ? kMainHoney : kMainLine,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_clock_rounded,
                          size: 18,
                          color: openDate != null ? kMainHoney : kMainMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          openDate == null
                              ? '열어볼 날짜 선택 (필수)'
                              : '${openDate!.year}.${openDate!.month.toString().padLeft(2, '0')}.${openDate!.day.toString().padLeft(2, '0')} 에 열려요',
                          style: mainBody(
                            size: 13,
                            color: openDate != null ? kMainHoney : kMainMuted,
                            weight: openDate != null
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
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
              onPressed: titleCtrl.text.trim().isEmpty || openDate == null
                  ? null
                  : () async {
                      if (titleCtrl.text.trim().isEmpty || openDate == null)
                        return;
                      Navigator.pop(ctx);
                      await _create(
                        title: titleCtrl.text.trim(),
                        message: msgCtrl.text.trim(),
                        openDate: openDate!,
                      );
                    },
              style: FilledButton.styleFrom(
                backgroundColor: kMainHoney,
                disabledBackgroundColor: kMainLine,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '봉인하기',
                style: mainBody(
                  size: 14,
                  color: Colors.white,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create({
    required String title,
    required String message,
    required DateTime openDate,
  }) async {
    final userCode =
        _auth.user?['UserCode'] ?? _auth.user?['userCode'] ?? 'unknown';
    final openDateStr =
        '${openDate.year}-${openDate.month.toString().padLeft(2, '0')}-${openDate.day.toString().padLeft(2, '0')}';
    try {
      await http.post(
        Uri.parse('${_auth.baseUrl}/api/capsules'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'message': message.isNotEmpty ? message : null,
          'created_by': userCode,
          'open_date': openDateStr,
        }),
      );
      await _load();
    } catch (_) {}
  }

  TextField _field(TextEditingController ctrl, String label, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: kMainPaperSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        labelStyle: mainBody(size: 12, color: kMainMuted),
        hintStyle: mainBody(size: 13, color: kMainMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
      style: mainBody(size: 14, color: kMainInk),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        foregroundColor: kMainInk,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '🕯️ 타임캡슐',
          style: mainBody(size: 17, color: kMainInk, weight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: kMainHoney,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: CozyPage(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                color: kMainHoney,
                child: _capsules.isEmpty ? _empty() : _list(),
              ),
      ),
    );
  }

  Widget _empty() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🕯️', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 14),
              Text('아직 타임캡슐이 없어요', style: mainTitle(size: 22)),
              const SizedBox(height: 8),
              Text('미래의 우리에게 편지를 남겨보세요', style: mainBody(size: 14)),
              const SizedBox(height: 4),
              Text(
                '열어볼 날짜를 정하고 봉인해요',
                style: mainBody(size: 13, color: kMainMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _list() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
      itemCount: _capsules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _capsuleCard(_capsules[i]),
    );
  }

  Widget _capsuleCard(Map<String, dynamic> c) {
    final isOpened = (c['is_opened'] as num?)?.toInt() == 1;
    final isOpenable = !isOpened && ((c['is_openable'] as num?)?.toInt() == 1);
    final openDate = c['open_date']?.toString().split('T')[0] ?? '';
    final openDateFormatted = openDate.replaceAll('-', '.');

    // Days remaining
    int? daysLeft;
    if (!isOpened && !isOpenable && openDate.isNotEmpty) {
      final target = DateTime.tryParse(openDate);
      if (target != null) {
        daysLeft = target.difference(DateTime.now()).inDays + 1;
      }
    }

    return MainCard(
      padding: const EdgeInsets.all(18),
      color: isOpened
          ? kMainSageSoft
          : isOpenable
          ? kMainHoneySoft
          : kMainPaper,
      borderColor: isOpenable ? kMainHoney.withAlpha(180) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isOpened
                    ? '🎉'
                    : isOpenable
                    ? '✨'
                    : '🔒',
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  c['title'] ?? '',
                  style: mainBody(
                    size: 16,
                    color: kMainInk,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
              if (isOpened)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: kMainSage,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '열림',
                    style: mainBody(
                      size: 11,
                      color: Colors.white,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (isOpened && (c['message'] ?? '').isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kMainSageSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                c['message'],
                style: mainBody(size: 14, color: kMainInk, height: 1.55),
              ),
            ),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: kMainMuted,
              ),
              const SizedBox(width: 4),
              Text(
                isOpened
                    ? '열린 날: $openDateFormatted'
                    : '$openDateFormatted 에 열려요',
                style: mainBody(size: 12, color: kMainMuted),
              ),
              if (daysLeft != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: kMainSkySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'D-$daysLeft',
                    style: mainBody(
                      size: 11,
                      color: kMainSky,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (!isOpened)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${c['created_by']} 이/가 작성',
                style: mainBody(size: 11, color: kMainMuted),
              ),
            ),
          if (isOpenable) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _openCapsule(c),
                style: FilledButton.styleFrom(
                  backgroundColor: kMainHoney,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: Text(
                  '지금 열어볼까요? 🎉',
                  style: mainBody(
                    size: 14,
                    color: Colors.white,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
