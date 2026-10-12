import 'package:flutter/material.dart';
import '../today_api.dart';
import '../../screens/home/today_loop_viewer.dart';

/// Load real Today Loop state for a tap, including one received at cold start.
class PushTodayRoute extends StatefulWidget {
  const PushTodayRoute({super.key, required this.api});
  final TodayApi api;
  @override
  State<PushTodayRoute> createState() => _PushTodayRouteState();
}

class _PushTodayRouteState extends State<PushTodayRoute> {
  late Future<TodayState> _state;
  @override
  void initState() {
    super.initState();
    _state = widget.api.fetchState();
  }

  @override
  void dispose() {
    widget.api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TodayState>(
    future: _state,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return TodayLoopViewer(
          state: snapshot.data!,
          baseUrl: widget.api.baseUrl,
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('오늘의 루프')),
        body: Center(
          child: snapshot.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('오늘의 루프를 불러오지 못했어요.'),
                    TextButton(
                      onPressed: () =>
                          setState(() => _state = widget.api.fetchState()),
                      child: const Text('다시 시도'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}
