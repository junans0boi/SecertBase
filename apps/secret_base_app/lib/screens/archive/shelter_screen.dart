import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/auth_service.dart';
import '../../core/main_design.dart';

// ──────────────────────────────────────────────────────────────────────────────
// 마음 대피소 화면
// - 탭1: 나만의 개인 일기 (mood 태그, 카테고리 필터, 수정/삭제)
// - 탭2: 관계 가이드북
// ──────────────────────────────────────────────────────────────────────────────

const _moods = ['😊', '😢', '😤', '😌', '😰', '💕', '🤔', '😴'];
const _moodLabels = ['행복', '슬픔', '화남', '평온', '불안', '사랑', '고민', '피곤'];

const _categories = [
  'general',
  'mbti',
  'conflict',
  'growth',
  'gratitude',
  'memory',
];
const _categoryLabels = {
  'general': '일상',
  'mbti': 'MBTI',
  'conflict': '갈등',
  'growth': '성장',
  'gratitude': '감사',
  'memory': '추억',
};
const _categoryIcons = {
  'general': '📝',
  'mbti': '🧠',
  'conflict': '🌊',
  'growth': '🌱',
  'gratitude': '🙏',
  'memory': '💌',
};

class ShelterScreen extends StatefulWidget {
  const ShelterScreen({super.key});

  @override
  State<ShelterScreen> createState() => _ShelterScreenState();
}

