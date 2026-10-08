import '../../../core/today_api.dart';

enum HomeSection { couple, memory, assessments, today }

enum HomeAssessmentStatus { notStarted, inProgress, resultReady }

class HomeCoupleInfo {
  final String? partnerName;
  final int? dDay;
  final String? startDate;

  const HomeCoupleInfo({this.partnerName, this.dDay, this.startDate});
}

class HomeMemoryCard {
  final int yearsAgo;
  final String? placeName;
  final String? caption;
  final String? mediaUrl;

  const HomeMemoryCard({
    required this.yearsAgo,
    this.placeName,
    this.caption,
    this.mediaUrl,
  });
}

class HomeOverview {
  final HomeCoupleInfo? couple;
  final HomeMemoryCard? memoryCard;
  final int memoryCardTotal;
  final HomeAssessmentStatus? assessmentStatus;
  final TodayState? todayState;
  final Set<HomeSection> failedSections;

  HomeOverview({
    this.couple,
    this.memoryCard,
    this.memoryCardTotal = 0,
    this.assessmentStatus,
    this.todayState,
    Set<HomeSection> failedSections = const {},
  }) : failedSections = Set.unmodifiable(failedSections);

  bool get todayLoadFailed => failedSections.contains(HomeSection.today);

  bool get hasAnyData =>
      couple != null ||
      memoryCard != null ||
      assessmentStatus != null ||
      todayState != null;
}
