import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'push_target.dart';

/// Operating-system boundary, independent of Firebase and authentication.
abstract class LocalNotificationDevice {
  Future<String?> initialize(void Function(String) onTap);
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  });
}

class LocalNotificationService {
  LocalNotificationService({LocalNotificationDevice? device})
    : _device = device ?? _PluginDevice();
  static final instance = LocalNotificationService();
  final LocalNotificationDevice _device;
  Future<void>? _starting;
  bool _ready = false;

  Future<void> start() => _starting ??= _start();
  Future<void> _start() async {
    try {
      final initial = await _device.initialize(_open);
      _ready = true;
      if (initial != null) _open(initial);
    } catch (_) {
      // Unsupported desktop/browser notification plugins must not block startup.
      _starting = null;
    }
  }

  void _open(String payload) {
    final target = PushTarget.fromPayload(payload);
    if (target != null) pendingPushTarget.value = target;
  }

  Future<void> showUploadFailure(String draftId) => show(
    id: draftId.hashCode & 0x7fffffff,
    title: '기록을 올리지 못했어요',
    body: '임시저장한 기록을 열어 다시 시도해 주세요.',
    target: PushTarget(screen: 'moment_draft', draftId: draftId),
  );

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required PushTarget target,
  }) async {
    await start();
    if (!_ready) return;
    try {
      await _device.show(
        id: id,
        title: title,
        body: body,
        payload: target.toPayload(),
      );
    } catch (_) {
      /* Notification failure must not discard a saved draft. */
    }
  }
}

class _PluginDevice implements LocalNotificationDevice {
  final _plugin = FlutterLocalNotificationsPlugin();
  @override
  Future<String?> initialize(void Function(String) onTap) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Android local notifications only');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) onTap(response.payload!);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true
        ? launch?.notificationResponse?.payload
        : null;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) => _plugin.show(
    id: id,
    title: title,
    body: body,
    payload: payload,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'secret_base_default',
        '비밀기지 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}
