import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';
import '../../../widgets/game_menu.dart';

const int kTelepathyQuestionsPerRound = 5;

class TelepathyQuestion {
  final String category;
  final String question;
  final List<String> options;

  const TelepathyQuestion({
    required this.category,
    required this.question,
    required this.options,
  });
}

const List<TelepathyQuestion> kTelepathyQuestions = [
  // 🍲 음식 & 야식 (2선택 / 4선택 / 6선택)
  TelepathyQuestion(
    category: '음식 🍜',
    question: '중식 먹을 때 나의 단골 선택은?',
    options: ['짜장면 🥢', '짬뽕 🌶️'],
  ),
  TelepathyQuestion(
    category: '음식 🍗',
    question: '치킨 파 중에서 내가 선호하는 파는?',
    options: ['후라이드 🍗', '양념치킨 🍯', '간장치킨 🧄', '시즈닝/뿌링클 ✨'],
  ),
  TelepathyQuestion(
    category: '음식 🍕',
    question: '오늘 밤 야식으로 가장 땡기는 메뉴는?',
    options: ['치킨 🍗', '피자 🍕', '족발/보쌈 🐷', '삼겹살/구이 🥩', '떡볶이 🌶️', '라면/분식 🍜'],
  ),
  TelepathyQuestion(
    category: '음식 ☕',
    question: '얼죽아 vs 쪄죽따, 당신의 선택은?',
    options: ['아이스 아메리카노 🧊', '따뜻한 아메리카노 ☕'],
  ),
  TelepathyQuestion(
    category: '음식 🍦',
    question: '디저트 카페에 갔을 때 더 선호하는 메뉴는?',
    options: ['케이크 🍰', '아이스크림 🍦', '빙수 🍧', '빵/베이커리 🥐'],
  ),
  TelepathyQuestion(
    category: '음식 🍔',
    question: '패스트푸드 최애 브랜드는?',
    options: ['맥도날드 🍔', '버거킹 👑', '롯데리아 🍟', '맘스터치 🍗', 'KFC 🍗', '노브랜드버거 🟡'],
  ),

  // ✈️ 데이트 & 여행 (2~6선택)
  TelepathyQuestion(
    category: '데이트 💖',
    question: '현재 시점 가고 싶은 데이트 장소는?',
    options: ['보드게임 카페 🎲', '영화관 🍿', '코인 노래방 🎤', '대형 쇼핑몰 🛍️', '맛집 탐방 🍱', 'Atmosphere 분위기 술집 🍸'],
  ),
  TelepathyQuestion(
    category: '데이트 🌳',
    question: '주말 데이트 스타일 선호도는?',
    options: ['야외 액티비티/공원 산책 🌳', '실내 카페/영화 힐링 ☕'],
  ),
  TelepathyQuestion(
    category: '여행 🏖️',
    question: '힐링 여행을 떠난다면 휴양지 vs 관광지?',
    options: ['바다 오션뷰 휴양지 🌊', '볼거리 많은 이국적 관광지 🏰'],
  ),
  TelepathyQuestion(
    category: '여행 🏕️',
    question: '숙소 취향 최고의 선택은?',
    options: ['오성급 호캉스 🏨', '감성 글램핑/캠핑 🏕️', '독채 풀빌라 🏊', '아늑한 게스트하우스 🏡'],
  ),

  // ❄️ 계절 & 날씨 (2선택 / 4선택)
  TelepathyQuestion(
    category: '계절 🌸',
    question: '내가 평소 가장 좋아하는 계절은?',
    options: ['봄 🌸', '여름 🌿', '가을 🍁', '겨울 ❄️'],
  ),
  TelepathyQuestion(
    category: '계절 🍂',
    question: '현 시점 가장 기대되는 계절은?',
    options: ['봄 🌸', '여름 🌿', '가을 🍁', '겨울 ❄️'],
  ),
  TelepathyQuestion(
    category: '날씨 ☔',
    question: '창밖 날씨 취향은?',
    options: ['햇살 쨍쨍한 맑은 날 ☀️', '촉촉하게 비 오는 날 ☔'],
  ),
  TelepathyQuestion(
    category: '날씨 🌨️',
    question: '겨울철 날씨 선호는?',
    options: ['눈 내리는 로맨틱한 날 ☃️', '상쾌하고 구름 없는 맑은 날 🌤️'],
  ),

  // 🎬 문화 & 취미 (2~6선택)
  TelepathyQuestion(
    category: '문화 🎬',
    question: '주말에 집에서 정주행하고 싶은 장르는?',
    options: ['로맨스/코미디 💖', '스릴러/공포 😱', 'SF/액션 🍿', '예능/토크쇼 😆', '다큐멘터리/지식 🧠', '애니메이션 🎨'],
  ),
  TelepathyQuestion(
    category: '취미 🎧',
    question: '평소 더 자주 듣는 음악 취향은?',
    options: ['감성 발라드 🎵', '신나는 댄스/아이돌 💃', '힙합/알앤비 🎧', '잔잔한 인디/Lofi ☕'],
  ),
  TelepathyQuestion(
    category: '취미 🎮',
    question: '휴식 시간에 더 하고 싶은 것은?',
    options: ['게임 한 판 하기 🎮', '유튜브/숏폼 시청 📱'],
  ),
  TelepathyQuestion(
    category: '문화 📚',
    question: '휴일에 여유가 생기면 책 읽기 vs 영화 보기?',
    options: ['마음의 양식 책 읽기 📚', '몰입감 넘치는 영화 보기 🎬'],
  ),

  // 🐾 라이프스타일 & 취향 (2~6선택)
  TelepathyQuestion(
    category: '일상 🐶',
    question: '귀여운 동물을 고른다면 강아지 vs 고양이?',
    options: ['댕댕이 강아지 🐶', '냥냥이 고양이 🐱'],
  ),
  TelepathyQuestion(
    category: '일상 ⏰',
    question: '나의 라이프스타일 패턴은?',
    options: ['부지런한 아침형 인간 🌅', '자유로운 밤형 인간 🌙'],
  ),
  TelepathyQuestion(
    category: '일상 📱',
    question: '연락할 때 내가 편한 방식은?',
    options: ['실시간 텍스트 카톡 💬', '목소리 들리는 전화 📞'],
  ),
  TelepathyQuestion(
    category: '일상 🏠',
    question: '주말에 완벽한 휴식이란?',
    options: ['하루 종일 집콕 침대 🛌', '밖에서 사람 만나며 에너징 🕺'],
  ),
  TelepathyQuestion(
    category: '선물 🎁',
    question: '생일 선물로 받고 싶은 것은?',
    options: ['실용적인 전자기기 📱', '마음 담긴 정성 선물 💌', '취향저격 패션/뷰티 👗', '맛있는 고급 식사권 🍽️'],
  ),
  TelepathyQuestion(
    category: '취향 🚗',
    question: '드라이브를 갈 때 더 좋은 곳은?',
    options: ['탁 트인 해안 도로 🌊', '푸르른 산길/숲길 🌲'],
  ),

  // 밸런스 & 심리전 (2~4선택)
  TelepathyQuestion(
    category: '밸런스 ⚖️',
    question: '다시 태어난다면 외모천재 vs 재력천재?',
    options: ['얼굴 천재 외모 🌟', '통장빵빵 재력 💰'],
  ),
  TelepathyQuestion(
    category: '밸런스 🚀',
    question: '초능력을 가질 수 있다면 타임머신 vs 순간이동?',
    options: ['시간 이동 타임머신 ⏳', '원하는 곳 순간이동 🌀'],
  ),
  TelepathyQuestion(
    category: '밸런스 🍔',
    question: '평생 하나만 먹어야 한다면 밥 vs 빵?',
    options: ['든든한 밥 🍚', '고소한 빵 🍞'],
  ),
  TelepathyQuestion(
    category: '밸런스 🗣️',
    question: '대화할 때 나의 보편적인 스타일은?',
    options: ['경청하고 공감하는 편 👂', '의견 내고 이끄는 편 🗣️'],
  ),
  TelepathyQuestion(
    category: '데이트 🎟️',
    question: '놀이동산에 갔을 때 메인 목표는?',
    options: ['무서운 놀이기구 전부 탑승 🎢', '머리띠 쓰고 인생샷 찍기 📸', '맛있는 군것질 탐방 츄러스 🍿', '퍼레이드 감상 🎠'],
  ),
  TelepathyQuestion(
    category: '일상 🛋️',
    question: '집에 있을 때 내 위치는?',
    options: ['침대 위 🛌', '소파 위 🛋️', '책상 앞 💻', '바닥 🧘'],
  ),
];

