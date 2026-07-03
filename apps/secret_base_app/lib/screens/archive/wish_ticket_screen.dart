import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/auth_service.dart';
import '../../core/main_design.dart';

class WishTicketScreen extends StatefulWidget {
  const WishTicketScreen({super.key});

  @override
  State<WishTicketScreen> createState() => _WishTicketScreenState();
}

class _WishTicketScreenState extends State<WishTicketScreen> {
  final _auth = AuthService();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${_auth.baseUrl}/api/wish-tickets?user_id=$uid'),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] == true && mounted) {
        setState(() {
          _tickets = (data['tickets'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTicket() async {
    final issuer = _auth.user?['UserId'] ?? _auth.user?['id'];
    final ownerCode = _auth.user?['PartnerCode'];
    if (issuer == null || ownerCode == null || _titleCtrl.text.trim().isEmpty)
      return;
    await http.post(
      Uri.parse('${_auth.baseUrl}/api/wish-tickets'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'issuer_user_id': issuer,
        'owner_user_code': ownerCode,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'source_type': 'manual',
      }),
    );
    _titleCtrl.clear();
    _descCtrl.clear();
    if (mounted) Navigator.pop(context);
    await _load();
  }

  Future<void> _useTicket(Map<String, dynamic> ticket) async {
    final uid = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (uid == null) return;
    await http.patch(
      Uri.parse('${_auth.baseUrl}/api/wish-tickets/${ticket['id']}/use'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': uid}),
    );
    await _load();
  }

  void _openCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kMainPaper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            16,
            18,
            MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('소원권 만들기', style: mainTitle(size: 24)),
              const SizedBox(height: 12),
              _field(_titleCtrl, '소원권 이름'),
              const SizedBox(height: 10),
              _field(_descCtrl, '설명'),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _createTicket,
                  child: const Text('만들기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint) => TextField(
    controller: ctrl,
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: kMainPaperSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final myId = '${_auth.user?['UserId'] ?? _auth.user?['id']}';
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        foregroundColor: kMainInk,
        title: Text(
          '소원권',
          style: mainBody(size: 17, color: kMainInk, weight: FontWeight.w800),
        ),
        actions: [
          IconButton(onPressed: _openCreateSheet, icon: const Icon(Icons.add)),
        ],
      ),
      body: CozyPage(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                  itemCount: _tickets.isEmpty ? 1 : _tickets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    if (_tickets.isEmpty) {
                      return MainCard(
                        child: Text(
                          '아직 소원권이 없어요',
                          style: mainBody(size: 14, color: kMainSub),
                        ),
                      );
                    }
                    final ticket = _tickets[i];
                    final mine = '${ticket['owner_user_id']}' == myId;
                    final available = ticket['status'] == 'available';
                    return MainCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${ticket['title']}',
                            style: mainBody(
                              size: 16,
                              color: kMainInk,
                              weight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${ticket['description'] ?? ''}',
                            style: mainBody(size: 13, color: kMainSub),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            mine ? '내가 가진 소원권' : '상대가 가진 소원권',
                            style: mainBody(size: 12, color: kMainMuted),
                          ),
                          if (mine && available) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () => _useTicket(ticket),
                              icon: const Icon(Icons.redeem_outlined, size: 17),
                              label: const Text('사용 완료'),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
