import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:secret_base_app/core/app_changelog.dart';
import 'package:secret_base_app/core/app_info.dart';

void main() {
  group('AppInfo formatting', () {
    test('shows version and build number', () {
      const info = AppInfo(version: '2.0.0', buildNumber: '2');
      expect(info.displayVersion, 'v2.0.0');
      expect(info.fullVersion, 'v2.0.0 (빌드 2)');
    });

    test('omits the build number when the platform cannot provide it', () {
      const info = AppInfo(version: '2.0.0', buildNumber: '');
      expect(info.fullVersion, 'v2.0.0');
    });

    test('appends the build id only when present', () {
      const withId = AppInfo(
        version: '2.0.0',
        buildNumber: '2',
        buildId: '20261106120000',
      );
      const without = AppInfo(version: '2.0.0', buildNumber: '2', buildId: '');
      expect(withId.detailVersion, 'v2.0.0 (빌드 2) · 20261106120000');
      expect(without.detailVersion, 'v2.0.0 (빌드 2)');
      expect(withId.clipboardText, '비밀기지 v2.0.0 (빌드 2) · 20261106120000');
    });

    test(
      'an unknown version formats to empty strings, never a fake number',
      () {
        const info = AppInfo(version: '  ', buildNumber: '7', buildId: 'x');
        expect(info.hasVersion, isFalse);
        expect(info.displayVersion, '');
        expect(info.fullVersion, '');
        expect(info.detailVersion, '');
      },
    );

    test('the build id defaults to empty without --dart-define', () {
      expect(AppInfoConstants.buildId, '');
    });

    test('load reads the platform package info', () async {
      PackageInfo.setMockInitialValues(
        appName: 'Secret Base',
        packageName: 'app.secretbase',
        version: '9.8.7',
        buildNumber: '65',
        buildSignature: '',
      );
      final info = await AppInfo.load();
      expect(info.fullVersion, 'v9.8.7 (빌드 65)');
      expect(AppInfo.current?.version, '9.8.7');
    });
  });

  group('single source of truth', () {
    test('pubspec version matches the newest changelog entry', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(
        r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(match, isNotNull, reason: 'pubspec needs version: x.y.z+build');
      expect(kChangelog.first.version, match!.group(1));

      final md = File('CHANGELOG.md').readAsStringSync();
      expect(md, contains('## [${match.group(1)}]'));
      for (final entry in kChangelog) {
        expect(md, contains('## [${entry.version}] - ${entry.date}'));
      }
    });

    test('android versionName/versionCode derive from pubspec', () {
      final gradle = File('android/app/build.gradle.kts').existsSync()
          ? File('android/app/build.gradle.kts').readAsStringSync()
          : File('android/app/build.gradle').readAsStringSync();
      expect(gradle, contains('flutter.versionName'));
      expect(gradle, contains('flutter.versionCode'));
    });
  });
}
