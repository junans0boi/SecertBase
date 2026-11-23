/// 마주 열기: 오늘의 질문 카드. 서버가 두 사람이 모두 답하기 전에는
/// 상대 답변 본문을 내려주지 않으므로 [partnerBody]는 열림 상태에서만 있다.
enum TwoAnswerStatus {
  /// 내가 아직 답하지 않았다(상대는 답했을 수도 있다).
  myTurn,

  /// 나는 답했고 상대를 기다린다.
  waiting,

  /// 둘 다 답해서 열렸다.
  open;

  static TwoAnswerStatus parse(Object? value) => switch ('$value') {
    'waiting' => TwoAnswerStatus.waiting,
    'open' => TwoAnswerStatus.open,
    _ => TwoAnswerStatus.myTurn,
  };
}

class TwoAnswerCard {
  final int id;
  final String businessDate;
  final String category;
  final String question;
  final TwoAnswerStatus status;
  final String? myBody;
  final bool partnerAnswered;
  final String? partnerBody;
  final int streak;

  const TwoAnswerCard({
    required this.id,
    required this.businessDate,
    required this.category,
    required this.question,
    required this.status,
    this.myBody,
    this.partnerAnswered = false,
    this.partnerBody,
    this.streak = 0,
  });

  bool get isOpen => status == TwoAnswerStatus.open;

  factory TwoAnswerCard.fromJson(Map<String, dynamic> json) {
    final mine = json['my_answer'];
    final partner = json['partner_answer'];
    return TwoAnswerCard(
      id: int.tryParse('${json['id']}') ?? 0,
      businessDate: '${json['business_date'] ?? ''}',
      category: '${json['category'] ?? ''}',
      question: '${json['question'] ?? ''}',
      status: TwoAnswerStatus.parse(json['status']),
      myBody: mine is Map ? '${mine['body']}' : null,
      partnerAnswered: json['partner_answered'] == true,
      partnerBody: partner is Map ? '${partner['body']}' : null,
      streak: int.tryParse('${json['streak'] ?? 0}') ?? 0,
    );
  }
}

class TwoAnswerHistoryPage {
  final List<TwoAnswerCard> items;
  final int? nextCursor;

  const TwoAnswerHistoryPage({required this.items, this.nextCursor});
}

/// 카테고리 키 → 화면에 보여줄 이름.
String twoAnswerCategoryLabel(String key) => switch (key) {
  'daily' => '일상',
  'memory' => '추억',
  'place' => '장소',
  'future' => '미래',
  'play' => '가벼운 놀이',
  _ => '오늘의 질문',
};
