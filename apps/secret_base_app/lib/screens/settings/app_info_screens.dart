import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_changelog.dart';
import '../../core/app_info.dart';
import '../../core/auth_service.dart';
import '../../v2/v2.dart';
import 'permission_probe.dart';
import 'settings_common.dart';

/// 앱 정보·약관: 버전, 업데이트 내역, 약관, 개발자 정보, 라이선스.
///
/// 버전 줄을 7번 누르면 개발자용 진단 화면이 열려요(일반 화면에는 디버그 값이 없어요).
class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({
    super.key,
    this.info,
    this.onOpenLink = openExternalLink,
    this.developerName = AppInfoConstants.developerName,
    this.teamName = AppInfoConstants.teamName,
    this.legalOperatorName = AppInfoConstants.legalOperatorName,
    this.supportEmail = AppInfoConstants.supportEmail,
    this.websiteUrl = AppInfoConstants.websiteUrl,
  });

  final AppInfo? info;
  final LinkOpener onOpenLink;
  final String developerName;
  final String teamName;
  final String legalOperatorName;
  final String supportEmail;
  final String websiteUrl;

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  AppInfo? _info;
  int _taps = 0;

  @override
  void initState() {
    super.initState();
    _info = widget.info;
    if (_info == null) {
      AppInfo.load()
          .then((v) {
            if (mounted) setState(() => _info = v);
          })
          .catchError((_) {});
    }
  }

  void _versionTap() {
    _taps++;
    if (_taps >= 7) {
      _taps = 0;
      pushMorePage<void>(context, DiagnosticsScreen(info: _info));
    }
  }

  Future<void> _mail(String email) async {
    final ok = await widget.onOpenLink(Uri(scheme: 'mailto', path: email));
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: email));
      if (mounted) {
        showV2Snack(context, '메일 앱을 열 수 없어요. 주소를 복사했어요.');
      }
    }
  }

  void _showLicenses() {
    showLicensePage(
      context: context,
      applicationName: AppInfoConstants.appNameKo,
      applicationVersion: _info?.fullVersion,
      applicationLegalese: AppInfoConstants.copyrightLine,
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final p = V2Palette.of(context);
    final email = widget.supportEmail.trim();
    final site = widget.websiteUrl.trim();
    final operator = widget.legalOperatorName.trim();
    final version = info != null && info.hasVersion
        ? info.version
        : '확인할 수 없어요';
    return V2Theme(
      child: Scaffold(
        appBar: const V2Header(title: '앱 정보·약관'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Column(
              children: [
                const V2Art(icon: V2Icons.base),
                const SizedBox(height: 12),
                Text(AppInfoConstants.appNameKo, style: V2Text.title),
                const SizedBox(height: 2),
                Text('버전 $version', style: V2Text.cap),
              ],
            ),
            const SizedBox(height: 24),
            V2List(
              children: [
                V2ListTile(
                  icon: V2Icons.sparkle,
                  tone: V2Tone.honey,
                  title: '업데이트 내역',
                  subtitle: '${kChangelog.first.version} 새로워진 점',
                  onTap: () => pushMorePage<void>(
                    context,
                    ChangelogScreen(currentVersion: info?.version ?? ''),
                  ),
                ),
                V2ListTile(
                  icon: V2Icons.text,
                  tone: V2Tone.sky,
                  title: '이용약관',
                  onTap: () =>
                      widget.onOpenLink(Uri.parse(AppInfoConstants.termsUrl)),
                ),
                V2ListTile(
                  icon: V2Icons.shield,
                  tone: V2Tone.sage,
                  title: '개인정보 처리방침',
                  onTap: () =>
                      widget.onOpenLink(Uri.parse(AppInfoConstants.privacyUrl)),
                ),
                V2ListTile(
                  icon: V2Icons.delete,
                  tone: V2Tone.peach,
                  title: '계정 삭제 안내',
                  onTap: () => widget.onOpenLink(
                    Uri.parse(AppInfoConstants.deleteAccountUrl),
                  ),
                ),
                V2ListTile(
                  icon: V2Icons.info,
                  tone: V2Tone.lilac,
                  title: '오픈소스 라이선스',
                  onTap: _showLicenses,
                ),
              ],
            ),
            V2Section(
              title: '개발자 정보',
              padding: EdgeInsets.zero,
              child: MoreInfoGroup(
                children: [
                  MoreInfoRow(label: '개발자', value: widget.developerName),
                  MoreInfoRow(label: '팀', value: widget.teamName),
                  if (operator.isNotEmpty)
                    MoreInfoRow(label: '운영자', value: operator),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _versionTap,
                    child: MoreInfoRow(
                      label: '버전',
                      value: info != null && info.hasVersion
                          ? info.fullVersion.replaceFirst('v', '')
                          : '확인할 수 없어요',
                    ),
                  ),
                  if (email.isNotEmpty)
                    MoreInfoRow(
                      label: '문의',
                      value: email,
                      trailing: V2IconButton(
                        icon: V2Icons.send,
                        tooltip: '메일 보내기',
                        onPressed: () => _mail(email),
                      ),
                    ),
                ],
              ),
            ),
            if (site.isNotEmpty) ...[
              const SizedBox(height: 12),
              V2Button(
                label: '팀 홈페이지',
                icon: V2Icons.link,
                variant: V2ButtonVariant.soft,
                onPressed: () => widget.onOpenLink(Uri.parse(site)),
              ),
            ],
            const SizedBox(height: 24),
            Center(
              child: Text(
                AppInfoConstants.copyrightLine,
                style: V2Text.cap.copyWith(color: p.muted),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 업데이트 내역: [kChangelog]를 최신순으로 보여 줘요.
class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({
    super.key,
    this.entries = kChangelog,
    this.currentVersion = '',
  });

  final List<ChangelogEntry> entries;

  /// 지금 설치된 버전. 같은 항목에 "현재 버전" 표시가 붙어요.
  final String currentVersion;

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Scaffold(
        appBar: const V2Header(title: '업데이트 내역'),
        body: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _ChangelogCard(
            entry: entries[index],
            isCurrent: entries[index].version == currentVersion,
          ),
        ),
      ),
    );
  }
}

class _ChangelogCard extends StatelessWidget {
  const _ChangelogCard({required this.entry, required this.isCurrent});

  final ChangelogEntry entry;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return V2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(entry.version, style: V2Text.head),
              const SizedBox(width: 8),
              if (isCurrent) const V2Chip(label: '현재 버전', tone: V2Tone.rose),
              const Spacer(),
              Text(entry.date.replaceAll('-', '.'), style: V2Text.cap),
            ],
          ),
          const SizedBox(height: 4),
          Text(entry.title, style: V2Text.bodyStrong),
          const SizedBox(height: 10),
          for (final item in entry.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: p.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(child: Text(item, style: V2Text.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 개발자용 진단(앱 정보의 버전을 7번 눌러야 열려요). 사용자에게 보이는 일반
/// 화면에는 넣지 않는 값(서버 주소, 사용자 ID, 권한 상태)을 모아 둬요.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({
    super.key,
    this.info,
    this.probe = const DevicePermissionProbe(),
  });

  final AppInfo? info;
  final PermissionProbe probe;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  String _permissions = '확인하는 중';

  @override
  void initState() {
    super.initState();
    _readPermissions();
  }

  static String _label(OsPermission p) => switch (p) {
    OsPermission.granted => '허용',
    OsPermission.denied => '꺼짐',
    OsPermission.notAsked => '묻기 전',
    OsPermission.unknown => '알 수 없음',
  };

  Future<void> _readPermissions() async {
    final location = await widget.probe.location();
    final notification = await widget.probe.notification();
    if (mounted) {
      setState(() {
        _permissions = '위치 ${_label(location)} · 알림 ${_label(notification)}';
      });
    }
  }

  List<(String, String)> get _rows {
    final auth = AuthService();
    final info = widget.info;
    final id = '${auth.user?['UserId'] ?? auth.user?['id'] ?? '-'}';
    return [
      ('앱 버전 / 빌드', info?.detailVersion ?? '-'),
      ('서버', auth.baseUrl),
      ('로그인', auth.token == null ? '로그아웃 상태' : '로그인됨'),
      ('사용자 ID', id),
      ('권한', _permissions),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return V2Theme(
      dark: true,
      child: Scaffold(
        appBar: const V2Header(title: '진단'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text('개발자 전용 화면이에요.', style: V2Text.cap),
            const SizedBox(height: 12),
            MoreInfoGroup(
              children: [
                for (final r in rows) MoreInfoRow(label: r.$1, value: r.$2),
              ],
            ),
            const SizedBox(height: 16),
            V2Button(
              label: '진단 정보 복사',
              icon: V2Icons.copy,
              variant: V2ButtonVariant.soft,
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text: rows.map((r) => '${r.$1}: ${r.$2}').join('\n'),
                  ),
                );
                if (context.mounted) showV2Snack(context, '진단 정보를 복사했어요');
              },
            ),
          ],
        ),
      ),
    );
  }
}
