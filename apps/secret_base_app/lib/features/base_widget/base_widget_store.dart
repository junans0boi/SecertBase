import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// 위젯이 읽는 저장소. 테스트에서는 가짜로 바꾼다.
abstract class BaseWidgetStore {
  Future<void> save(Map<String, Object?> values);
  Future<void> clear();
}

/// 위젯 2종의 Android 클래스 이름(Kotlin AppWidgetProvider).
const baseWidgetProviders = ['DdayWidgetProvider', 'TodayWidgetProvider'];

class HomeWidgetStore implements BaseWidgetStore {
  const HomeWidgetStore();

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> save(Map<String, Object?> values) async {
    if (!_supported) return;
    for (final entry in values.entries) {
      await HomeWidget.saveWidgetData<Object>(entry.key, entry.value);
    }
    await _refresh();
  }

  @override
  Future<void> clear() async {
    if (!_supported) return;
    for (final key in const [
      'active',
      'dday',
      'ann_label',
      'ann_days',
      'qa_state',
      'loop_open',
      'unread',
      'as_of',
    ]) {
      await HomeWidget.saveWidgetData<Object>(key, null);
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    for (final name in baseWidgetProviders) {
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.secretbase.secret_base_app.$name',
      );
    }
  }
}
