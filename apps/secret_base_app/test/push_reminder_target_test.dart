import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/push/push_reminder_route.dart';
import 'package:secret_base_app/core/push/push_target.dart';
import 'package:secret_base_app/features/two_answers/presentation/two_answers_screen.dart';
import 'package:secret_base_app/screens/home/anniversaries_screen.dart';

void main() {
  group('reminder push targets', () {
    test(
      'anniversary and two_answers payloads parse from data, payload and uri',
      () {
        for (final screen in ['anniversary', 'two_answers']) {
          expect(PushTarget.fromData({'screen': screen})?.screen, screen);
          expect(
            PushTarget.fromPayload(
              PushTarget(screen: screen).toPayload(),
            )?.screen,
            screen,
          );
          expect(
            PushTarget.fromUri(
              Uri.parse('https://x.test/#/?screen=$screen'),
            )?.screen,
            screen,
          );
        }
        expect(PushTarget.fromData({'screen': 'unknown_screen'}), isNull);
      },
    );

    test('anniversary tap opens the anniversaries screen', () {
      final page = pushReminderPage(
        const PushTarget(screen: 'anniversary'),
        baseUrl: 'http://x.test',
        token: 'jwt',
      );
      expect(page, isA<AnniversariesScreen>());
    });

    test('two_answers tap opens 마주 열기 and needs a signed-in token', () {
      expect(
        pushReminderPage(
          const PushTarget(screen: 'two_answers'),
          baseUrl: 'http://x.test',
          token: 'jwt',
        ),
        isA<TwoAnswersScreen>(),
      );
      expect(
        pushReminderPage(
          const PushTarget(screen: 'two_answers'),
          baseUrl: 'http://x.test',
          token: null,
        ),
        isNull,
      );
    });

    test('other screens are not handled here', () {
      expect(
        pushReminderPage(
          const PushTarget(screen: 'notes'),
          baseUrl: 'http://x.test',
          token: 'jwt',
        ),
        isNull,
      );
    });
  });
}
