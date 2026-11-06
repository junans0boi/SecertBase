/// 업데이트 내역. 새 버전을 내면 목록 맨 위에 항목을 추가하고
/// `CHANGELOG.md`에도 같은 내용을 적는다.
class ChangelogEntry {
  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.title,
    required this.items,
  });

  final String version;
  final String date;
  final String title;
  final List<String> items;
}

const kChangelog = <ChangelogEntry>[
  ChangelogEntry(
    version: '2.0.0',
    date: '2026-11-06',
    title: '게임 2.0',
    items: [
      '블랙잭·도둑잡기·제로·해적 룰렛·패널티킥·원카드를 새로 만들었어요. 게임마다 어울리는 테마와 효과음, 연출이 들어갔어요.',
      '윷놀이·텔레파시·그림 맞히기·고스톱도 2.0으로 바뀌었어요. 고스톱 규칙을 바로잡고, 그림 맞히기는 실행 취소와 힌트가 생겼어요.',
      '탱크 대작전 2.0: 전차 4종, 무기 7종 이상, 보급 상자, 테마 맵 4종.',
      '텔레파시에 밸런스 질문 320개와 19+ 문제가 추가되어 여러 판을 해도 같은 질문이 나오지 않아요.',
      '다시 하기는 상대가 수락해야 시작되고, 이번 방 전적이 이어서 보여요.',
      '앱을 다시 켜거나 잠시 나갔다 와도 하던 판으로 돌아와요.',
      '더보기에 앱 정보(앱 버전, 업데이트 내역, 개발자 정보, 오픈소스 라이선스)가 생겼어요.',
      '불러오기 실패와 업로드 멈춤에서 스스로 복구하고, 회원 탈퇴 처리를 안정화했어요.',
    ],
  ),
  ChangelogEntry(
    version: '1.0.0',
    date: '2026-07-23',
    title: '첫 정식 릴리즈',
    items: ['MomentLoop, 비밀 지도, 함께 놀기 등 비밀기지의 첫 번째 정식 버전이에요.'],
  ),
];
