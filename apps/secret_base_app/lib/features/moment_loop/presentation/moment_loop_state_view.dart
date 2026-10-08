import 'package:flutter/widgets.dart';

import '../application/moment_loop_controller.dart';

/// Small presentation seam shared by the screen and future MomentLoop surfaces.
/// The feed itself stays in the existing screen while migration is incremental.
class MomentLoopStateView extends StatelessWidget {
  final MomentLoopState state;
  final Widget Function()? loading;
  final Widget Function(String message)? failure;
  final Widget child;

  const MomentLoopStateView({
    super.key,
    required this.state,
    required this.child,
    this.loading,
    this.failure,
  });

  @override
  Widget build(BuildContext context) {
    if (state.status == MomentLoopStatus.loading && state.moments.isEmpty) {
      return loading?.call() ?? const SizedBox.shrink();
    }
    if (state.status == MomentLoopStatus.failure && state.moments.isEmpty) {
      return failure?.call('${state.error ?? 'moment_loop_load_failed'}') ??
          child;
    }
    return child;
  }
}
