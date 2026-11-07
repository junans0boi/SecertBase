import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/app_theme.dart' show buildAppTheme;
import '../../core/auth_service.dart';
import '../../core/socket_service.dart';
import '../../v2/v2.dart';
import '../arcade/games/yut/yut_skin_shop.dart';
import 'gacha_screen.dart';
import 'inventory_tab.dart';
import 'shop_common.dart';

export 'shop_common.dart' show formatStatValue, statLabels, gradeOrder;

/// 상점: 상점 · 내 아이템 · 미션 · 쿠폰. 코인은 오른쪽 위 알약 한 곳에서만
/// 보여 주고, 누르면 "코인 얻는 법"이 열려요. 놀이 탭과 더보기 두 곳에서 열려요.
class ShopScreen extends StatefulWidget {
  final http.Client? client;
  final String? baseUrl;

  const ShopScreen({super.key, this.client, this.baseUrl});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _auth = AuthService();
  final _socket = SocketService();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _coupons = [];
  List<Map<String, dynamic>> _missions = [];
  Set<int> _ownedItemIds = {};
  Set<int> _equippedItemIds = {};
  int? _balance;
  int _tickets = 0;
  int _userLevel = 1;
  int _userXp = 0;
  int _xpNeeded = 100;
  bool _loading = true;
  bool _failed = false;
  int? _buyingItemId;
  String? _feedback;
  bool _feedbackError = false;
  int _tab = 0;
  String? _category;
  bool _claiming = false;

  late final http.Client _client;
  late final bool _ownsClient;

  @override
  void initState() {
    super.initState();
    _ownsClient = widget.client == null;
    _client = widget.client ?? http.Client();
    _socket.addListener(_onWallet);
    _load();
  }

  @override
  void dispose() {
    _socket.removeListener(_onWallet);
    if (_ownsClient) _client.close();
    super.dispose();
  }

