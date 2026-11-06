import 'package:package_info_plus/package_info_plus.dart';

import 'legal_urls.dart';

/// 앱 이름, 개발자/문의 정보, 버전을 한곳에서 관리한다.
///
/// 버전의 단일 출처는 `pubspec.yaml`의 `version:` 이다. 런타임에는
/// `package_info_plus`가 (Android versionName/versionCode, iOS, 웹의
/// version.json 에서) 그 값을 읽어 오므로 이 파일에 버전 숫자를 적지 않는다.
///
/// 개발자 정보는 저장소에 이미 공개돼 있는 값만 적는다. 값이 없는 항목은
/// 빈 문자열로 두면 화면에서 해당 줄이 숨겨진다.
abstract final class AppInfoConstants {
  static const appNameKo = '비밀기지';
  static const appNameEn = 'Secret Base';

  /// 개발자(대표) 이름. 오너가 확정한 값(2026-11-06).
  static const developerName = '이준환 (LeeJunHwan)';

  /// 팀(스튜디오) 이름. 오너가 확정한 값(2026-11-06).
  static const teamName = 'SteadyToVivid';

  /// 팀 홈페이지. 오너가 확정한 값(2026-11-06).
  static const websiteUrl = 'https://steady2vivid.kro.kr/';

  /// 운영자 법적 명칭. 개인정보 처리방침·이용약관이 "미확인"으로 표시한 항목이라
  /// 오너가 확정하기 전까지 비워 둔다.
  static const legalOperatorName = '';

  /// 문의 이메일. 오너가 확정한 값(2026-11-06). 고객센터 시트의 [kSupportEmail]과 같다.
  static const supportEmail = 'junans0boi@naver.com';

  static const copyrightYear = 2026;
  static const copyrightHolder = 'SteadyToVivid';

  /// `--dart-define=BUILD_ID=...` 로 주입되는 빌드 식별자(배포 스크립트는 빌드
  /// 시각, CI 라면 커밋 해시 등). 없으면 빈 문자열이라 화면에 나타나지 않는다.
  static const buildId = String.fromEnvironment('BUILD_ID');

  static const privacyUrl = kPrivacyUrl;
  static const termsUrl = kTermsUrl;
  static const deleteAccountUrl = kDeleteAccountUrl;

  static String get copyrightLine =>
      '© $copyrightYear $copyrightHolder. All Rights Reserved.';
}

/// 실행 중인 앱의 버전 정보.
class AppInfo {
  const AppInfo({
    required this.version,
    required this.buildNumber,
    this.buildId = AppInfoConstants.buildId,
  });

  /// `pubspec.yaml`의 `x.y.z` 부분. 알 수 없으면 빈 문자열.
  final String version;

  /// `pubspec.yaml`의 `+N` 부분. 웹 등에서 알 수 없으면 빈 문자열.
  final String buildNumber;

  /// 선택적인 빌드 식별자(dart-define). 없으면 빈 문자열.
  final String buildId;

  /// 가장 최근에 [load]한 값. 앱 시작 시 한 번 채워진다.
  static AppInfo? current;

  static Future<AppInfo> load() async {
    final info = await PackageInfo.fromPlatform();
    return current = AppInfo(
      version: info.version,
      buildNumber: info.buildNumber,
    );
  }

  bool get hasVersion => version.trim().isNotEmpty;

  /// `v2.0.0`. 버전을 모르면 빈 문자열.
  String get displayVersion => hasVersion ? 'v${version.trim()}' : '';

  /// `v2.0.0 (빌드 2)`. 빌드 번호를 모르면 `v2.0.0`.
  String get fullVersion {
    if (!hasVersion) return '';
    final build = buildNumber.trim();
    return build.isEmpty ? displayVersion : '$displayVersion (빌드 $build)';
  }

  /// `v2.0.0 (빌드 2) · 20261106120000`. 빌드 식별자가 없으면 [fullVersion].
  String get detailVersion {
    final id = buildId.trim();
    if (!hasVersion || id.isEmpty) return fullVersion;
    return '$fullVersion · $id';
  }

  /// 문의할 때 붙여 넣기 좋은 한 줄.
  String get clipboardText => '${AppInfoConstants.appNameKo} $detailVersion';
}
