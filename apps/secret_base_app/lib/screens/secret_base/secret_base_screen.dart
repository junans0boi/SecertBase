import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../v2/v2.dart';
import 'base_anniversaries_tab.dart';
import 'base_api.dart';
import 'base_common.dart';
import 'base_memories_tab.dart';
import 'base_postcard_screen.dart';
import 'base_rewards_tab.dart';
import 'couple_store.dart';

/// 비밀기지 허브: 보상 · 기념일 · 엽서 · 추억.
class SecretBaseScreen extends StatefulWidget {
  final String baseUrl;
  final Map<String, String> authHeaders;
  final http.Client? client;

  /// 0 보상, 1 기념일, 2 엽서, 3 추억.
  final int initialTab;

  const SecretBaseScreen({
    super.key,
    required this.baseUrl,
    required this.authHeaders,
    this.client,
    this.initialTab = 0,
  });

  @override
  State<SecretBaseScreen> createState() => _SecretBaseScreenState();
}

class _SecretBaseScreenState extends State<SecretBaseScreen> {
  static const _titles = ['보상', '기념일', '엽서', '추억'];

  late final BaseApi _api = BaseApi(
    baseUrl: widget.baseUrl,
    headers: widget.authHeaders,
    client: widget.client,
  );
  late final CoupleStore _couple = CoupleStore(_api);
  late final BaseHub _hub = BaseHub(api: _api, couple: _couple);
  late int _tab = widget.initialTab.clamp(0, 3);
  late final Set<int> _visited = {_tab};
  int _claimable = 0;

  @override
  void initState() {
    super.initState();
    _couple.load();
  }

  @override
  void dispose() {
    _couple.dispose();
    super.dispose();
  }

  void _select(int tab) => setState(() {
    _tab = tab;
    _visited.add(tab);
  });

  Widget _page(int i) => switch (i) {
    0 => BaseRewardsTab(
      hub: _hub,
      onClaimableChanged: (n) {
        if (mounted && n != _claimable) setState(() => _claimable = n);
      },
    ),
    1 => BaseAnniversariesTab(hub: _hub),
    2 => BasePostcardTab(hub: _hub),
    _ => BaseMemoriesTab(hub: _hub),
  };

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Scaffold(
        backgroundColor: V2Colors.bg,
        appBar: const V2Header(title: '비밀기지'),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                V2Space.page,
                V2Space.x1,
                V2Space.page,
                V2Space.x2,
              ),
              child: V2Segmented<int>(
                segments: [
                  for (var i = 0; i < _titles.length; i++)
                    V2Segment(
                      value: i,
                      label: i == 0 && _claimable > 0
                          ? '${_titles[i]} $_claimable'
                          : _titles[i],
                    ),
                ],
                selected: _tab,
                onChanged: _select,
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  for (var i = 0; i < 4; i++)
                    _visited.contains(i) ? _page(i) : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