  String get _baseUrl => widget.baseUrl ?? _socket.serverUrl ?? '';

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${_auth.token}',
    'Content-Type': 'application/json',
  };

  void _onWallet() {
    final b = _socket.walletBalance;
    if (mounted && b != null && b != _balance) setState(() => _balance = b);
  }

  Future<Map> _get(String path) async {
    final res = await _client.get(
      Uri.parse('$_baseUrl$path'),
      headers: _headers,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException('status ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final r = await Future.wait([
        _get('/api/shop/items'),
        _get('/api/wallet/balance'),
        _get('/api/shop/coupons'),
        _get('/api/shop/owned'),
        _get('/api/shop/equipped'),
        _get('/api/user/level'),
        _get('/api/missions'),
      ]);
      final owned = (r[3]['owned'] as List? ?? []).cast<Map<String, dynamic>>();
      final slots = (r[4]['slots'] as Map? ?? {}).values.toList();
      if (!mounted) return;
      setState(() {
        _items = (r[0]['items'] as List? ?? []).cast<Map<String, dynamic>>();
        _balance = (r[1]['balance'] as num?)?.toInt() ?? _balance;
        _coupons = (r[2]['coupons'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _ownedItemIds = owned.map((o) => (o['item_id'] as num).toInt()).toSet();
        _equippedItemIds = slots
            .map((s) => ((s as Map)['item_id'] as num).toInt())
            .toSet();
        if (r[5]['ok'] == true) {
          _userLevel = (r[5]['level'] as num?)?.toInt() ?? 1;
          _userXp = (r[5]['xp'] as num?)?.toInt() ?? 0;
          _xpNeeded = (r[5]['xpNeeded'] as num?)?.toInt() ?? 100;
          _tickets = (r[5]['tickets'] as num?)?.toInt() ?? 0;
        }
        _missions = (r[6]['missions'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  // ── Purchase ────────────────────────────────────────────────────────────────

  Future<void> _preview(Map<String, dynamic> item) async {
    final id = (item['id'] as num).toInt();
    final grade = item['grade'] as String? ?? 'B';
    final owned = _ownedItemIds.contains(id);
    final equipped = _equippedItemIds.contains(id);
    final price = (item['price'] as num?)?.toInt() ?? 0;
    final buying = _buyingItemId == id;
    final gachaOnly = const ['S', 'SS', 'SSS'].contains(grade);
    final balance = _balance ?? 0;
    final stats = (item['stats'] as List? ?? []).cast<Map<String, dynamic>>();
    final badge = ownershipChip(owned: owned, equipped: equipped);

    String label;
    VoidCallback? onTap;
    if (buying) {
      label = '구매 중...';
    } else if (equipped) {
      label = '장착 중';
    } else if (owned) {
      label = '보유 중';
    } else if (gachaOnly) {
      label = '뽑기에서만 얻을 수 있어요';
    } else if (balance < price) {
      label = '코인이 ${coinText(price - balance)} 모자라요';
    } else {
      label = '${coinText(price)} 코인으로 사기';
      onTap = () {
        Navigator.pop(context);
        _buy(item);
      };
    }

    await showV2Sheet<void>(
      context,
      title: item['name'] as String? ?? '',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ItemArt(game: item['game'], grade: grade, size: 88),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              GradeChip(grade: grade),
              ?badge,
            ],
          ),
          if ((item['description'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              item['description'] as String,
              textAlign: TextAlign.center,
              style: V2Text.body,
            ),
          ],
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('능력치', style: V2Text.bodyStrong),
            const SizedBox(height: 4),
            for (final s in stats)
              StatRow(
                statKey: '${s['key']}',
                value: num.tryParse('${s['value']}') ?? 0,
                grade: grade,
              ),
          ],
          if (onTap != null) ...[
            const SizedBox(height: 12),
            Text(
              '지금 코인 ${coinText(balance)} → ${coinText(balance - price)}',
              textAlign: TextAlign.center,
              style: V2Text.cap,
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            key: ValueKey('shop_purchase_button_${item['id']}'),
            child: V2Button(
              label: label,
              onPressed: onTap,
              variant: onTap == null
                  ? V2ButtonVariant.soft
                  : V2ButtonVariant.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buy(Map<String, dynamic> item) async {
    final id = (item['id'] as num).toInt();
    if (_buyingItemId != null) return;
    setState(() {
      _buyingItemId = id;
      _feedback = null;
    });
    try {
      final res = await _client.post(
        Uri.parse('$_baseUrl/api/shop/buy'),
        headers: _headers,
        body: jsonEncode({'item_id': item['id']}),
      );
      final body = jsonDecode(res.body) as Map;
      if (body['ok'] == true) {
        final newBalance = (body['new_balance'] as num?)?.toInt() ?? _balance;
        setState(() {
          _balance = newBalance;
          _feedback =
              '${item['name']}을 보관함에 넣었어요 · ${coinText(newBalance ?? 0)} 코인 남음';
          _feedbackError = false;
        });
        await _load();
      } else {
        setState(() {
          _feedback =
              '구매하지 못했어요 · ${shopReasonText(body['reason'] as String?)}';
          _feedbackError = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _feedback = '구매하지 못했어요 · 네트워크를 확인하고 다시 시도해 주세요.';
          _feedbackError = true;
        });
        // 응답을 못 받았을 수 있으니 실제 코인을 다시 읽어 와요.
        _load();
      }
    } finally {
      if (mounted) setState(() => _buyingItemId = null);
    }
  }

  // ── Coins guide / gacha ─────────────────────────────────────────────────────

  int get _claimableCount => _missions
      .where((m) => m['completed'] == true && m['claimed'] != true)
      .length;

  int get _claimableCoins => _missions
      .where((m) => m['completed'] == true && m['claimed'] != true)
      .fold<int>(0, (a, m) => a + ((m['rewardCoins'] as num?)?.toInt() ?? 0));

  Future<void> _showCoinGuide() {
    final claimable = _claimableCount;
    return showV2Sheet<void>(
      context,
      title: '코인 얻는 법',
      subtitle: '코인은 이 앱 안에서만 쓰는 포인트예요. 돈으로 살 수 없어요.',
      builder: (ctx) => V2List(
        children: [
          V2ListTile(
            icon: V2Icons.check,
            tone: V2Tone.ok,
            title: '미션 완료하고 받기',
            subtitle: claimable > 0
                ? '지금 받을 수 있는 보상이 $claimable개 있어요'
                : '매주 새 미션이 열려요',
            trailing: claimable > 0
                ? Text(
                    '+${coinText(_claimableCoins)}',
                    style: V2Text.bodyStrong,
                  )
                : null,
            showChevron: true,
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _tab = 2);
            },
          ),
          V2ListTile(
            icon: V2Icons.play,
            tone: V2Tone.sky,
            title: '놀이 하기',
            subtitle: '놀이에서 이기면 코인을 받아요',
          ),
        ],
      ),
    );
  }

  Future<void> _openGacha() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GachaScreen(
          client: _client,
          baseUrl: _baseUrl,
          balance: _balance ?? 0,
          onOpenCoinGuide: _showCoinGuide,
        ),
      ),
    );
    if (mounted) _load();
  }

  // ── Missions ────────────────────────────────────────────────────────────────

  Future<bool> _claimOne(int missionId) async {
    try {
      final res = await _client.post(
        Uri.parse('$_baseUrl/api/missions/$missionId/claim'),
        headers: _headers,
      );
      final body = jsonDecode(res.body) as Map;
      return body['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _claim(List<Map<String, dynamic>> missions) async {
    if (_claiming || missions.isEmpty) return;
    setState(() => _claiming = true);
    var coins = 0;
    var failed = 0;
    for (final m in missions) {
      if (await _claimOne((m['id'] as num).toInt())) {
        coins += (m['rewardCoins'] as num?)?.toInt() ?? 0;
      } else {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() => _claiming = false);
    if (failed == 0) {
      showV2Snack(context, '코인 ${coinText(coins)}개를 받았어요');
    } else {
      showV2Snack(
        context,
        '받지 못한 보상이 $failed개 있어요. 다시 시도해 주세요.',
        tone: V2Tone.err,
      );
    }
    _load();
  }

  // ── Coupons ─────────────────────────────────────────────────────────────────

  Future<void> _issueCoupon() async {
    final result = await showV2Sheet<(String, String)>(
      context,
      title: '쿠폰 만들기',
      builder: (_) => _CouponForm(balance: _balance ?? 0),
    );
    if (result == null || !mounted) return;
    try {
      final res = await _client.post(
        Uri.parse('$_baseUrl/api/shop/coupons/issue'),
        headers: _headers,
        body: jsonEncode({'title': result.$1, 'description': result.$2}),
      );
      final body = jsonDecode(res.body) as Map;
      if (!mounted) return;
      if (body['ok'] == true) {
        setState(
          () => _balance = (body['new_balance'] as num?)?.toInt() ?? _balance,
        );
        showV2Snack(context, '쿠폰을 보냈어요');
      } else {
        showV2Snack(
          context,
          body['reason'] == 'no_couple'
              ? '파트너와 연결하면 쿠폰을 보낼 수 있어요.'
              : '쿠폰을 보내지 못했어요. ${shopReasonText(body['reason'] as String?)}',
          tone: V2Tone.err,
        );
      }
    } catch (_) {
      if (mounted) {
        showV2Snack(
          context,
          '쿠폰을 보내지 못했어요. 네트워크를 확인하고 다시 시도해 주세요.',
          tone: V2Tone.err,
        );
      }
    }
  }

  Future<void> _redeemCoupon(Map<String, dynamic> coupon) async {
    final ok = await showV2Confirm(
      context,
      title: '${coupon['title']}을(를) 사용할까요?',
      message: '사용하면 되돌릴 수 없어요.',
      confirmLabel: '사용하기',
      cancelLabel: '취소',
    );
    if (!ok || !mounted) return;
    try {
      final res = await _client.post(
        Uri.parse('$_baseUrl/api/shop/coupons/redeem'),
        headers: _headers,
        body: jsonEncode({'coupon_id': coupon['id']}),
      );
      final body = jsonDecode(res.body) as Map;
      if (!mounted) return;
      if (body['ok'] == true) {
        showV2Snack(context, '쿠폰을 사용했어요');
        await _load();
      } else {
        showV2Snack(
          context,
          '쿠폰을 사용하지 못했어요. 이미 쓰였거나 기한이 지났을 수 있어요.',
          tone: V2Tone.err,
        );
      }
    } catch (_) {
      if (mounted) {
        showV2Snack(context, '쿠폰을 사용하지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final claimable = _claimableCount;
    return V2Theme(
      child: Scaffold(
        appBar: V2Header(
          title: '상점',
          actions: [
            CoinPill(balance: _balance, onTap: _showCoinGuide),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: V2Segmented<int>(
                segments: [
                  const V2Segment(value: 0, label: '상점'),
                  const V2Segment(value: 1, label: '내 아이템'),
                  V2Segment(
                    value: 2,
                    label: claimable > 0 ? '미션 $claimable' : '미션',
                  ),
                  const V2Segment(value: 3, label: '쿠폰'),
                ],
                selected: _tab,
                onChanged: (v) => setState(() => _tab = v),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(V2Space.page),
        child: V2SkeletonList(count: 4),
      );
    }
    if (_failed && _items.isEmpty) {
      return V2ErrorState(
        title: '상점을 열지 못했어요',
        body: '연결이 불안정한 것 같아요. 코인과 아이템은 그대로 안전해요.',
        onRetry: _load,
      );
    }
    return switch (_tab) {
      1 => InventoryTab(
        client: _client,
        baseUrl: widget.baseUrl,
        onBalanceChanged: _load,
        onOpenShop: () => setState(() => _tab = 0),
      ),
      2 => _missionsTab(),
      3 => _couponsTab(),
      _ => _shopTab(),
    };
  }

  Widget _shopTab() {
    final yutItems = _items
        .where((i) => i['game'] == 'yut' && i['slot'] != 'yut_piece')
        .toList();
    final onecardItems = _items.where((i) => i['game'] == 'onecard').toList();
    final showYut = _category == null || _category == 'yut';
    final showCard = _category == null || _category == 'onecard';
    final p = V2Palette.of(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          if (_failed)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: V2Banner(
                tone: V2BannerTone.warn,
                message: '최신 정보를 불러오지 못했어요.',
                actionLabel: '다시 시도',
                onAction: _load,
              ),
            ),
          if (_feedback != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: KeyedSubtree(
                key: const Key('shop_purchase_feedback'),
                child: V2Banner(
                  tone: _feedbackError ? V2BannerTone.err : V2BannerTone.ok,
                  message: _feedback!,
                  actionLabel: _feedbackError ? null : '내 아이템 보기',
                  onAction: _feedbackError
                      ? null
                      : () => setState(() => _tab = 1),
                  onDismiss: () => setState(() => _feedback = null),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Lv.$_userLevel',
                  style: V2Text.label.copyWith(color: p.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: V2ProgressBar(
                    value: _xpNeeded > 0 ? _userXp / _xpNeeded : 0,
                    height: 6,
                    semanticLabel: '레벨 $_userLevel, 경험치 $_userXp / $_xpNeeded',
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$_userXp / $_xpNeeded XP',
                  style: V2Text.label.copyWith(color: p.sub),
                ),
                if (_tickets > 0) ...[
                  const SizedBox(width: 10),
                  V2Chip(label: '뽑기권 $_tickets장', tone: V2Tone.lilac),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: V2Card(
              gradient: V2Gradients.hero,
              onTap: _openGacha,
              semanticLabel: '뽑기. 3,000 코인부터. 뽑으러 가기',
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '뽑기',
                          style: V2Text.head.copyWith(
                            color: V2Colors.onHeroStrong,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '무엇이 나올까요? ${coinText(kGachaTiers.first.cost)} 코인부터',
                          style: V2Text.cap.copyWith(
                            color: V2Colors.onHeroStrong,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: V2Colors.onHeroStrong,
                  ),
                  const SizedBox(width: 4),
                  Icon(V2Icons.chevron, color: V2Colors.onHeroStrong),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: V2Card(
              variant: V2CardVariant.soft,
              onTap: _showCoinGuide,
              child: Row(
                children: [
                  Icon(
                    Icons.monetization_on_rounded,
                    color: V2ToneColors.of(V2Tone.honey).base,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('코인 얻는 법', style: V2Text.bodyStrong),
                        Text('미션을 마치거나 놀이를 하면 코인을 받아요', style: V2Text.cap),
                      ],
                    ),
                  ),
                  Icon(V2Icons.chevron, color: p.muted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          CategoryFilter(
            selected: _category,
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 8),
          if (showYut) ...[
            _SectionTitle('윷놀이', yutItems.length),
            if (yutItems.isEmpty)
              const _ComingSoon()
            else
              // 윷 스킨 진열대는 게임 쪽 그림이라 원래(게임) 테마로 그려요.
              Theme(
                data: buildAppTheme(),
                child: YutSkinShop(
                  items: yutItems,
                  ownedIds: _ownedItemIds,
                  equippedIds: _equippedItemIds,
                  formatCoins: compactCoins,
                  onItemTap: _preview,
                ),
              ),
          ],
          if (showCard) ...[
            _SectionTitle('원카드', onecardItems.length),
            if (onecardItems.isEmpty)
              const _ComingSoon()
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in onecardItems)
                      _ItemTile(
                        item: item,
                        owned: _ownedItemIds.contains(
                          (item['id'] as num).toInt(),
                        ),
                        equipped: _equippedItemIds.contains(
                          (item['id'] as num).toInt(),
                        ),
                        onTap: () => _preview(item),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _missionsTab() {
    bool isDone(Map m) => m['claimed'] == true;
    bool isReady(Map m) => m['completed'] == true && m['claimed'] != true;
    final ready = _missions.where(isReady).toList();
    final doing = _missions.where((m) => !isReady(m) && !isDone(m)).toList();
    final done = _missions.where(isDone).toList();

    Widget group(
      String title,
      List<Map<String, dynamic>> list, {
      Widget? head,
    }) => list.isEmpty
        ? const SizedBox.shrink()
        : V2Section(
            title: '$title ${list.length}',
            child: Column(
              children: [
                ?head,
                for (final m in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MissionCard(
                      mission: m,
                      onClaim: _claiming ? null : () => _claim([m]),
                    ),
                  ),
              ],
            ),
          );

    return RefreshIndicator(
      onRefresh: _load,
      child: _missions.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 48),
                V2EmptyState(
                  illustration: const V2SceneIllustration(V2Scene.calendar),
                  title: '지금은 진행 중인 미션이 없어요',
                  body: '새 미션이 열리면 여기에 나타나요. 받은 보상은 코인에 모두 더해졌어요.',
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                group(
                  '받을 수 있어요',
                  ready,
                  head: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: V2Button(
                      label: '모두 받기 · +${coinText(_claimableCoins)} 코인',
                      loading: _claiming,
                      onPressed: ready.length > 1 ? () => _claim(ready) : null,
                    ),
                  ),
                ),
                group('진행 중', doing),
                group('완료', done),
              ],
            ),
    );
  }

  Widget _couponsTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          V2Button(
            label: '쿠폰 만들기',
            icon: V2Icons.add,
            variant: V2ButtonVariant.soft,
            onPressed: _issueCoupon,
          ),
          const SizedBox(height: 16),
          if (_coupons.isEmpty)
            const V2EmptyState(
              icon: Icons.local_activity_rounded,
              title: '받은 쿠폰이 없어요',
              body: '파트너가 보낸 데이트 쿠폰이 여기에 모여요.',
            )
          else ...[
            Text('받은 쿠폰 ${_coupons.length}', style: V2Text.bodyStrong),
            const SizedBox(height: 10),
            for (final c in _coupons) ...[
              _CouponCard(coupon: c, onRedeem: () => _redeemCoupon(c)),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.count);

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
    child: Row(
      children: [
        Text(title, style: V2Text.head),
        const Spacer(),
        Text('$count종', style: V2Text.cap),
      ],
    ),
  );
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(child: Text('곧 만나요', style: V2Text.cap)),
  );
}

/// Shop grid tile (원카드 and anything that is not a yut skin).
class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.owned,
    required this.equipped,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final bool owned;
  final bool equipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grade = item['grade'] as String? ?? 'B';
    final price = (item['price'] as num?)?.toInt() ?? 0;
    final gachaOnly = const ['S', 'SS', 'SSS'].contains(grade);
    final badge = ownershipChip(owned: owned, equipped: equipped);
    return SizedBox(
      width: 156,
      child: V2Card(
        key: ValueKey('shop_item_${item['id']}'),
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        semanticLabel: '${item['name']}, ${gradeLabel(grade)}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ItemArt(game: item['game'], grade: grade, size: 52),
            const SizedBox(height: 10),
            Text(
              item['name'] as String? ?? '',
              style: V2Text.bodyStrong,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            GradeChip(grade: grade),
            const SizedBox(height: 8),
            badge ??
                Text(
                  gachaOnly ? '뽑기 전용' : coinText(price),
                  style: V2Text.bodyStrong,
                ),
          ],
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission, required this.onClaim});

  final Map<String, dynamic> mission;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final progress = (mission['progress'] as num?)?.toInt() ?? 0;
    final target = (mission['targetCount'] as num?)?.toInt() ?? 1;
    final completed = mission['completed'] == true;
    final claimed = mission['claimed'] == true;
    final coins = (mission['rewardCoins'] as num?)?.toInt() ?? 0;
    final tickets = (mission['rewardTickets'] as num?)?.toInt() ?? 0;
    final xp = (mission['rewardXp'] as num?)?.toInt() ?? 0;
    final desc = mission['description'] as String? ?? '';

    return V2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mission['title'] as String? ?? '',
                  style: V2Text.bodyStrong.copyWith(
                    color: claimed ? p.muted : p.ink,
                  ),
                ),
              ),
              if (claimed)
                const V2Chip(
                  label: '받았어요',
                  tone: V2Tone.ok,
                  icon: V2Icons.check,
                )
              else if (completed)
                V2Button(
                  label: '받기',
                  size: V2ButtonSize.sm,
                  fullWidth: false,
                  onPressed: onClaim,
                ),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(desc, style: V2Text.cap),
          ],
          if (!claimed) ...[
            const SizedBox(height: 10),
            V2ProgressBar(
              value: target > 0 ? (progress / target).clamp(0.0, 1.0) : 0,
              height: 6,
              semanticLabel: '$target 중 $progress',
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('$progress/$target', style: V2Text.cap),
              if (coins > 0)
                V2Chip(label: '+${coinText(coins)} 코인', tone: V2Tone.honey),
              if (tickets > 0)
                V2Chip(label: '뽑기권 +$tickets', tone: V2Tone.lilac),
              if (xp > 0) V2Chip(label: '+$xp XP', tone: V2Tone.sky),
            ],
          ),
        ],
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon, required this.onRedeem});

  final Map<String, dynamic> coupon;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final desc = coupon['description'] as String? ?? '';
    final expires = DateTime.tryParse(
      '${coupon['expires_at'] ?? ''}',
    )?.toLocal();
    return V2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  coupon['title'] as String? ?? '',
                  style: V2Text.head,
                ),
              ),
              const V2Chip(label: '사용 가능', tone: V2Tone.ok),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(desc, style: V2Text.body),
          ],
          if (expires != null) ...[
            const SizedBox(height: 4),
            Text('${expires.month}월 ${expires.day}일까지', style: V2Text.cap),
          ],
          const SizedBox(height: 12),
          V2Button(label: '사용하기', size: V2ButtonSize.sm, onPressed: onRedeem),
        ],
      ),
    );
  }
}

/// 쿠폰 만들기 폼. 잘못된 칸 아래에 이유를 보여 줘요(이름 필수, 20자까지).
class _CouponForm extends StatefulWidget {
  const _CouponForm({required this.balance});

  static const cost = 500;
  final int balance;

  @override
  State<_CouponForm> createState() => _CouponFormState();
}

class _CouponFormState extends State<_CouponForm> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String? _titleError;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = '쿠폰 이름을 입력해 주세요.');
      return;
    }
    if (title.length > 20) {
      setState(() => _titleError = '쿠폰 이름은 20자까지 쓸 수 있어요.');
      return;
    }
    Navigator.of(context).pop((title, _desc.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final short = widget.balance < _CouponForm.cost;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        V2TextField(
          label: '쿠폰 이름',
          controller: _title,
          hint: '예) 주말 늦잠 허락권',
          maxLength: 20,
          error: _titleError,
          onChanged: (_) {
            if (_titleError != null) setState(() => _titleError = null);
          },
        ),
        const SizedBox(height: 12),
        V2TextField(
          label: '메모 (선택)',
          controller: _desc,
          hint: '파트너에게 전할 말을 적어 보세요',
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        Text(
          '${coinText(_CouponForm.cost)} 코인이 들고, 보낸 날부터 30일 동안 쓸 수 있어요.',
          style: V2Text.cap,
        ),
        if (short) ...[
          const SizedBox(height: 8),
          V2Banner(
            tone: V2BannerTone.warn,
            message: '코인이 ${coinText(_CouponForm.cost - widget.balance)} 모자라요.',
          ),
        ],
        const SizedBox(height: 16),
        V2Button(label: '보내기', onPressed: short ? null : _submit),
      ],
    );
  }
}
