import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/push/local_notification_service.dart';
import 'package:secret_base_app/core/push/push_target.dart';

class _Device implements LocalNotificationDevice {
  void Function(String)? tap;
  String? payload;
  @override
  Future<String?> initialize(void Function(String) onTap) async {
    tap = onTap;
    return '{"screen":"moment_draft","draft_id":"cold-draft"}';
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    this.payload = payload;
  }
}

void main() {
  test(
    'upload failure opens the saved draft without Firebase configuration',
    () async {
      final device = _Device();
      final service = LocalNotificationService(device: device);
      await service.start();
      expect(pendingPushTarget.value?.draftId, 'cold-draft');
      await service.showUploadFailure('draft / 42');
      device.tap!(device.payload!);
      expect(pendingPushTarget.value?.screen, 'moment_draft');
      expect(pendingPushTarget.value?.draftId, 'draft / 42');
      pendingPushTarget.value = null;
    },
  );
}
