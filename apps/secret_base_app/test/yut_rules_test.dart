import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/ui/yut_board.dart';

void main() {
  test('백도 경로가 서버 규칙과 일치한다', () {
    expect(yutPreviousPosition(1, 0), 20);
    expect(yutPreviousPosition(20, 1), 19);
    expect(yutPreviousPosition(20, 27), 27);
  });
}
