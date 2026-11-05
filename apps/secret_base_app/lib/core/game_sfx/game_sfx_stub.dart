import 'dart:typed_data';

/// 웹이 아닌 환경(테스트 포함): 소리를 내지 않는다.
class GameSfxBackend {
  bool get supported => false;

  String prepare(Uint8List wav) => '';

  void play(String handle, double volume) {}
}
