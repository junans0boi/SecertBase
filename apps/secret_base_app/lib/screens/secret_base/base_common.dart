import 'package:flutter/material.dart';

import '../../v2/v2.dart';
import '../archive/moment_loop_screen.dart';
import '../auth/partner_screen.dart';
import 'base_api.dart';
import 'couple_store.dart';

/// What every 비밀기지 tab needs from the hub.
class BaseHub {
  const BaseHub({required this.api, required this.couple});
  final BaseApi api;
  final CoupleStore couple;
}

/// Opens the 기록 composer from 비밀기지 / 홈 call sites.
///
/// TODO(moment-agent): once `MomentLoopScreen` gets its optional
/// "오늘의 순간 ON" named parameter, pass it here. Until then the screen opens
/// with its existing parameters only.
Future<void> openMomentComposer(BuildContext context) {
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => const MomentLoopScreen()));
}

Future<void> openPartnerScreen(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => const PartnerScreen()));

/// Shared loading / error / unpaired scaffolding for the hub tabs.
enum BaseLoad { loading, ready, error, unpaired }

BaseLoad loadStateFor(Object error) =>
    error is BaseApiException && error.unpaired
    ? BaseLoad.unpaired
    : BaseLoad.error;

Widget baseTabBody({
  required BuildContext context,
  required BaseLoad load,
  required VoidCallback onRetry,
  required Widget Function() ready,
  String errorTitle = '불러오지 못했어요',
  String errorBody = '네트워크를 확인하고 다시 시도해 주세요.',
  Widget? loading,
}) {
  switch (load) {
    case BaseLoad.loading:
      return loading ?? const V2SkeletonList(count: 4);
    case BaseLoad.error:
      return V2ErrorState(
        title: errorTitle,
        body: errorBody,
        retryLabel: '다시 불러오기',
        onRetry: onRetry,
      );
    case BaseLoad.unpaired:
      return V2EmptyState.unpaired(onAction: () => openPartnerScreen(context));
    case BaseLoad.ready:
      return ready();
  }
}

/// 2025.9.21 (일)-style rows share this card shell.
const baseListPadding = EdgeInsets.fromLTRB(
  V2Space.page,
  V2Space.x2,
  V2Space.page,
  V2Space.x10,
);
