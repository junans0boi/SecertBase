import 'dart:async';

import 'package:secret_base_app/screens/archive/map/secret_map.dart';

/// Applies to every test file: widget tests can't run the MapLibre platform
/// view or fetch the map style, so the map renders as a plain stand-in.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SecretMap.debugFake = true;
  await testMain();
}
