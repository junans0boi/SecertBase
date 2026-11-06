import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_changelog.dart';
import '../../core/app_info.dart';
import '../../core/main_design.dart';

typedef LinkOpener = Future<void> Function(Uri uri);

Future<void> openExternalLink(Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // 열 수 있는 앱이 없을 때는 조용히 넘어간다.
  }
}

/// 업데이트 내역: [kChangelog]를 최신순으로 보여 준다.
class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({
    super.key,
    this.entries = kChangelog,
    this.currentVersion = '',
  });

  final List<ChangelogEntry> entries;

  /// 지금 설치된 버전. 같은 항목에 "현재 버전" 표시가 붙는다.
  final String currentVersion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        title: Text('업데이트 내역', style: mainTitle(size: 22)),
        backgroundColor: kMainBg,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _ChangelogCard(
          entry: entries[index],
          isCurrent: entries[index].version == currentVersion,
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
    return MainCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('v${entry.version}', style: mainTitle(size: 24)),
                    if (isCurrent)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: kMainRoseSoft,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          child: Text(
                            '현재 버전',
                            style: mainBody(
                              size: 11,
                              color: kMainRose,
                              weight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  entry.date,
                  style: mainBody(size: 12, color: kMainMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            entry.title,
            style: mainBody(size: 14, color: kMainInk, weight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (final item in entry.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: kMainRose,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(item, style: mainBody(size: 13, height: 1.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 개발자 정보: 앱 이름, 개발자/팀, 문의, 약관·정책 링크, 저작권, 오픈소스 라이선스.
///
/// 값이 비어 있는 항목([AppInfoConstants]에서 빈 문자열)은 줄째 숨긴다.
class DeveloperInfoScreen extends StatelessWidget {
  const DeveloperInfoScreen({
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

  void _showLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: AppInfoConstants.appNameKo,
      applicationVersion: info?.fullVersion,
      applicationLegalese: AppInfoConstants.copyrightLine,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = supportEmail.trim();
    final site = websiteUrl.trim();
    final details = <(IconData, Color, String, String)>[
      (
        Icons.favorite_rounded,
        kMainRose,
        '앱 이름',
        '${AppInfoConstants.appNameKo} / ${AppInfoConstants.appNameEn}',
      ),
      if (info != null && info!.hasVersion)
        (Icons.tag_rounded, kMainLilac, '버전', info!.fullVersion),
      (Icons.person_outline_rounded, kMainSky, '개발자', developerName),
      (Icons.groups_outlined, kMainSage, '팀', teamName),
      (Icons.business_outlined, kMainHoney, '운영자', legalOperatorName),
    ].where((row) => row.$4.trim().isNotEmpty).toList();

    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        title: Text('개발자 정보', style: mainTitle(size: 22)),
        backgroundColor: kMainBg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          _InfoSection(
            title: '앱과 개발자',
            children: [
              for (final (icon, color, label, value) in details)
                _DetailRow(
                  icon: icon,
                  color: color,
                  label: label,
                  value: value,
                ),
              if (email.isNotEmpty)
                _LinkTile(
                  icon: Icons.mail_outline_rounded,
                  color: kMainPeach,
                  title: '문의',
                  subtitle: email,
                  onTap: () => onOpenLink(Uri(scheme: 'mailto', path: email)),
                ),
              if (site.isNotEmpty)
                _LinkTile(
                  icon: Icons.public_rounded,
                  color: kMainSky,
                  title: '팀 홈페이지',
                  subtitle: site,
                  onTap: () => onOpenLink(Uri.parse(site)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _InfoSection(
            title: '약관과 정책',
            children: [
              _LinkTile(
                icon: Icons.shield_outlined,
                color: kMainSage,
                title: '개인정보 처리방침',
                onTap: () => onOpenLink(Uri.parse(AppInfoConstants.privacyUrl)),
              ),
              _LinkTile(
                icon: Icons.description_outlined,
                color: kMainSky,
                title: '이용약관',
                onTap: () => onOpenLink(Uri.parse(AppInfoConstants.termsUrl)),
              ),
              _LinkTile(
                icon: Icons.person_remove_outlined,
                color: kMainPeach,
                title: '회원 탈퇴 안내',
                onTap: () =>
                    onOpenLink(Uri.parse(AppInfoConstants.deleteAccountUrl)),
              ),
              _LinkTile(
                icon: Icons.article_outlined,
                color: kMainLilac,
                title: '오픈소스 라이선스',
                onTap: () => _showLicenses(context),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Center(
            child: Text(
              AppInfoConstants.copyrightLine,
              style: mainBody(size: 11, color: kMainMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: mainTitle(size: 22)),
        const SizedBox(height: 9),
        MainCard(
          radius: 26,
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(label, style: mainBody(size: 13, color: kMainMuted)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: mainBody(
                    size: 14,
                    color: kMainInk,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: subtitle == null ? title : '$title: $subtitle',
      button: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: mainBody(
                            size: 14,
                            color: kMainInk,
                            weight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: mainBody(size: 11, color: kMainMuted),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: kMainMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
