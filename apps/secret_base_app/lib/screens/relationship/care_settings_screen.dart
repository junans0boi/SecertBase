import 'package:flutter/material.dart';

import 'package:secret_base_app/v2/v2.dart';

import '../../core/safety_location.dart';
import 'care_safety.dart';

/// 돌봄 설정: location use is chosen here, ahead of time (default OFF).
/// Nothing in the care area asks for location at the moment of a crisis.
class CareSettingsScreen extends StatefulWidget {
  const CareSettingsScreen({super.key, this.locationProvider});

  /// Used to request the OS permission when the toggle is switched on.
  final SafetyLocationProvider? locationProvider;

  @override
  State<CareSettingsScreen> createState() => _CareSettingsScreenState();
}

class _CareSettingsScreenState extends State<CareSettingsScreen> {
  bool _location = false;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    CarePrefs.locationEnabled().then((v) {
      if (!mounted) return;
      setState(() {
        _location = v;
        _loaded = true;
      });
    });
  }

  Future<void> _toggle(bool on) async {
    if (_busy) return;
    if (!on) {
      setState(() => _location = false);
      await CarePrefs.setLocationEnabled(false);
      return;
    }
    final choice = await showV2PermissionSheet(
      context,
      V2PermissionKind.location,
    );
    if (choice != V2PermissionChoice.allow || !mounted) return;
    setState(() => _busy = true);
    final provider =
        widget.locationProvider ?? const PlatformSafetyLocationProvider();
    SafetyLocation result;
    try {
      result = await provider.resolve();
    } catch (_) {
      result = const SafetyLocation.denied();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.permissionGranted) {
      await CarePrefs.setLocationEnabled(true);
      if (mounted) setState(() => _location = true);
    } else {
      await CarePrefs.setLocationEnabled(false);
      if (mounted) {
        setState(() => _location = false);
        showV2Snack(
          context,
          '위치를 켜지 못했어요. 기기 설정에서 허용한 뒤 다시 켜 주세요.',
          tone: V2Tone.warn,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Scaffold(
        appBar: const V2Header(title: '돌봄 설정'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(V2Space.page, 8, V2Space.page, 32),
          children: [
            V2List(
              children: [
                V2ListTile(
                  icon: V2Icons.myLocation,
                  tone: V2Tone.sky,
                  title: '도움 기관을 가까운 곳 기준으로',
                  subtitle: '미리 켜 두면 위기 안내에 지역 기관이 함께 나와요. 위치는 저장하지 않아요.',
                  trailing: V2Toggle(
                    value: _location,
                    semanticLabel: '가까운 기관 안내 위치 사용',
                    onChanged: _loaded ? _toggle : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '꺼 두어도 112·119·109 같은 기본 안내는 항상 보여요. 급할 때 위치 허용을 묻지 않아요.',
              style: V2Text.cap,
            ),
            const V2Section(
              title: '언제든 쓸 수 있는 연락처',
              child: CrisisContactsCard(),
            ),
            const SizedBox(height: 16),
            const CareAiNotice(),
          ],
        ),
      ),
    );
  }
}
