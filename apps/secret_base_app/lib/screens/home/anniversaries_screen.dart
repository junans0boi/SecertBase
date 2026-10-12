import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/http/api_client.dart';
import '../../core/main_design.dart';

class AnniversariesScreen extends StatefulWidget {
  const AnniversariesScreen({super.key});

  @override
  State<AnniversariesScreen> createState() => _AnniversariesScreenState();
}

class _AnniversariesScreenState extends State<AnniversariesScreen> {
  final _auth = AuthService();
  late final ApiClient _api;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(
      baseUrl: _auth.baseUrl,
      tokenProvider: () => _auth.token,
    );
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final body = await _api.getJson('/api/anniversaries');
      if (!mounted) return;
      final list = body['anniversaries'];
      setState(() {
        _items = (list is List)
            ? list.map((a) => Map<String, dynamic>.from(a as Map)).toList()
            : [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id) async {
    try {
      await _api.deleteJson('/api/anniversaries/$id');
      if (!mounted) return;
      setState(() => _items.removeWhere((a) => a['id'] == id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제하지 못했어요')),
        );
      }
    }
  }

  Future<void> _showForm([Map<String, dynamic>? existing]) async {
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AnniversaryForm(existing: existing),
    );
    if (result == null) return;

    try {
      if (existing != null) {
        await _api.patchJson('/api/anniversaries/${existing['id']}', body: result);
      } else {
        await _api.postJson('/api/anniversaries', body: result);
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장하지 못했어요')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기념일'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showForm(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_available_rounded,
                          size: 56, color: kMainRoseSoft),
                      const SizedBox(height: 12),
                      Text(
                        '기념일을 추가해보세요',
                        style: mainBody(size: 15, color: kMainMuted),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _showForm(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('기념일 추가'),
                        style: FilledButton.styleFrom(
                          backgroundColor: kMainRose,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final a = _items[i];
                    final daysUntil = a['days_until'];
                    final daysLabel = daysUntil == null
                        ? ''
                        : daysUntil == 0
                            ? '오늘!'
                            : 'D-$daysUntil';
                    return ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: kMainRoseSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.favorite_rounded,
                            color: kMainRose, size: 22),
                      ),
                      title: Text(
                        '${a['label']}',
                        style: mainBody(
                            size: 15, weight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${a['date']}${a['repeat_yearly'] == true ? ' · 매년 반복' : ''}',
                        style: mainBody(size: 12, color: kMainMuted),
                      ),
                      trailing: daysLabel.isNotEmpty
                          ? Text(
                              daysLabel,
                              style: mainBody(
                                  size: 13,
                                  color: kMainRose,
                                  weight: FontWeight.w700),
                            )
                          : null,
                      onTap: () => _showForm(a),
                      onLongPress: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('삭제할까요?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('삭제',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await _delete(int.parse('${a['id']}'));
                        }
                      },
                    );
                  },
                ),
    );
  }
}

class _AnniversaryForm extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const _AnniversaryForm({this.existing});

  @override
  State<_AnniversaryForm> createState() => _AnniversaryFormState();
}

class _AnniversaryFormState extends State<_AnniversaryForm> {
  late final TextEditingController _labelCtrl;
  late DateTime _date;
  late bool _repeatYearly;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(
      text: widget.existing?['label'] as String? ?? '',
    );
    _date = DateTime.tryParse(
          widget.existing?['date'] as String? ?? '',
        ) ??
        DateTime.now();
    _repeatYearly = (widget.existing?['repeat_yearly'] as bool?) ?? true;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.existing == null ? '기념일 추가' : '기념일 수정',
              style: mainTitle(size: 18),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: '이름 (예: 100일, 생일)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_rounded),
              label: Text(_fmt(_date)),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _repeatYearly,
              onChanged: (v) => setState(() => _repeatYearly = v ?? true),
              title: const Text('매년 반복'),
              contentPadding: EdgeInsets.zero,
              activeColor: kMainRose,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                final label = _labelCtrl.text.trim();
                if (label.isEmpty) return;
                Navigator.pop(context, {
                  'label': label,
                  'date': _fmt(_date),
                  'repeat_yearly': _repeatYearly,
                });
              },
              style: FilledButton.styleFrom(backgroundColor: kMainRose),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}
