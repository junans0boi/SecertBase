import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/auth_service.dart';
import '../../core/socket_service.dart';
import '../../v2/v2.dart';
import 'shop_common.dart';

export 'shop_common.dart'
    show formatStatValue, statLabels, gradeOrder, gradeColor;

/// 내 아이템: 상점과 같은 카테고리 필터 · 같은 보유/장착 뱃지를 써요.
class InventoryTab extends StatefulWidget {
  final VoidCallback onBalanceChanged;
  final http.Client? client;
  final String? baseUrl;
  final VoidCallback? onOpenShop;

  const InventoryTab({
    super.key,
    required this.onBalanceChanged,
    this.client,
    this.baseUrl,
    this.onOpenShop,
  });

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final _auth = AuthService();
  final _socket = SocketService();

  List<Map<String, dynamic>> _owned = [];
  Set<int> _equippedIds = {};
  Map<String, dynamic> _equippedBySlot = {};
  bool _loading = true;
  bool _failed = false;
  String? _filterGame;

  late final http.Client _client;
  late final bool _ownsClient;

  @override
  void initState() {
    super.initState();
    _ownsClient = widget.client == null;
    _client = widget.client ?? http.Client();
    _load();
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
    super.dispose();
  }

  String get _baseUrl => widget.baseUrl ?? _socket.serverUrl ?? '';

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${_auth.token}',
    'Content-Type': 'application/json',
  };

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final results = await Future.wait([
        _client.get(Uri.parse('$_baseUrl/api/shop/owned'), headers: _headers),
        _client.get(
          Uri.parse('$_baseUrl/api/shop/equipped'),
          headers: _headers,
        ),
      ]);
      final ownedData = jsonDecode(results[0].body) as Map;
      final equippedData = jsonDecode(results[1].body) as Map;
      final slots = (equippedData['slots'] as Map? ?? {})
          .cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        // 폐지된 말 스킨·은퇴한 옛 윷은 보여 주지 않아요.
        _owned = (ownedData['owned'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .where((i) => i['slot'] != 'yut_piece' && i['game'] != 'yut_legacy')
            .toList();
        _equippedIds = slots.values
            .map((v) => ((v as Map)['item_id'] as num).toInt())
            .toSet();
        _equippedBySlot = Map<String, dynamic>.from(slots);
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _equip(Map<String, dynamic> item) async {
    try {
      final res = await _client.post(
        Uri.parse('$_baseUrl/api/shop/equip'),
        headers: _headers,
        body: jsonEncode({'item_id': item['item_id']}),
      );
      final body = jsonDecode(res.body) as Map;
      if (!mounted) return;
      if (body['ok'] == true) {
        showV2Snack(context, '${item['name']}을 장착했어요');
        await _load();
      } else {
        showV2Snack(context, '장착하지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
      }
    } catch (_) {
      if (mounted) {
        showV2Snack(context, '장착하지 못했어요. 네트워크를 확인해 주세요.', tone: V2Tone.err);
      }
    }
  }

  Future<void> _unequip(String slot) async {
    try {
      final res = await _client.post(
        Uri.parse('$_baseUrl/api/shop/unequip'),
        headers: _headers,
        body: jsonEncode({'slot': slot}),
      );
      final body = jsonDecode(res.body) as Map;
      if (!mounted) return;
      if (body['ok'] == true) {
        showV2Snack(context, '기본 아이템으로 바꿨어요');
        await _load();
      } else {
        showV2Snack(context, '바꾸지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
      }
    } catch (_) {
      if (mounted) {
        showV2Snack(context, '바꾸지 못했어요. 네트워크를 확인해 주세요.', tone: V2Tone.err);
      }
    }
  }

  static const _defaultItems = <Map<String, dynamic>>[
    {
      'item_id': 0,
      'name': '기본 윷',
      'slot': 'yut_yut',
      'game': 'yut',
      'grade': 'B',
      'stats': <String, dynamic>{},
    },
    {
      'item_id': 0,
      'name': '기본 카드',
      'slot': 'onecard_cardback',
      'game': 'onecard',
      'grade': 'B',
      'stats': <String, dynamic>{},
    },
  ];

  static const _statMaxValues = {
    'coin_bonus_pct': 20,
    'shop_discount_pct': 20,
    'daily_bonus_add': 500,
    'lose_refund_pct': 20,
    'yut_control_pct': 1.5,
    'yut_backdo_shield_pct': 12,
    'yut_catch_bonus': 300,
    'gacha_rate_up': 20,
    'win_streak_bonus': 400,
    'yut_mo_rate_pct': 8,
    'yut_backdo_bonus_pct': 25,
    'yut_win_coin_pct': 10,
    'yut_overturn_pct': 1.5,
    'piece_catch_resist_pct': 9,
    'piece_catch_coin_bonus': 25,
    'piece_safe_zone_pct': 15,
    'piece_group_pct': 22,
    'card_shield_pct': 25,
    'card_lucky_draw_pct': 25,
    'card_uno_protect_pct': 22,
    'card_reverse_bonus': 22,
    'onecard_draw_reduce': 2,
  };

  Map<String, dynamic> _statsOf(Map<String, dynamic> item) {
    final raw = item['stats'];
    if (raw is String && raw.isNotEmpty && raw != 'null') {
      try {
        return Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {}
    } else if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {};
  }

  void _showItemDetail(Map<String, dynamic> item) {
    final grade = item['grade'] as String? ?? 'B';
    final slot = item['slot'] as String? ?? '';
    final id = (item['item_id'] as num).toInt();
    final equipped = _equippedIds.contains(id);
    final usable = item['usable'] != false;
    final description = item['description'] as String?;
    final stats = _statsOf(item);
    final equippedInSlot = _equippedBySlot[slot] as Map?;
    final equippedStats =
        equippedInSlot != null &&
            (equippedInSlot['item_id'] as num?)?.toInt() != id
        ? Map<String, dynamic>.from((equippedInSlot['stats'] as Map?) ?? {})
        : <String, dynamic>{};

    showV2Sheet<void>(
      context,
      title: item['name'] as String? ?? '',
      builder: (ctx) {
        final p = V2Palette.of(ctx);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ItemArt(game: item['game'], grade: grade, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      GradeChip(grade: grade),
                      ?ownershipChip(owned: true, equipped: equipped),
                    ],
                  ),
                ),
              ],
            ),
            if (description != null && description.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                key: const Key('inventory_item_description'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.soft,
                  borderRadius: BorderRadius.circular(V2Radius.ctl),
                ),
                child: Text(description, style: V2Text.body),
              ),
            ],
            const SizedBox(height: 16),
            if (stats.isEmpty)
              Text('능력치가 없는 아이템이에요.', style: V2Text.cap)
            else ...[
              Text(
                equippedStats.isEmpty ? '능력치' : '능력치 (장착 중인 아이템과 비교)',
                style: V2Text.bodyStrong,
              ),
              const SizedBox(height: 8),
              for (final e in stats.entries)
                _StatBar(
                  label: statLabels[e.key] ?? e.key,
                  value: (e.value as num).toDouble(),
                  compare: equippedStats[e.key] == null
                      ? null
                      : (equippedStats[e.key] as num).toDouble(),
                  max: (_statMaxValues[e.key] ?? (e.value as num)).toDouble(),
                  grade: grade,
                ),
            ],
            const SizedBox(height: 16),
            if (!equipped)
              SizedBox(
                key: const Key('inventory_use_cta'),
                child: V2Button(
                  label: usable ? '장착하기' : '지금은 쓸 수 없어요',
                  onPressed: usable
                      ? () {
                          Navigator.pop(ctx);
                          _equip(item);
                        }
                      : null,
                ),
              )
            else
              V2Button(
                label: '닫기',
                variant: V2ButtonVariant.soft,
                onPressed: () => Navigator.pop(ctx),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showCompendium() async {
    final gameParam = _filterGame != null ? '?game=$_filterGame' : '';
    try {
      final res = await _client.get(
        Uri.parse('$_baseUrl/api/shop/catalog$gameParam'),
        headers: _headers,
      );
      final body = jsonDecode(res.body) as Map;
      if (!mounted) return;
      if (body['ok'] != true) throw StateError('catalog');
      final items = (body['items'] as List? ?? []).cast<Map<String, dynamic>>();
      await showV2Sheet<void>(
        context,
        title: '도감',
        builder: (_) => _Compendium(items: items),
      );
    } catch (_) {
      if (mounted) {
        showV2Snack(context, '도감을 불러오지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _owned.isEmpty) {
      return const Padding(
        key: Key('inventory_loading_state'),
        padding: EdgeInsets.all(V2Space.page),
        child: V2SkeletonList(count: 3),
      );
    }
    if (_failed) {
      return KeyedSubtree(
        key: const Key('inventory_error_state'),
        child: V2ErrorState(
          title: '인벤토리를 불러오지 못했어요.',
          body: '잠시 후 다시 불러오거나 네트워크를 확인해 주세요. 가진 아이템은 그대로 안전해요.',
          onRetry: _load,
        ),
      );
    }

    final owned = _filterGame == null
        ? _owned
        : _owned.where((i) => i['game'] == _filterGame).toList();
    final defaults = [
      for (final d in _defaultItems)
        if (_filterGame == null || d['game'] == _filterGame)
          {
            ...d,
            '_isDefault': true,
            // 슬롯에 다른 아이템이 없으면 기본 아이템이 장착 중이에요.
            '_equipped': _equippedBySlot[d['slot']] == null,
          },
    ];
    final p = V2Palette.of(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text('내 아이템 ${_owned.length}', style: V2Text.head),
                ),
                V2Button(
                  label: '도감',
                  icon: Icons.menu_book_rounded,
                  variant: V2ButtonVariant.text,
                  size: V2ButtonSize.sm,
                  fullWidth: false,
                  onPressed: _showCompendium,
                ),
              ],
            ),
          ),
          CategoryFilter(
            selected: _filterGame,
            onChanged: (g) => setState(() => _filterGame = g),
          ),
          const SizedBox(height: 16),
          if (owned.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: KeyedSubtree(
                key: const Key('inventory_empty_state'),
                child: V2Card(
                  variant: V2CardVariant.soft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('아직 보유한 아이템이 없어요.', style: V2Text.bodyStrong),
                      const SizedBox(height: 4),
                      Text(
                        '상점에서 고르거나 뽑기로 첫 아이템을 만나 보세요. 산 아이템은 여기서 장착해요.',
                        style: V2Text.cap.copyWith(color: p.sub),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          V2Button(
                            label: '다시 불러오기',
                            variant: V2ButtonVariant.ghost,
                            size: V2ButtonSize.sm,
                            fullWidth: false,
                            onPressed: _load,
                          ),
                          if (widget.onOpenShop != null)
                            V2Button(
                              label: '상점 둘러보기',
                              size: V2ButtonSize.sm,
                              fullWidth: false,
                              onPressed: widget.onOpenShop,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in [...defaults, ...owned])
                  _InventoryTile(
                    item: item,
                    equipped: item['_isDefault'] == true
                        ? item['_equipped'] == true
                        : _equippedIds.contains(
                            (item['item_id'] as num).toInt(),
                          ),
                    onTap: item['_isDefault'] == true
                        ? (item['_equipped'] == true
                              ? null
                              : () => _unequip(item['slot'] as String))
                        : () => _showItemDetail(item),
                    defaultLabel: item['_isDefault'] == true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({
    required this.item,
    required this.equipped,
    required this.onTap,
    required this.defaultLabel,
  });

  final Map<String, dynamic> item;
  final bool equipped;
  final VoidCallback? onTap;
  final bool defaultLabel;

  @override
  Widget build(BuildContext context) {
    final grade = item['grade'] as String? ?? 'B';
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    return SizedBox(
      width: 156,
      child: V2Card(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        semanticLabel: [
          '${item['name']}',
          if (equipped) '장착 중',
          if (onTap != null && !equipped)
            defaultLabel ? '눌러서 기본으로 바꾸기' : '눌러서 자세히 보기',
        ].join(', '),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ItemArt(game: item['game'], grade: grade, size: 52),
                const Spacer(),
                if (qty > 1) Text('×$qty', style: V2Text.label),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item['name'] as String? ?? '',
              style: V2Text.bodyStrong,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            GradeChip(grade: grade),
            const SizedBox(height: 8),
            ownershipChip(owned: true, equipped: equipped) ??
                Text(
                  defaultLabel ? '눌러서 쓰기' : '장착하기',
                  style: V2Text.label.copyWith(
                    color: V2Palette.of(context).primary,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.label,
    required this.value,
    required this.compare,
    required this.max,
    required this.grade,
  });

  final String label;
  final double value;
  final double? compare;
  final double max;
  final String grade;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final t = V2ToneColors.of(gradeTone(grade));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: V2Text.cap.copyWith(color: p.ink)),
              ),
              Text(
                '+${formatStatValue(value)}',
                style: V2Text.label.copyWith(color: t.text),
              ),
              if (compare != null)
                Text(' (지금 +${formatStatValue(compare!)})', style: V2Text.cap),
            ],
          ),
          const SizedBox(height: 4),
          V2ProgressBar(
            value: max > 0 ? value / max : 0,
            height: 6,
            color: t.base,
            semanticLabel: '$label +${formatStatValue(value)}',
          ),
        ],
      ),
    );
  }
}

/// 도감: 모은 아이템은 보이고, 아직 못 모은 아이템은 "???"로 가려져요.
class _Compendium extends StatefulWidget {
  const _Compendium({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  State<_Compendium> createState() => _CompendiumState();
}

class _CompendiumState extends State<_Compendium> {
  String? _game;

  @override
  Widget build(BuildContext context) {
    final items = widget.items
        .where((i) => _game == null || i['game'] == _game)
        .toList();
    final owned = items.where((i) => i['owned'] == true).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$owned개 모았어요 · 전체 ${items.length}개', style: V2Text.cap),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final c in shopCategories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: V2Chip(
                    label: c.label,
                    selected: _game == c.game,
                    onTap: () => setState(() => _game = c.game),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: 96,
                child: Column(
                  children: [
                    item['owned'] == true
                        ? ItemArt(
                            game: item['game'],
                            grade: item['grade'] as String? ?? 'B',
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: V2Palette.of(context).soft2,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              V2Icons.lock,
                              color: V2Palette.of(context).muted,
                            ),
                          ),
                    const SizedBox(height: 6),
                    Text(
                      item['owned'] == true ? '${item['name']}' : '???',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: V2Text.cap.copyWith(
                        color: V2Palette.of(context).ink,
                      ),
                    ),
                    Text(
                      item['owned'] == true ? '' : '미보유',
                      style: V2Text.label.copyWith(
                        color: V2Palette.of(context).sub,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
