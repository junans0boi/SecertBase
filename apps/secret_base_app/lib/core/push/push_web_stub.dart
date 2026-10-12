import 'package:firebase_core/firebase_core.dart';
import 'push_target.dart';

Future<void> initialize(
  FirebaseOptions options,
  String vapid,
  void Function(PushTarget) onOpened,
) async => throw UnsupportedError('web');
Future<String?> getToken() async => null;
Future<bool> permissionGranted() async => false;
Future<bool> requestPermission() async => false;
Stream<String> get onTokenRefresh => const Stream.empty();