class _ShelterScreenState extends State<ShelterScreen>
    with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  late TabController _tabController;
  final _journalCtrl = TextEditingController();

  List<dynamic> _journals = [];
  bool _loadingJournal = true;
  bool _saving = false;

  String _selectedMood = '😊';
  String _selectedCategory = 'general';
  String _filterCategory = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadJournals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _journalCtrl.dispose();
    super.dispose();
  }

  int? get _userId {
    final value = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (value is int) return value;
    return int.tryParse('$value');
  }

  List<dynamic> get _filteredJournals {
    if (_filterCategory == 'all') return _journals;
    return _journals.where((j) => j['category'] == _filterCategory).toList();
  }

  Future<void> _loadJournals() async {
    final uid = _userId;
    if (uid == null) return;
    setState(() => _loadingJournal = true);
    try {
      final response = await http.get(
        Uri.parse('${_auth.baseUrl}/api/reflections?user_id=$uid'),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['ok'] == true) {
        setState(() {
          _journals = data['reflections'] ?? [];
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingJournal = false);
    }
  }

  Future<void> _saveJournal() async {
    final uid = _userId;
    final text = _journalCtrl.text.trim();
    if (uid == null || text.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      final response = await http.post(
        Uri.parse('${_auth.baseUrl}/api/reflections'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': uid,
          'content': text,
          'mood_tag': _selectedMood,
          'category': _selectedCategory,
        }),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (response.statusCode == 200 && data['ok'] == true) {
        _journalCtrl.clear();
        FocusScope.of(context).unfocus();
        _loadJournals();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('마음속 이야기를 대피소에 담았어요 🍃')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장 실패. 네트워크 상태를 확인해주세요.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editJournal(Map<String, dynamic> journal) async {
    final editCtrl = TextEditingController(text: journal['content']);
    String editMood = journal['mood_tag'] ?? '😊';
    String editCategory = journal['category'] ?? 'general';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kMainPaper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('기록 수정', style: mainTitle(size: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 기분 선택
                Text('기분', style: mainBody(size: 12, color: kMainSub)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: List.generate(
                    _moods.length,
                    (i) => GestureDetector(
                      onTap: () => setDialogState(() => editMood = _moods[i]),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: editMood == _moods[i]
                              ? kMainRoseSoft
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: editMood == _moods[i]
                                ? kMainRose
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          _moods[i],
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: editCtrl,
                  maxLines: 6,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: kMainRose,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('취소', style: mainBody(color: kMainMuted)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: kMainRose,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                '저장',
                style: mainBody(color: Colors.white, weight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;

    try {
      await http.patch(
        Uri.parse('${_auth.baseUrl}/api/reflections/${journal['id']}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'content': editCtrl.text.trim(),
          'mood_tag': editMood,
          'category': editCategory,
        }),
      );
      _loadJournals();
    } catch (_) {}
  }

  Future<void> _deleteJournal(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('${_auth.baseUrl}/api/reflections/$id'),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['ok'] == true) _loadJournals();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainPaper,
      appBar: AppBar(
        backgroundColor: kMainPaper,
        elevation: 0,
        title: Text('마음 대피소 🍃', style: mainTitle(size: 22)),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: mainBody(size: 14, weight: FontWeight.bold),
          unselectedLabelStyle: mainBody(size: 14),
          labelColor: kMainRose,
          unselectedLabelColor: kMainMuted,
          indicatorColor: kMainRose,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: '나만의 일기'),
            Tab(text: '관계 가이드북'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildJournalTab(), _buildGuidebookTab()],
      ),
    );
  }

  Widget _buildJournalTab() {
    return Column(
      children: [
        // ── 새 일기 작성 패널
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: kMainRose.withValues(alpha: 0.08),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('지금 어떤 기분이에요?', style: mainBody(size: 13, color: kMainSub)),
              const SizedBox(height: 8),
              // 기분 선택
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _moods.length,
                  itemBuilder: (ctx, i) => GestureDetector(
                    onTap: () => setState(() => _selectedMood = _moods[i]),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedMood == _moods[i]
                            ? kMainRoseSoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedMood == _moods[i]
                              ? kMainRose
                              : kMainRoseSoft,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_moods[i], style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 4),
                          Text(
                            _moodLabels[i],
                            style: mainBody(
                              size: 11,
                              color: _selectedMood == _moods[i]
                                  ? kMainRose
                                  : kMainMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 카테고리 선택
              SizedBox(
                height: 32,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (ctx, i) {
                    final cat = _categories[i];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedCategory == cat
                              ? kMainRose
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedCategory == cat
                                ? kMainRose
                                : kMainRoseSoft,
                          ),
                        ),
                        child: Text(
                          '${_categoryIcons[cat]} ${_categoryLabels[cat]}',
                          style: mainBody(
                            size: 11,
                            color: _selectedCategory == cat
                                ? Colors.white
                                : kMainInk,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _journalCtrl,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: '오늘의 마음속 이야기를 털어놓아 보세요.\n파트너에게는 절대 보이지 않아요 🔒',
                  hintStyle: mainBody(size: 13, color: kMainMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kMainRose, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveJournal,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.lock_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                  label: Text(
                    '비공개 저장',
                    style: mainBody(
                      size: 13,
                      color: Colors.white,
                      weight: FontWeight.bold,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: kMainRose,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── 카테고리 필터 탭
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterChip(
                label: '전체',
                isSelected: _filterCategory == 'all',
                onTap: () => setState(() => _filterCategory = 'all'),
              ),
              ...(_categories.map(
                (cat) => _FilterChip(
                  label: '${_categoryIcons[cat]} ${_categoryLabels[cat]}',
                  isSelected: _filterCategory == cat,
                  onTap: () => setState(() => _filterCategory = cat),
                ),
              )),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── 일기 목록
        Expanded(
          child: _loadingJournal
              ? const Center(child: CircularProgressIndicator(color: kMainRose))
              : _filteredJournals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🌿', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        '마음속 이야기를 써보세요',
                        style: mainBody(size: 14, color: kMainSub),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: _filteredJournals.length,
                  itemBuilder: (ctx, i) {
                    final j = _filteredJournals[i];
                    final moodTag = j['mood_tag'] ?? '😊';
                    final category = j['category'] ?? 'general';
                    final dateStr = (j['created_at'] ?? '').toString();
                    final date = dateStr.length >= 10
                        ? dateStr.substring(0, 10)
                        : dateStr;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                moodTag,
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: kMainRoseSoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_categoryIcons[category]} ${_categoryLabels[category] ?? category}',
                                  style: mainBody(size: 11, color: kMainRose),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                date,
                                style: mainBody(size: 11, color: kMainMuted),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _editJournal(j),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  size: 16,
                                  color: kMainMuted,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => showDialog(
                                  context: ctx,
                                  builder: (c) => AlertDialog(
                                    backgroundColor: kMainPaper,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: Text(
                                      '삭제할까요?',
                                      style: mainTitle(size: 16),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(c),
                                        child: Text(
                                          '취소',
                                          style: mainBody(color: kMainMuted),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(c);
                                          _deleteJournal(j['id']);
                                        },
                                        child: const Text(
                                          '삭제',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.delete_rounded,
                                  size: 16,
                                  color: kMainMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            j['content'] ?? '',
                            style: mainBody(size: 14, color: kMainInk),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGuidebookTab() {
    final guides = [
      _GuideItem(
        icon: '🧠',
        title: 'MBTI 차이, 극복하는 법',
        content:
            'MBTI는 성격 유형일 뿐, 우열이 없어요. I와 E의 에너지 충전 방식이 다를 뿐입니다.\n\n'
            '• T와 F: T는 논리로 문제를 해결하려 하고 F는 감정 공감을 원해요. 서로의 방식이 틀린 게 아니라 다른 것임을 인식하는 것이 첫 걸음이에요.\n'
            '• J와 P: J는 계획, P는 유연함을 선호해요. 여행 계획은 J가, 즉흥 이벤트는 P가 주도하는 역할 분담이 효과적이에요.\n\n'
            '핵심: 상대의 MBTI를 "그래서 그랬구나"로 이해하는 도구로 쓰되, 상대를 박스에 가두는 레이블로 쓰지 마세요.',
      ),
      _GuideItem(
        icon: '🌊',
        title: '갈등을 봉합이 아닌 해결로',
        content:
            '싸운 직후 억지로 화해하면 감정이 쌓입니다.\n\n'
            '1. 서로 30분의 쿨다운 타임을 갖기\n'
            '2. "나는 ○○ 때문에 ○○하게 느꼈어" (I-Message) 방식으로 말하기\n'
            '3. 상대가 말할 때 반론 금지 — 먼저 끝까지 듣기\n'
            '4. 사과할 때 "미안한데..." (역접) 없이 순수하게 사과하기\n\n'
            '기억하세요: 싸움의 목적은 이기는 게 아니라 서로를 더 이해하는 거예요.',
      ),
      _GuideItem(
        icon: '⚖️',
        title: '수평적 관계를 만드는 법',
        content:
            '건강한 연애는 한쪽이 일방적으로 맞추거나 희생하지 않아요.\n\n'
            '• 의사결정: 큰 결정은 두 사람이 함께 논의하고 합의하기\n'
            '• 경제: 각자의 경제적 독립성을 존중하기\n'
            '• 시간: 혼자만의 시간도 건강한 관계의 일부예요\n'
            '• 관심사: 상대의 취미와 관심사를 강제로 공유할 필요는 없어요\n\n'
            '나를 잃지 않으면서 함께할 때, 관계가 더 단단해집니다.',
      ),
      _GuideItem(
        icon: '🌱',
        title: '연애 초보자를 위한 기본기',
        content:
            '• 연락 주기: "적당한" 연락 주기는 커플마다 달라요. 초반에 명확히 이야기 나눠두세요.\n'
            '• 감정 표현: 표현하지 않으면 아무도 몰라요. 사랑한다면 사랑한다고, 불편하면 불편하다고 말하세요.\n'
            '• 기대치 조율: "당연히 이럴 거야"라는 기대는 실망의 씨앗이에요.\n'
            '• 경계선: 불편한 것은 초반에 분명히 말해두는 게 나중에 훨씬 편해요.\n\n'
            '완벽한 연애는 없지만, 함께 노력하는 연애는 있어요.',
      ),
      _GuideItem(
        icon: '💪',
        title: '힘든 시기에 관계 지키기',
        content:
            '취업 걱정, 가족 문제, 건강 이슈… 힘든 시기에 연애가 흔들리는 건 자연스러운 일이에요.\n\n'
            '• 파트너에게 내 상황을 솔직하게 알리기 (혼자 끌어안지 않기)\n'
            '• "요즘 여유가 없어서 연락이 줄어도 이해해줘"라고 미리 말하기\n'
            '• 지지를 원하는지 / 혼자 있고 싶은지 파트너에게 명확히 말하기\n'
            '• 이 시기가 지나면 반드시 고마움을 표현하기\n\n'
            '힘든 시기를 함께 버틴 커플은 더 강해집니다.',
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: guides.length,
      itemBuilder: (ctx, i) => _GuideCard(guide: guides[i]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 필터 칩
// ──────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? kMainRose : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? kMainRose : kMainRoseSoft),
        ),
        child: Text(
          label,
          style: mainBody(
            size: 11,
            color: isSelected ? Colors.white : kMainInk,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 가이드 아이템
// ──────────────────────────────────────────────────────────────────────────────

class _GuideItem {
  final String icon;
  final String title;
  final String content;
  const _GuideItem({
    required this.icon,
    required this.title,
    required this.content,
  });
}

class _GuideCard extends StatefulWidget {
  final _GuideItem guide;
  const _GuideCard({required this.guide});

  @override
  State<_GuideCard> createState() => _GuideCardState();
}

class _GuideCardState extends State<_GuideCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: kMainRose.withValues(alpha: 0.06), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(widget.guide.icon, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.guide.title,
                      style: mainBody(
                        size: 15,
                        color: kMainInk,
                        weight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: kMainMuted,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      widget.guide.content,
                      style: mainBody(
                        size: 13,
                        color: kMainSub,
                      ).copyWith(height: 1.65),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