class TelepathyScreen extends StatefulWidget {
  const TelepathyScreen({super.key});

  @override
  State<TelepathyScreen> createState() => _TelepathyScreenState();
}

class _TelepathyScreenState extends State<TelepathyScreen> {
  final _socket = SocketService();
  String? _myChoice;
  bool _waiting = false;
  int _questionIndex = 0;
  int _round = 0;
  int _roundSuccessCount = 0;
  bool _roundComplete = false;
  late List<TelepathyQuestion> _roundQuestions;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
    _roundQuestions = _pickRoundQuestions(_socket.roomCode ?? 'default', _round);
  }

  @override
  void dispose() {
    _socket.removeListener(_rebuild);
    super.dispose();
  }

  // Both partners derive the same 5-question round independently from the
  // room code + round number, so they see identical questions in the same
  // order without any server-side round state.
  List<TelepathyQuestion> _pickRoundQuestions(String room, int round) {
    final base = room.codeUnits.fold(0, (a, b) => a + b);
    final seed = base * 1000003 + round;
    final pool = List<TelepathyQuestion>.from(kTelepathyQuestions)
      ..shuffle(math.Random(seed));
    return pool.take(kTelepathyQuestionsPerRound).toList();
  }

  void _rebuild() {
    if (!mounted) return;
    setState(() {
      _waiting = _socket.telepathySuccess == null && _myChoice != null;
    });
  }

  TelepathyQuestion get _currentQ => _roundQuestions[_questionIndex];

  void _pick(String opt) {
    if (_waiting) return;
    setState(() {
      _myChoice = opt;
      _waiting = true;
    });
    _socket.playTelepathy(opt, _currentQ.options);
  }

  void _nextQuestion() {
    final wasSuccess = _socket.telepathySuccess == true;
    setState(() {
      if (wasSuccess) _roundSuccessCount++;
      if (_questionIndex + 1 >= _roundQuestions.length) {
        _roundComplete = true;
      } else {
        _questionIndex++;
      }
      _myChoice = null;
      _waiting = false;
    });
    _socket.telepathySuccess = null;
    _socket.telepathySelected = null;
    _socket.telepathyChoices = null;
  }

  void _startNewRound() {
    setState(() {
      _round++;
      _roundQuestions = _pickRoundQuestions(_socket.roomCode ?? 'default', _round);
      _questionIndex = 0;
      _roundSuccessCount = 0;
      _roundComplete = false;
      _myChoice = null;
      _waiting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final success = _socket.telepathySuccess;
    final selected = _socket.telepathySelected;
    final choices = _socket.telepathyChoices;
    final q = _currentQ;

    return GameScaffold(
      title: '🧠 텔레파시',
      actions: [const GameMenuButton()],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // 주제 카테고리 태그 + 문제 질문
            if (!_roundComplete) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${q.category}  (문제 ${_questionIndex + 1}/$kTelepathyQuestionsPerRound)',
                  style: GoogleFonts.notoSans(
                    color: kPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                q.question,
                style: GoogleFonts.notoSans(
                  color: kText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
            ],

            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_roundComplete) ...[
                        _buildRoundSummary(),
                      ] else if (success != null) ...[
                        _buildResult(success, selected, choices),
                        const SizedBox(height: 28),
                        _ResetBtn(
                          onTap: _nextQuestion,
                          label: _questionIndex + 1 >= _roundQuestions.length
                              ? '라운드 결과 보기'
                              : '다음 문제 풀어보기',
                        ),
                      ] else if (_waiting) ...[
                        const _WaitWidget(),
                        const SizedBox(height: 20),
                        if (_myChoice != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: kPrimary.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              '내 선택: $_myChoice',
                              style: GoogleFonts.notoSans(
                                color: kPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ] else ...[
                        Text(
                          '상대방과 통할 것 같은 하나를 골라보세요!',
                          style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        _buildOptionsLayout(q.options),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsLayout(List<String> options) {
    if (options.length == 2) {
      return Column(
        children: options.map((opt) => _buildOptionButton(opt, height: 60, fontSize: 17)).toList(),
      );
    } else if (options.length <= 4) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.1,
        physics: const NeverScrollableScrollPhysics(),
        children: options.map((opt) => _buildOptionCard(opt, fontSize: 15)).toList(),
      );
    } else {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
        physics: const NeverScrollableScrollPhysics(),
        children: options.map((opt) => _buildOptionCard(opt, fontSize: 14)).toList(),
      );
    }
  }

  Widget _buildOptionButton(String opt, {required double height, required double fontSize}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _pick(opt),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              opt,
              style: GoogleFonts.notoSans(
                color: kText,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(String opt, {required double fontSize}) {
    return GestureDetector(
      onTap: () => _pick(opt),
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              opt,
              style: GoogleFonts.notoSans(
                color: kText,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResult(
    bool success,
    String? selected,
    Map<String, String>? choices,
  ) {
    return Column(
      children: [
        Text(success ? '✨' : '💔', style: const TextStyle(fontSize: 64)),
        const SizedBox(height: 10),
        Text(
          success ? '텔레파시 성공!' : '아쉽게 통하지 않았어요',
          style: GoogleFonts.notoSans(
            color: success ? kSuccess : kError,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        if (success && selected != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: kSuccess.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '둘 다 "$selected" 선택!',
              style: GoogleFonts.notoSans(
                color: kSuccess,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ] else if (!success && choices != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              children: choices.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_socket.presenceNicknames[e.key] ?? e.key}: ',
                        style: GoogleFonts.notoSans(
                            color: kTextMuted, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        e.value,
                        style: GoogleFonts.notoSans(
                            color: kText, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRoundSummary() {
    return Column(
      children: [
        const Text('🎉', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 10),
        Text(
          '라운드 완료!',
          style: GoogleFonts.notoSans(
            color: kText,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            '$kTelepathyQuestionsPerRound문항 중 $_roundSuccessCount개 텔레파시 성공!',
            style: GoogleFonts.notoSans(
              color: kPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 28),
        _ResetBtn(onTap: _startNewRound, label: '새 라운드 시작'),
      ],
    );
  }
}

class _WaitWidget extends StatelessWidget {
  const _WaitWidget();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(strokeWidth: 3, color: kPrimary),
        ),
        const SizedBox(height: 16),
        Text(
          '상대방 선택 대기 중...',
          style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 16),
        ),
      ],
    );
  }
}

class _ResetBtn extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  const _ResetBtn({required this.onTap, this.label = '다음 문제 풀어보기'});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }
}

