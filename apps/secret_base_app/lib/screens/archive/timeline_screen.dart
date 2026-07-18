import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/auth_service.dart';
import '../../core/main_design.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final _auth = AuthService();
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;

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
        Uri.parse('${_auth.baseUrl}/api/timeline?user_id=$uid&limit=50'),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] == true && mounted) {
        setState(() {
          _events = (data['events'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
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
          '우리 타임라인',
          style: mainBody(size: 17, color: kMainInk, weight: FontWeight.w800),
        ),
        elevation: 0,
      ),
      body: CozyPage(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _events.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(18),
                        children: [
                          MainCard(
                            child: Text(
                              '아직 기록된 이벤트가 없어요',
                              style: mainBody(size: 14, color: kMainSub),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                        itemCount: _events.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _eventCard(_events[i]),
                      ),
              ),
      ),
    );
  }

  Widget _eventCard(Map<String, dynamic> event) {
    final actor = event['ActorName'] ?? event['ActorNickname'] ?? '우리';
    final date = '${event['event_date'] ?? event['created_at'] ?? ''}'.split(
      'T',
    )[0];
    return MainCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DoodleBadge(
            color: _eventColor('${event['event_type']}'),
            backgroundColor: _eventColor(
              '${event['event_type']}',
            ).withAlpha(28),
            size: 44,
            child: Icon(
              _eventIcon('${event['event_type']}'),
              size: 21,
              color: _eventColor('${event['event_type']}'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${event['title'] ?? ''}',
                  style: mainBody(
                    size: 15,
                    color: kMainInk,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$actor · $date',
                  style: mainBody(size: 12, color: kMainMuted),
                ),
                if (event['body'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${event['body']}',
                    style: mainBody(size: 13, color: kMainSub, height: 1.35),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _eventIcon(String type) {
    return switch (type) {
      'question_answered' => Icons.question_answer_outlined,
      'mission_completed' => Icons.task_alt_outlined,
      'streak_completed' => Icons.local_fire_department_outlined,
      'wish_ticket_created' => Icons.card_giftcard_outlined,
      'wish_ticket_used' => Icons.redeem_outlined,
      _ => Icons.auto_awesome_outlined,
    };
  }

  Color _eventColor(String type) {
    return switch (type) {
      'question_answered' => kMainHoney,
      'mission_completed' => kMainSage,
      'streak_completed' => kMainRose,
      'wish_ticket_created' => kMainSky,
      'wish_ticket_used' => kMainPeach,
      _ => kMainSub,
    };
  }
}
