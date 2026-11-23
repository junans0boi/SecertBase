import 'package:flutter/widgets.dart';

import '../../features/two_answers/data/two_answers_repository.dart';
import '../../features/two_answers/presentation/two_answers_screen.dart';
import '../../screens/home/anniversaries_screen.dart';
import 'push_target.dart';

/// 기념일 D-1 / 마주 열기 푸시 탭 도착지. 이 파일이 다루지 않는 화면은 null.
Widget? pushReminderPage(
  PushTarget target, {
  required String baseUrl,
  required String? token,
}) {
  switch (target.screen) {
    case 'anniversary':
      return const AnniversariesScreen();
    case 'two_answers':
      if (token == null) return null;
      return TwoAnswersScreen(
        repository: HttpTwoAnswersRepository(baseUrl: baseUrl, token: token),
      );
  }
  return null;
}
