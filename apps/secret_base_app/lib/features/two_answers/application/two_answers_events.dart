import 'package:flutter/widgets.dart';

import '../../../core/socket_service.dart';

/// 서버가 활성 Couple 상대에게만 보내는 본문 없는 상태 이벤트.
const twoAnswersUpdatedEvent = 'two-answers:updated';

/// 이벤트 구독을 추상화해 테스트에서 소켓 없이 쓴다. 반환값은 구독 해제 함수.
typedef TwoAnswersEventSource = VoidCallback Function(VoidCallback onUpdated);

VoidCallback socketTwoAnswersEvents(VoidCallback onUpdated) {
  final socket = SocketService();
  void handler(Map<String, dynamic> _) => onUpdated();
  socket.addGameHandler(twoAnswersUpdatedEvent, handler);
  return () => socket.removeGameHandler(twoAnswersUpdatedEvent, handler);
}

/// 소켓 이벤트를 받거나 앱이 포그라운드로 돌아오면 [onRefresh]를 부른다.
/// 이벤트에는 본문이 없으므로 항상 서버에서 다시 조회한다.
class TwoAnswersRefresher extends StatefulWidget {
  final TwoAnswersEventSource? events;
  final VoidCallback onRefresh;
  final Widget child;

  const TwoAnswersRefresher({
    super.key,
    this.events,
    required this.onRefresh,
    required this.child,
  });

  @override
  State<TwoAnswersRefresher> createState() => _TwoAnswersRefresherState();
}

class _TwoAnswersRefresherState extends State<TwoAnswersRefresher>
    with WidgetsBindingObserver {
  VoidCallback? _unsubscribe;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _unsubscribe = (widget.events ?? socketTwoAnswersEvents)(
      () => widget.onRefresh(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.onRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unsubscribe?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
