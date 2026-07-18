import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/main_design.dart';

class DateRouletteScreen extends StatefulWidget {
  const DateRouletteScreen({super.key});

  @override
  State<DateRouletteScreen> createState() => _DateRouletteScreenState();
}

class _DateRouletteScreenState extends State<DateRouletteScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipCtrl;
  late Animation<double> _scaleX;

  String _budget = '전체';
  String _type = '전체';
  _DateIdea _current = _ideas[0];
  bool _flipping = false;

  static const _budgets = ['전체', '저예산', '중간', '럭셔리'];
  static const _types = ['전체', '카페', '식사', '실내', '야외', '문화', '활동'];

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleX = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _flipCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _shuffleNoAnim();
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  List<_DateIdea> get _filtered {
    return _ideas.where((idea) {
      final budgetOk = _budget == '전체' || idea.budget == _budget;
      final typeOk = _type == '전체' || idea.type == _type;
      return budgetOk && typeOk;
    }).toList();
  }

  void _shuffleNoAnim() {
    final pool = _filtered;
    if (pool.isEmpty) return;
    _current = pool[math.Random().nextInt(pool.length)];
  }

  void _spin() async {
    if (_flipping) return;
    final pool = _filtered;
    if (pool.isEmpty) return;
    setState(() => _flipping = true);

    await _flipCtrl.forward();
    setState(() {
      _DateIdea next;
      do {
        next = pool[math.Random().nextInt(pool.length)];
      } while (pool.length > 1 && next == _current);
      _current = next;
      _scaleX = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _flipCtrl,
          curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
        ),
      );
    });
    await _flipCtrl.reverse();

    // Reset animation direction for next spin
    _scaleX = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _flipCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _flipCtrl.reset();
    if (mounted) setState(() => _flipping = false);
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
          '🎲 데이트 룰렛',
          style: mainBody(size: 17, color: kMainInk, weight: FontWeight.w700),
        ),
      ),
      body: CozyPage(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: [
                    _filterRow('예산', _budgets, _budget, (v) {
                      setState(() {
                        _budget = v;
                        _shuffleNoAnim();
                      });
                    }),
                    const SizedBox(height: 10),
                    _filterRow('종류', _types, _type, (v) {
                      setState(() {
                        _type = v;
                        _shuffleNoAnim();
                      });
                    }),
                    const SizedBox(height: 28),
                    _filteredEmpty ? _emptyState() : _ideaCard(),
                    const SizedBox(height: 28),
                    if (!_filteredEmpty) _spinButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _filteredEmpty => _filtered.isEmpty;

  Widget _filterRow(
    String label,
    List<String> options,
    String selected,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: mainBody(size: 12, color: kMainMuted, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((opt) {
              final isSelected = opt == selected;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onChanged(opt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? kMainSky : kMainPaperSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      opt,
                      style: mainBody(
                        size: 13,
                        color: isSelected ? Colors.white : kMainSub,
                        weight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _ideaCard() {
    return AnimatedBuilder(
      animation: _flipCtrl,
      builder: (_, _) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scaleByDouble(_scaleX.value, 1.0, 1.0, 1.0),
        child: _IdeaCard(idea: _current),
      ),
    );
  }

  Widget _spinButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _flipping ? null : _spin,
        icon: const Text('🎲', style: TextStyle(fontSize: 18)),
        label: Text(
          '다시 뽑기',
          style: mainBody(
            size: 16,
            color: Colors.white,
            weight: FontWeight.w700,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: kMainSky,
          disabledBackgroundColor: kMainLine,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Text('😅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('필터에 맞는 데이트가 없어요', style: mainTitle(size: 20)),
          const SizedBox(height: 6),
          Text('다른 조건을 선택해보세요', style: mainBody(size: 13)),
        ],
      ),
    );
  }
}

class _IdeaCard extends StatelessWidget {
  final _DateIdea idea;
  const _IdeaCard({required this.idea});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: idea.gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: idea.shadowColor.withAlpha(70),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_tag(idea.budget), _tag(idea.type)],
          ),
          const SizedBox(height: 22),
          Text(idea.emoji, style: const TextStyle(fontSize: 54)),
          const SizedBox(height: 14),
          Text(
            idea.title,
            style: mainTitle(
              size: 28,
              color: Colors.white,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            idea.description,
            style: mainBody(
              size: 15,
              color: Colors.white.withAlpha(220),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 14,
                color: Colors.white70,
              ),
              const SizedBox(width: 5),
              Text(idea.time, style: mainBody(size: 13, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: mainBody(size: 12, color: Colors.white, weight: FontWeight.w600),
      ),
    );
  }
}

class _DateIdea {
  final String emoji;
  final String title;
  final String description;
  final String budget;
  final String type;
  final String time;
  final LinearGradient gradient;
  final Color shadowColor;

  const _DateIdea({
    required this.emoji,
    required this.title,
    required this.description,
    required this.budget,
    required this.type,
    required this.time,
    required this.gradient,
    required this.shadowColor,
  });
}

const _g1 = LinearGradient(
  colors: [Color(0xFF5AAAD8), Color(0xFF7BC8F0)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const _g2 = LinearGradient(
  colors: [Color(0xFF5EBF8A), Color(0xFF80DEB0)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const _g3 = LinearGradient(
  colors: [Color(0xFFFF7B9C), Color(0xFFFFAD8A)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const _g4 = LinearGradient(
  colors: [Color(0xFFFFC234), Color(0xFFFFE07A)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const _g5 = LinearGradient(
  colors: [Color(0xFFB67DFF), Color(0xFFDF9FFF)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const _ideas = <_DateIdea>[
  _DateIdea(
    emoji: '☕',
    title: '감성 카페 투어',
    description: '동네 숨어있는 감성 카페 두 곳을 찾아서 각자 좋아하는 음료 마시기. 사진도 많이 찍어요!',
    budget: '저예산',
    type: '카페',
    time: '2-3시간',
    gradient: _g4,
    shadowColor: Color(0xFFFFC234),
  ),
  _DateIdea(
    emoji: '🌸',
    title: '동네 골목 산책',
    description: '목적지 없이 예쁜 골목 찾아 걷기. 마음에 드는 곳에서 사진 찍고 편의점 들러서 간식 먹기.',
    budget: '저예산',
    type: '야외',
    time: '1-2시간',
    gradient: _g2,
    shadowColor: Color(0xFF5EBF8A),
  ),
  _DateIdea(
    emoji: '🎬',
    title: '집에서 영화마라톤',
    description: '좋아하는 영화 3편 정하고 이불 깔고 과자 먹으면서 보기. 중간에 배달 시켜도 좋아요.',
    budget: '저예산',
    type: '실내',
    time: '하루',
    gradient: _g5,
    shadowColor: Color(0xFFB67DFF),
  ),
  _DateIdea(
    emoji: '🍳',
    title: '집에서 요리 데이트',
    description: '유튜브에서 새로운 레시피 찾아서 같이 만들기. 실패해도 웃기니까 걱정 마요.',
    budget: '저예산',
    type: '실내',
    time: '2-3시간',
    gradient: _g3,
    shadowColor: Color(0xFFFF7B9C),
  ),
  _DateIdea(
    emoji: '🌅',
    title: '한강 야경 피크닉',
    description: '편의점에서 좋아하는 음식 골라서 한강 가서 자리 잡기. 노을 보면서 도란도란 이야기.',
    budget: '저예산',
    type: '야외',
    time: '반나절',
    gradient: _g4,
    shadowColor: Color(0xFFFFC234),
  ),
  _DateIdea(
    emoji: '🎨',
    title: '서로 초상화 그리기',
    description: '스케치북 하나씩 들고 서로 그려주기. 못 그려도 더 웃기고 소장각이에요.',
    budget: '저예산',
    type: '실내',
    time: '1-2시간',
    gradient: _g5,
    shadowColor: Color(0xFFB67DFF),
  ),
  _DateIdea(
    emoji: '📚',
    title: '북카페 데이트',
    description: '각자 책 한 권씩 골라 읽고 서로 어떤 내용인지 이야기 나누기. 조용하고 아늑한 오후.',
    budget: '저예산',
    type: '카페',
    time: '2-4시간',
    gradient: _g1,
    shadowColor: Color(0xFF5AAAD8),
  ),
  _DateIdea(
    emoji: '🎳',
    title: '볼링 + 찜닭',
    description: '볼링 한 게임 하고 근처 찜닭 맛집에서 저녁 먹기. 볼링 진 사람이 계산!',
    budget: '중간',
    type: '활동',
    time: '반나절',
    gradient: _g2,
    shadowColor: Color(0xFF5EBF8A),
  ),
  _DateIdea(
    emoji: '🍣',
    title: '스시 오마카세',
    description: '작은 바 스타일 오마카세에서 코스 즐기기. 셰프가 내어주는 대로 먹으면서 대화하기 딱 좋아요.',
    budget: '중간',
    type: '식사',
    time: '2시간',
    gradient: _g3,
    shadowColor: Color(0xFFFF7B9C),
  ),
  _DateIdea(
    emoji: '🎭',
    title: '소극장 공연 관람',
    description: '홍대나 대학로의 작은 뮤지컬 또는 연극 관람. 끝나고 감상 나누며 근처 카페 들르기.',
    budget: '중간',
    type: '문화',
    time: '반나절',
    gradient: _g5,
    shadowColor: Color(0xFFB67DFF),
  ),
  _DateIdea(
    emoji: '🏊',
    title: '워터파크 & 찜질방',
    description: '종일 물놀이하고 찜질방에서 식혜 마시면서 구워먹기. 체력 소진 보장.',
    budget: '중간',
    type: '활동',
    time: '하루',
    gradient: _g1,
    shadowColor: Color(0xFF5AAAD8),
  ),
  _DateIdea(
    emoji: '🛹',
    title: '성수동 팝업 투어',
    description: '성수동이나 홍대에서 팝업 스토어 돌아다니기. 예쁜 곳 찾아 사진 많이 찍어요.',
    budget: '중간',
    type: '야외',
    time: '반나절',
    gradient: _g4,
    shadowColor: Color(0xFFFFC234),
  ),
  _DateIdea(
    emoji: '🍕',
    title: '이탈리안 디너',
    description: '파스타 & 피자 맛집에서 와인 한 잔과 함께 저녁. 캔들 있는 분위기 있는 곳 찾아보세요.',
    budget: '중간',
    type: '식사',
    time: '2시간',
    gradient: _g3,
    shadowColor: Color(0xFFFF7B9C),
  ),
  _DateIdea(
    emoji: '🎡',
    title: '유람선 야경',
    description: '한강 유람선 타고 야경 감상. 저녁 7-8시 타면 노을이랑 야경 둘 다 볼 수 있어요.',
    budget: '중간',
    type: '야외',
    time: '2시간',
    gradient: _g1,
    shadowColor: Color(0xFF5AAAD8),
  ),
  _DateIdea(
    emoji: '🏨',
    title: '도심 호캉스',
    description: '시내 호텔에서 1박. 루프탑 수영장 있으면 더 좋아요. 아무것도 안 하고 쉬는 여행.',
    budget: '럭셔리',
    type: '실내',
    time: '하루',
    gradient: _g5,
    shadowColor: Color(0xFFB67DFF),
  ),
  _DateIdea(
    emoji: '✈️',
    title: '제주도 1박2일',
    description: '비행기 타고 제주. 렌터카 빌려서 오름 올라가고, 흑돼지 먹고, 애월 카페 투어.',
    budget: '럭셔리',
    type: '야외',
    time: '하루',
    gradient: _g2,
    shadowColor: Color(0xFF5EBF8A),
  ),
  _DateIdea(
    emoji: '🎿',
    title: '스키장 당일치기',
    description: '얼리버드 패스 예매하고 새벽 버스 타고 출발. 슬로프 내려오는 재미 + 온돌방 라면.',
    budget: '럭셔리',
    type: '활동',
    time: '하루',
    gradient: _g1,
    shadowColor: Color(0xFF5AAAD8),
  ),
  _DateIdea(
    emoji: '🎡',
    title: '놀이공원 하루',
    description: '롯데월드나 에버랜드에서 하루 종일. 무서운 거 먼저 타고 야간 퍼레이드 보면서 마무리.',
    budget: '럭셔리',
    type: '활동',
    time: '하루',
    gradient: _g3,
    shadowColor: Color(0xFFFF7B9C),
  ),
  _DateIdea(
    emoji: '💆',
    title: '스파 & 마사지',
    description: '커플 마사지 패키지 예약하고 종일 힐링. 찜질방도 추가하면 완벽한 힐링 데이.',
    budget: '럭셔리',
    type: '실내',
    time: '반나절',
    gradient: _g4,
    shadowColor: Color(0xFFFFC234),
  ),
  _DateIdea(
    emoji: '🍽️',
    title: '파인다이닝',
    description: '한 번쯤은 제대로 된 파인다이닝에서 코스 요리. 드레스코드 맞춰 입고 특별한 밤.',
    budget: '럭셔리',
    type: '식사',
    time: '2-3시간',
    gradient: _g5,
    shadowColor: Color(0xFFB67DFF),
  ),
];
