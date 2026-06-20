import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/auth_service.dart';
import '../../core/main_design.dart';

const _categories = ['식당', '카페', '활동', '여행', '쇼핑', '기타'];
const _categoryEmojis = {
  '식당': '🍽️',
  '카페': '☕',
  '활동': '🎯',
  '여행': '✈️',
  '쇼핑': '🛍️',
  '기타': '📍',
};

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _auth = AuthService();
  List<Map<String, dynamic>> _pins = [];
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
      final res = await http.get(Uri.parse('${_auth.baseUrl}/api/map'));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] == true) {
        setState(() {
          _pins = (data['pins'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];
        });
      }
    } catch (_) {
      debugPrint('map load error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final memoCtrl = TextEditingController();
    String selectedCategory = '기타';
    int selectedRating = 5;
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: kMainPaper,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('장소 추가', style: mainTitle(size: 22)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: '장소 이름',
                    hintText: '예: 을지로 어딘가',
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
                ),
                const SizedBox(height: 14),
                Text('카테고리', style: mainBody(size: 12, color: kMainMuted, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _categories.map((cat) {
                    final selected = cat == selectedCategory;
                    return GestureDetector(
                      onTap: () => setDlg(() => selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? kMainPeach.withAlpha(60) : kMainPaperSoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? kMainPeach : kMainLine,
                          ),
                        ),
                        child: Text(
                          '${_categoryEmojis[cat] ?? '📍'} $cat',
                          style: mainBody(
                            size: 12,
                            color: selected ? kMainInk : kMainMuted,
                            weight: selected ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text('별점', style: mainBody(size: 12, color: kMainMuted, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return GestureDetector(
                      onTap: () => setDlg(() => selectedRating = star),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.star_rounded,
                          color: star <= selectedRating ? kMainHoney : kMainLine,
                          size: 28,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: kMainPeach,
                            onPrimary: Colors.white,
                            surface: kMainPaper,
                            onSurface: kMainInk,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setDlg(() => selectedDate = picked);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: kMainPaperSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      selectedDate == null
                          ? '방문 날짜 선택 (선택)'
                          : '${selectedDate!.year}.${selectedDate!.month.toString().padLeft(2, '0')}.${selectedDate!.day.toString().padLeft(2, '0')}',
                      style: mainBody(
                        size: 13,
                        color: selectedDate == null ? kMainMuted : kMainInk,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: memoCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '방문 후기 (선택)',
                    filled: true,
                    fillColor: kMainPaperSoft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    hintStyle: mainBody(size: 13, color: kMainMuted),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: mainBody(size: 14, color: kMainInk),
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
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await _addPin(
                  name: nameCtrl.text.trim(),
                  category: selectedCategory,
                  rating: selectedRating,
                  visitDate: selectedDate,
                  memo: memoCtrl.text.trim(),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: kMainPeach,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('추가', style: mainBody(size: 14, color: Colors.white, weight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPin({
    required String name,
    required String category,
    required int rating,
    DateTime? visitDate,
    required String memo,
  }) async {
    final userCode = _auth.user?['UserCode'] ?? _auth.user?['userCode'] ?? 'unknown';
    String? visitDateStr;
    if (visitDate != null) {
      visitDateStr =
          '${visitDate.year}-${visitDate.month.toString().padLeft(2, '0')}-${visitDate.day.toString().padLeft(2, '0')}';
    }
    try {
      await http.post(
        Uri.parse('${_auth.baseUrl}/api/map'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'place_name': name,
          'category': category,
          'rating': rating,
          'visit_date': visitDateStr,
          'memo': memo.isNotEmpty ? memo : null,
          'created_by': userCode,
        }),
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
        title: Text('🗺️ 비밀 지도', style: mainBody(size: 17, color: kMainInk, weight: FontWeight.w700)),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: kMainPeach,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_location_alt_outlined),
      ),
      body: CozyPage(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                color: kMainPeach,
                child: _pins.isEmpty
                    ? _empty()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
                        itemCount: _pins.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _pinCard(_pins[i]),
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
          Text('🗺️', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('아직 등록된 장소가 없어요', style: mainTitle(size: 22)),
          const SizedBox(height: 6),
          Text('우리 함께 간 곳들을 기록해요', style: mainBody(size: 13)),
        ],
      ),
    );
  }

  Widget _pinCard(Map<String, dynamic> pin) {
    final category = pin['category'] ?? '기타';
    final emoji = _categoryEmojis[category] ?? '📍';
    final rating = (pin['rating'] as num?)?.toInt() ?? 0;
    final visitDate = pin['visit_date'];
    final visitDateStr = visitDate != null
        ? visitDate.toString().split('T')[0].replaceAll('-', '.')
        : null;

    return MainCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DoodleBadge(
            color: kMainPeach,
            backgroundColor: kMainPeachSoft,
            size: 52,
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pin['place_name'] ?? '',
                  style: mainBody(size: 16, color: kMainInk, weight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: kMainPeachSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(category, style: mainBody(size: 11, color: kMainPeach)),
                    ),
                    if (visitDateStr != null) ...[
                      const SizedBox(width: 8),
                      Text(visitDateStr, style: mainBody(size: 11, color: kMainMuted)),
                    ],
                  ],
                ),
                if (rating > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: i < rating ? kMainHoney : kMainLine,
                      ),
                    ),
                  ),
                ],
                if ((pin['memo'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    pin['memo'],
                    style: mainBody(size: 12, color: kMainSub, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
