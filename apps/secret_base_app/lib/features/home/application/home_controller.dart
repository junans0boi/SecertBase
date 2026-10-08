import 'package:flutter/foundation.dart';

import '../data/home_overview_repository.dart';
import '../domain/home_overview.dart';

enum HomeStatus { idle, loading, ready, partial, failure }

class HomeState {
  final HomeStatus status;
  final HomeOverview? data;
  final Object? error;

  const HomeState({this.status = HomeStatus.idle, this.data, this.error});
}

class HomeController extends ChangeNotifier {
  final HomeOverviewRepository repository;
  HomeState _state = const HomeState();
  int _requestVersion = 0;
  bool _disposed = false;

  HomeController(this.repository);

  HomeState get state => _state;

  Future<void> load() => _run();

  Future<void> refresh() => _run();

  Future<void> _run() async {
    final version = ++_requestVersion;
    _setState(HomeState(status: HomeStatus.loading, data: _state.data));

    try {
      final data = await repository.fetch();
      if (version != _requestVersion) return;
      _setState(
        HomeState(
          status: data.failedSections.isEmpty
              ? HomeStatus.ready
              : HomeStatus.partial,
          data: data,
        ),
      );
    } catch (error) {
      if (version != _requestVersion) return;
      _setState(
        HomeState(status: HomeStatus.failure, data: _state.data, error: error),
      );
    }
  }

  void _setState(HomeState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
