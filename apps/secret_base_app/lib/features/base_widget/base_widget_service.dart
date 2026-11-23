import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/push/push_target.dart';
import '../home/domain/home_overview.dart';
import '../two_answers/domain/two_answer.dart';
import 'base_widget_data.dart';
import 'base_widget_store.dart';

/// 앱이 데이터를 갱신할 때 위젯에도 알리는 얇은 계층. 위젯 실패는 앱 동작에
/// 영향을 주지 않도록 모두 삼킨다. 로그인 전·로그아웃 뒤에는 켜지 않는다.
class BaseWidgetService {
  BaseWidgetService(this._store, {bool enabled = true}) : _enabled = enabled;

  /// 앱 전역 인스턴스. 홈 셸이 열릴 때 [enable]로 켜고, 로그아웃·연결 해제에서 [clear].
  static BaseWidgetService instance = BaseWidgetService(
    const HomeWidgetStore(),
    enabled: false,
  );

  final BaseWidgetStore _store;
  bool _enabled;
  BaseWidgetData _data = BaseWidgetData.empty();
  Map<String, Object?>? _lastWritten;
  StreamSubscription<Uri?>? _clickSub;

  void enable() => _enabled = true;

  /// 푸시 수신 시 앱이 가진 최신 값으로 위젯을 다시 채우도록 부르는 훅들.
  final List<Future<void> Function()> refreshers = [];

  /// 푸시를 받으면 등록된 갱신 함수를 실행한다(위젯 쪽 실패는 무시).
  void requestRefresh() {
    if (!_enabled) return;
    for (final refresh in List.of(refreshers)) {
      unawaited(refresh().catchError((_) {}));
    }
  }

  Future<void> onHome(HomeOverview overview) =>
      _apply(_data.withHome(overview));

  Future<void> onTwoAnswer(TwoAnswerCard card) =>
      _apply(_data.withTwoAnswer(card));

  Future<void> onUnread(int count) => _apply(_data.withUnread(count));

  Future<void> _apply(BaseWidgetData next) async {
    if (!_enabled) return;
    _data = next;
    final map = next.toStorage();
    if (mapEquals(map, _lastWritten)) return;
    _lastWritten = map;
    try {
      await _store.save(map);
    } catch (e) {
      _lastWritten = null;
      debugPrint('[BaseWidget] save failed: $e');
    }
  }

  /// 로그아웃·연결 해제: 위젯에 남은 Couple 정보를 모두 지운다.
  Future<void> clear() async {
    _enabled = false;
    _data = BaseWidgetData.empty();
    _lastWritten = null;
    try {
      await _store.clear();
    } catch (e) {
      debugPrint('[BaseWidget] clear failed: $e');
    }
  }

  /// 위젯 탭으로 앱이 열렸을 때 해당 화면으로 보낸다(알림 탭과 같은 경로).
  Future<void> listenForLaunches() async {
    if (_clickSub != null) return;
    try {
      _route(await HomeWidget.initiallyLaunchedFromHomeWidget());
      _clickSub = HomeWidget.widgetClicked.listen(_route, onError: (_) {});
    } catch (_) {
      // 플러그인이 없는 플랫폼(웹·테스트)에서는 조용히 건너뛴다.
    }
  }

  void _route(Uri? uri) {
    final target = BaseWidgetLinks.targetFor(uri);
    if (target != null) pendingPushTarget.value = target;
  }

  void dispose() {
    _clickSub?.cancel();
    _clickSub = null;
  }
}
