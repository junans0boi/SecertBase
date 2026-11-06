import 'package:flutter/foundation.dart';

import '../../core/auth_service.dart';
import '../home/home_format.dart';
import 'base_api.dart';

/// The couple facts the 비밀기지 tabs share: partner name and first day.
class BaseCouple {
  const BaseCouple({this.partnerName, this.startDate});
  final String? partnerName;
  final DateTime? startDate;
}

/// Loads `/couple/info` once for the hub and saves a new first day.
/// [revision] increases after every successful start-date change so the
/// rewards and anniversaries tabs can recalculate.
class CoupleStore extends ChangeNotifier {
  CoupleStore(this.api);

  final BaseApi api;
  BaseCouple? couple;
  bool loading = false;
  bool unpaired = false;
  int revision = 0;
  bool _disposed = false;

  String get partnerName => couple?.partnerName ?? '짝꿍';

  String get myName {
    try {
      final user = AuthService().user;
      final name = '${user?['Nickname'] ?? user?['UserName'] ?? ''}'.trim();
      return name.isEmpty ? '나' : name;
    } catch (_) {
      return '나';
    }
  }

  Future<void> load() async {
    loading = true;
    _notify();
    try {
      final body = await api.get('/couple/info');
      couple = BaseCouple(
        partnerName: _string(body['partnerName']),
        startDate: parseDay(_string(body['startDate'])),
      );
      unpaired = false;
    } on BaseApiException catch (e) {
      unpaired = e.unpaired;
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Throws [BaseApiException] when the server refuses.
  Future<void> saveStartDate(DateTime day) async {
    await api.patch('/couple/info', {'start_date': isoDay(day)});
    couple = BaseCouple(partnerName: couple?.partnerName, startDate: day);
    revision++;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static String? _string(Object? v) {
    final s = v == null ? '' : '$v'.trim();
    return s.isEmpty ? null : s;
  }
}
