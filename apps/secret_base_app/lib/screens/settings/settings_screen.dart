import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../core/auth_service.dart';
import '../../core/http/api_client.dart';
import '../../v2/v2.dart';
import '../archive/personal_history_screen.dart';
import '../auth/partner_screen.dart';
import '../home/anniversaries_screen.dart';
import '../relationship/relationship_understanding_screen.dart';
import '../secret_base/secret_base_screen.dart';
import '../shop/shop_screen.dart';
import 'account_screen.dart';
import 'app_info_screens.dart';
import 'couple_info_screen.dart';
import 'notification_settings_screen.dart';
import 'permission_probe.dart';
import 'permissions_screen.dart';
import 'profile_edit_screen.dart';
import 'settings_common.dart';
import 'support_sheet.dart';

/// 더보기 탭: 4개 구역 허브.
///
/// ① 프로필·커플 ② 우리 이야기 ③ 앱 설정 ④ 도움말·정보·계정.
/// 탭과 겹치는 바로가기, 디버그 정보(Ping·접속자·방 코드)는 두지 않는다.
class SettingsScreen extends StatefulWidget {
  /// 홈 셸이 넘겨 주던 탭 이동 콜백. 2.0 더보기는 탭 바로가기를 두지 않아
  /// 쓰지 않지만, 호출하는 쪽의 생성자를 바꾸지 않으려고 남겨 둔다.
  final ValueChanged<int>? onNavigate;
  final ApiClient? apiClient;
  final PermissionProbe permissionProbe;

  const SettingsScreen({
    super.key,
    this.onNavigate,
    this.apiClient,
    this.permissionProbe = const DevicePermissionProbe(),
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthService();
  late final ApiClient _api = widget.apiClient ?? _auth.apiClient;

  CoupleInfo? _couple;
  String? _notificationSummary;
  int? _coins;
  OsPermission _osNotification = OsPermission.unknown;
  AppInfo? _appInfo;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuth);
    _loadAll();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
    super.dispose();
  }

  void _onAuth() {
    if (mounted) setState(() {});
  }

  Map<String, dynamic>? get _user => _auth.user;

  Future<void> _loadAll() async {
    // 요약 줄은 하나라도 실패해도 허브는 그대로 쓸 수 있어야 해요.
    _loadCouple();
    _loadNotificationSummary();
    _loadCoins();
    widget.permissionProbe.notification().then((state) {
      if (mounted) setState(() => _osNotification = state);
    });
    AppInfo.load()
        .then((info) {
          if (mounted) setState(() => _appInfo = info);
        })
        .catchError((_) {});
  }

  Future<void> _loadCouple() async {
    if (!isPaired(_user)) return;
    try {
      final info = await fetchCoupleInfo(_api);
      if (mounted) setState(() => _couple = info);
    } catch (_) {}
  }

  Future<void> _loadNotificationSummary() async {
    try {
      final json = await _api.getJson('/api/notification-prefs') as Map;
      final prefs = {
        ...kNotificationPrefDefaults,
        ...Map<String, dynamic>.from(json['prefs'] as Map),
      };
      if (mounted) {
        setState(() => _notificationSummary = notificationSummary(prefs));
      }
    } catch (_) {}
  }

  Future<void> _loadCoins() async {
    try {
      final json = await _api.getJson('/api/wallet/balance') as Map;
      final balance = (json['balance'] as num?)?.toInt();
      if (mounted && balance != null) setState(() => _coins = balance);
    } catch (_) {}
  }

  Future<void> _open(Widget page) async {
    await pushMorePage<void>(context, page);
    if (!mounted) return;
    // 돌아오면 바뀐 값(알림, 코인, 커플 정보)을 다시 읽어요.
    _loadAll();
  }

