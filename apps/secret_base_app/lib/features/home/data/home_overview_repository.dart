import '../../../core/auth_service.dart';
import '../../../core/http/api_client.dart';
import '../../../core/today_api.dart';
import '../domain/home_overview.dart';

class HomeRepositoryException implements Exception {
  final Set<HomeSection> failedSections;

  const HomeRepositoryException(this.failedSections);

  @override
  String toString() => 'HomeRepositoryException($failedSections)';
}

class HomeOverviewRepository {
  final ApiClient? _apiClient;
  final Future<TodayState> Function()? _todayStateLoader;

  HomeOverviewRepository({
    required ApiClient apiClient,
    Future<TodayState> Function()? todayStateLoader,
  }) : _apiClient = apiClient,
       _todayStateLoader = todayStateLoader;

  HomeOverviewRepository.forAuth(
    AuthService auth, {
    Future<TodayState> Function()? todayStateLoader,
  }) : _apiClient = auth.apiClient,
       _todayStateLoader =
           todayStateLoader ??
           (() async {
             final api = TodayApi(
               baseUrl: auth.baseUrl,
               token: auth.token ?? '',
               apiClient: auth.apiClient,
             );
             return api.fetchState();
           });

  HomeOverviewRepository.fake() : _apiClient = null, _todayStateLoader = null;

  Future<HomeOverview> fetch() async {
    final api = _apiClient;
    if (api == null) {
      throw StateError('A real HomeOverviewRepository needs an ApiClient');
    }

    final failedSections = <HomeSection>{};
    HomeCoupleInfo? couple;
    HomeMemoryCard? memoryCard;
    var memoryCardTotal = 0;
    HomeAssessmentStatus? assessmentStatus;
    TodayState? todayState;

    await Future.wait<void>([
      () async {
        try {
          couple = await _loadCouple(api);
        } catch (_) {
          failedSections.add(HomeSection.couple);
        }
      }(),
      () async {
        try {
          final value = await _loadMemory(api);
          memoryCard = value.card;
          memoryCardTotal = value.totalCount;
        } catch (_) {
          failedSections.add(HomeSection.memory);
        }
      }(),
      () async {
        try {
          assessmentStatus = await _loadAssessments(api);
        } catch (_) {
          failedSections.add(HomeSection.assessments);
        }
      }(),
      () async {
        try {
          todayState = await _loadToday();
        } catch (_) {
          failedSections.add(HomeSection.today);
        }
      }(),
    ]);

    if (failedSections.length == HomeSection.values.length) {
      throw HomeRepositoryException(failedSections);
    }

    return HomeOverview(
      couple: couple,
      memoryCard: memoryCard,
      memoryCardTotal: memoryCardTotal,
      assessmentStatus: assessmentStatus,
      todayState: todayState,
      failedSections: failedSections,
    );
  }

  Future<HomeCoupleInfo> _loadCouple(ApiClient api) async {
    final body = _jsonObject(await api.getJson('/api/couple/info'));
    if (body['ok'] != true) throw const FormatException('Invalid couple info');
    return HomeCoupleInfo(
      partnerName: _optionalString(body['partnerName']),
      dDay: _optionalInt(body['dDay']),
      startDate: _optionalString(body['startDate']),
    );
  }

  Future<_MemoryResult> _loadMemory(ApiClient api) async {
    final body = _jsonObject(await api.getJson('/api/retention/memory-card'));
    if (body['ok'] != true) throw const FormatException('Invalid memory card');
    final rawCard = body['card'];
    if (rawCard == null) return const _MemoryResult.empty();
    final card = _jsonObject(rawCard);
    return _MemoryResult(
      card: HomeMemoryCard(
        yearsAgo: _optionalInt(card['years_ago']) ?? 0,
        placeName: _optionalString(card['place_name']),
        caption: _optionalString(card['caption']),
        mediaUrl: _optionalString(card['media_url']),
      ),
      totalCount: _optionalInt(body['total_count']) ?? 0,
    );
  }

  Future<HomeAssessmentStatus> _loadAssessments(ApiClient api) async {
    final body = _jsonObject(
      await api.getJson('/api/relationship/assessments'),
    );
    if (body['ok'] != true || body['assessments'] is! List) {
      throw const FormatException('Invalid assessment catalog');
    }
    final assessments = (body['assessments'] as List).whereType<Map>().where(
      (assessment) => assessment['audience'] == 'individual',
    );
    if (assessments.any(
      (assessment) => assessment['completionStatus'] == 'in_progress',
    )) {
      return HomeAssessmentStatus.inProgress;
    }
    if (assessments.any(
      (assessment) => assessment['completionStatus'] == 'completed',
    )) {
      return HomeAssessmentStatus.resultReady;
    }
    return HomeAssessmentStatus.notStarted;
  }

  Future<TodayState> _loadToday() {
    final loader = _todayStateLoader;
    if (loader == null) {
      throw StateError('A Today state loader is required');
    }
    return loader();
  }

  Map<String, dynamic> _jsonObject(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Expected a JSON object');
  }

  int? _optionalInt(Object? value) {
    if (value is int) return value;
    return int.tryParse('$value');
  }

  String? _optionalString(Object? value) {
    final valueAsString = value == null ? '' : '$value'.trim();
    return valueAsString.isEmpty ? null : valueAsString;
  }
}

class _MemoryResult {
  final HomeMemoryCard? card;
  final int totalCount;

  const _MemoryResult({required this.card, required this.totalCount});

  const _MemoryResult.empty() : card = null, totalCount = 0;
}
