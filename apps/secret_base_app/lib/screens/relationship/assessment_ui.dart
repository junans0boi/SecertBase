/// Rough completion time shown as "약 N분 · N문항".
int assessmentMinutes(int questionCount) =>
    questionCount <= 0 ? 1 : ((questionCount + 5) ~/ 6).clamp(1, 60);

String assessmentSizeLabel(int questionCount) =>
    '약 ${assessmentMinutes(questionCount)}분 · $questionCount문항';