  void _needsPartner() {
    showV2Snack(context, '파트너와 연결하면 열려요');
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final paired = isPaired(user);
    final me = myDisplayName(user);
    final partner = partnerDisplayName(user);

    return V2Theme(
      child: Scaffold(
        appBar: const V2Header(title: '더보기'),
        body: user == null
            ? const Padding(
                padding: EdgeInsets.all(V2Space.page),
                child: V2SkeletonList(count: 6),
              )
            : RefreshIndicator(
                onRefresh: _loadAll,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  children: [
                    if (_osNotification == OsPermission.denied &&
                        !_bannerDismissed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: V2Banner(
                          tone: V2BannerTone.warn,
                          title: '알림이 꺼져 있어요',
                          message: partner == null
                              ? '새 소식을 바로 받지 못해요'
                              : '$partner의 새 기록을 바로 받지 못해요',
                          actionLabel: '켜기',
                          onAction: () =>
                              _open(const NotificationSettingsScreen()),
                          onDismiss: () =>
                              setState(() => _bannerDismissed = true),
                        ),
                      ),
                    _ProfileEntry(
                      me: me,
                      partner: paired ? (partner ?? '파트너') : null,
                      dDay: _couple?.dDayText ?? '',
                      onTap: () => _open(
                        paired
                            ? const CoupleInfoScreen()
                            : const ProfileEditScreen(),
                      ),
                      onPair: () => _open(const PartnerScreen()),
                    ),
                    V2Section(
                      title: '우리 이야기',
                      child: V2List(
                        children: [
                          V2ListTile(
                            icon: V2Icons.event,
                            title: '기념일',
                            subtitle: paired
                                ? _anniversarySubtitle()
                                : '연결하면 열려요',
                            onTap: paired
                                ? () => _open(const AnniversariesScreen())
                                : _needsPartner,
                          ),
                          V2ListTile(
                            icon: V2Icons.base,
                            tone: V2Tone.lilac,
                            title: '비밀기지',
                            subtitle: paired ? '둘만의 공간' : '연결하면 열려요',
                            onTap: paired ? _openBase : _needsPartner,
                          ),
                          V2ListTile(
                            icon: V2Icons.care,
                            tone: V2Tone.honey,
                            title: '우리 이해',
                            subtitle: paired
                                ? '오늘의 운세와 마음 돌봄'
                                : '내 운세부터 볼 수 있어요',
                            onTap: () =>
                                _open(const RelationshipUnderstandingScreen()),
                          ),
                          V2ListTile(
                            icon: V2Icons.shop,
                            tone: V2Tone.sky,
                            title: '상점',
                            subtitle: '꾸미기 아이템과 미션',
                            trailing: _coins == null
                                ? null
                                : Text(
                                    groupedNumber(_coins!),
                                    style: V2Text.bodyStrong,
                                  ),
                            showChevron: true,
                            onTap: () => _open(const ShopScreen()),
                          ),
                          if (!paired)
                            V2ListTile(
                              icon: V2Icons.lock,
                              tone: V2Tone.sage,
                              title: '개인 보관함',
                              subtitle: '연결 전에 남긴 나만의 기록',
                              onTap: () => _open(const PersonalHistoryScreen()),
                            ),
                        ],
                      ),
                    ),
                    V2Section(
                      title: '앱 설정',
                      child: V2List(
                        children: [
                          V2ListTile(
                            icon: V2Icons.bell,
                            tone: V2Tone.lilac,
                            title: '알림',
                            subtitle: _osNotification == OsPermission.denied
                                ? '꺼짐 · 휴대폰 설정에서 켤 수 있어요'
                                : (_notificationSummary ?? '받고 싶은 알림만 골라요'),
                            onTap: () =>
                                _open(const NotificationSettingsScreen()),
                          ),
                          V2ListTile(
                            icon: V2Icons.shield,
                            tone: V2Tone.sage,
                            title: '개인정보·권한',
                            subtitle: '위치 · 카메라 · 알림',
                            onTap: () => _open(const PermissionsScreen()),
                          ),
                        ],
                      ),
                    ),
                    V2Section(
                      title: '도움말·정보',
                      child: V2List(
                        children: [
                          V2ListTile(
                            icon: V2Icons.help,
                            tone: V2Tone.sky,
                            title: '고객센터·FAQ',
                            subtitle: '자주 묻는 질문과 문의',
                            onTap: () => showSupportSheet(context),
                          ),
                          V2ListTile(
                            icon: V2Icons.info,
                            tone: V2Tone.neutral,
                            title: '앱 정보·약관',
                            trailing: Text(
                              _appInfo?.hasVersion == true
                                  ? _appInfo!.version
                                  : '',
                              style: V2Text.cap,
                            ),
                            showChevron: true,
                            onTap: () => _open(AppInfoScreen(info: _appInfo)),
                          ),
                          V2ListTile(
                            icon: V2Icons.person,
                            tone: V2Tone.peach,
                            title: '계정',
                            subtitle: '로그아웃 · 탈퇴',
                            onTap: () => _open(const AccountScreen()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  String _anniversarySubtitle() {
    final label = _couple?.nextAnniversaryLabel;
    final days = _couple?.nextAnniversaryDays;
    if (label == null || label.isEmpty || days == null) {
      return '소중한 날을 챙겨 보세요';
    }
    return days <= 0 ? '$label 오늘이에요' : '$label까지 $days일';
  }

  void _openBase() => _open(
    SecretBaseScreen(
      baseUrl: _auth.baseUrl,
      authHeaders: {
        if (_auth.token != null) 'Authorization': 'Bearer ${_auth.token}',
      },
    ),
  );
}

/// 프로필·커플 카드(맨 위). 연결 전에는 "파트너 연결하기" 버튼이 붙어요.
class _ProfileEntry extends StatelessWidget {
  const _ProfileEntry({
    required this.me,
    required this.partner,
    required this.dDay,
    required this.onTap,
    required this.onPair,
  });

  final String me;
  final String? partner;
  final String dDay;
  final VoidCallback onTap;
  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final paired = partner != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: V2Card(
        onTap: onTap,
        semanticLabel: paired ? '$me, $partner 커플 정보' : '$me 프로필',
        child: Column(
          children: [
            Row(
              children: [
                if (paired)
                  V2AvatarPair(me: me, partner: partner!)
                else
                  V2Avatar(name: me, size: V2AvatarSize.lg),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paired ? '$me · $partner' : me,
                        style: V2Text.head,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (!paired)
                        Text('아직 연결 전이에요', style: V2Text.cap)
                      else if (dDay.isNotEmpty)
                        Row(
                          children: [
                            Text('함께한 지 ', style: V2Text.cap),
                            Text(
                              dDay,
                              style: V2Text.serif(size: 16, color: p.primary),
                            ),
                          ],
                        )
                      else
                        Text('커플 정보 보기', style: V2Text.cap),
                    ],
                  ),
                ),
                Icon(V2Icons.chevron, color: p.muted),
              ],
            ),
            if (!paired) ...[
              const SizedBox(height: 14),
              V2Button(
                label: '파트너 연결하기',
                icon: V2Icons.link,
                onPressed: onPair,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
