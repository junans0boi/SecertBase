import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/auth_service.dart';
import '../../core/main_design.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final _auth = AuthService();
  Map<String, dynamic>? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (uid == null) return;
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse(
          '${_auth.baseUrl}/api/reports/monthly?user_id=$uid&month=$month',
        ),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] == true && mounted)
        setState(() => _report = data['report'] as Map<String, dynamic>?);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        foregroundColor: kMainInk,
        title: Text(
          '월간 리포트',
          style: mainBody(size: 17, color: kMainInk, weight: FontWeight.w800),
        ),
      ),
      body: CozyPage(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                children: [
                  MainCard(
                    gradient: kRoseGrad,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_report?['month'] ?? ''} 우리 리포트',
                          style: mainTitle(size: 28, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '이번 달 둘이 만든 흔적',
                          style: mainBody(
                            size: 14,
                            color: Colors.white.withAlpha(220),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _metric(
                          '완료한 날',
                          '${_report?['completedDays'] ?? 0}일',
                          kMainSage,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _metric(
                          '최고 스트릭',
                          '${_report?['maxStreak'] ?? 0}일',
                          kMainRose,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _listMetric('행동 기록', _report?['actions'] as List?),
                  const SizedBox(height: 12),
                  _listMetric('소원권', _report?['wishTickets'] as List?),
                ],
              ),
      ),
    );
  }

  Widget _metric(String label, String value, Color color) => MainCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: mainBody(size: 12, color: kMainMuted)),
        const SizedBox(height: 6),
        Text(value, style: mainTitle(size: 26, color: color)),
      ],
    ),
  );

  Widget _listMetric(String title, List? rows) => MainCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: mainBody(size: 15, color: kMainInk, weight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (rows == null || rows.isEmpty)
          Text('아직 데이터가 없어요', style: mainBody(size: 13, color: kMainMuted))
        else
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '${row['action_type'] ?? row['status']}: ${row['count']}',
                style: mainBody(size: 13, color: kMainSub),
              ),
            ),
          ),
      ],
    ),
  );
}
