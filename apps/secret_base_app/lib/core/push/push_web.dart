import 'dart:convert';
import 'dart:js_interop';
import 'package:firebase_core/firebase_core.dart';
import 'push_target.dart';

@JS('secretBasePush.initialize')
external JSPromise<JSBoolean> _initialize(
  JSString config,
  JSString vapid,
  JSFunction onOpened,
);
@JS('secretBasePush.getToken')
external JSPromise<JSString?> _getToken();
@JS('secretBasePush.permissionGranted')
external JSBoolean _permissionGranted();
@JS('secretBasePush.requestPermission')
external JSPromise<JSBoolean> _requestPermission();

Future<void> initialize(
  FirebaseOptions options,
  String vapid,
  void Function(PushTarget) onOpened,
) async {
  final callback = ((JSString payload) {
    final target = PushTarget.fromPayload(payload.toDart);
    if (target != null) onOpened(target);
  }).toJS;
  final configured = await _initialize(
    jsonEncode({
      'apiKey': options.apiKey,
      'appId': options.appId,
      'messagingSenderId': options.messagingSenderId,
      'projectId': options.projectId,
    }).toJS,
    vapid.toJS,
    callback,
  ).toDart;
  if (!configured.toDart) throw StateError('Firebase web config missing');
}

Future<String?> getToken() async => (await _getToken().toDart)?.toDart;
Future<bool> permissionGranted() async => _permissionGranted().toDart;
Future<bool> requestPermission() async =>
    (await _requestPermission().toDart).toDart;
// Web SDK exposes no refresh event. Re-read periodically; the service dedupes.
Stream<String> get onTokenRefresh =>
    Stream<void>.periodic(const Duration(hours: 6))
        .asyncMap((_) async {
          try {
            return await permissionGranted() ? await getToken() : null;
          } catch (_) {
            return null;
          }
        })
        .where((token) => token != null)
        .cast<String>();
