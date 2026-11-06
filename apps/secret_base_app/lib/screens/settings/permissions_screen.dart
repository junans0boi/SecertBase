import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../v2/v2.dart';
import 'permission_probe.dart';
import 'settings_common.dart';

/// 개인정보·권한: 위치·카메라·알림이 어떤 상태이고 어디서 바꾸는지 보여 줘요.
/// 이 화면은 권한을 묻지 않고(읽기 전용) 상태만 읽어요.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({
    super.key,
    this.probe = const DevicePermissionProbe(),
    this.onOpenLink = openExternalLink,
  });

  final PermissionProbe probe;
  final LinkOpener onOpenLink;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  OsPermission? _location;
  OsPermission? _notification;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _read();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 설정 앱에서 돌아오면 바뀐 상태를 다시 읽어요.
    if (state == AppLifecycleState.resumed) _read();
  }

  Future<void> _read() async {
    final location = await widget.probe.location();
    final notification = await widget.probe.notification();
    if (!mounted) return;
    setState(() {
      _location = location;
      _notification = notification;
    });
  }

  Future<void> _openSettings() async {
    final opened = await widget.probe.openSettings();
    if (!opened && mounted) {
      showV2Snack(context, '설정을 열 수 없어요. 휴대폰 설정에서 비밀기지를 찾아 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Scaffold(
        appBar: const V2Header(title: '개인정보·권한', subtitle: '필요한 순간에만 물어봐요'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            _PermissionCard(
              icon: V2Icons.location,
              tone: V2Tone.sage,
              title: '위치',
              state: _location,
              purpose: '지도에서 내 주변 장소를 찾을 때만 써요.',
              canOpenSettings: widget.probe.canOpenSettings,
              onOpenSettings: _openSettings,
            ),
            const SizedBox(height: 12),
            _PermissionCard(
              icon: V2Icons.camera,
              tone: V2Tone.sky,
              title: '카메라·사진',
              state: OsPermission.notAsked,
              purpose: '기록할 사진이나 영상을 찍고 고를 때 써요.',
              canOpenSettings: widget.probe.canOpenSettings,
              onOpenSettings: _openSettings,
            ),
            const SizedBox(height: 12),
            _PermissionCard(
              icon: V2Icons.bell,
              tone: V2Tone.lilac,
              title: '알림',
              state: _notification,
              purpose: '파트너의 새 기록과 기념일 소식을 받을 때 써요.',
              canOpenSettings: widget.probe.canOpenSettings,
              onOpenSettings: _openSettings,
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 12),
              Text(
                '웹에서는 브라우저 주소창 왼쪽의 자물쇠 버튼에서 권한을 바꿀 수 있어요.',
                style: V2Text.cap,
              ),
            ],
            V2Section(
              title: '약관과 정책',
              padding: EdgeInsets.zero,
              child: V2List(
                children: [
                  V2ListTile(
                    icon: V2Icons.shield,
                    tone: V2Tone.sage,
                    title: '개인정보 처리방침',
                    onTap: () => widget.onOpenLink(
                      Uri.parse(AppInfoConstants.privacyUrl),
                    ),
                  ),
                  V2ListTile(
                    icon: V2Icons.text,
                    tone: V2Tone.sky,
                    title: '이용약관',
                    onTap: () =>
                        widget.onOpenLink(Uri.parse(AppInfoConstants.termsUrl)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.tone,
    required this.title,
    required this.state,
    required this.purpose,
    required this.canOpenSettings,
    required this.onOpenSettings,
  });

  final IconData icon;
  final V2Tone tone;
  final String title;
  final OsPermission? state;
  final String purpose;
  final bool canOpenSettings;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final t = V2ToneColors.of(tone);
    final (label, chipTone, icon2) = switch (state) {
      OsPermission.granted => ('허용됨', V2Tone.ok, V2Icons.ok),
      OsPermission.denied => ('꺼짐', V2Tone.warn, V2Icons.warn),
      OsPermission.notAsked => ('쓸 때 물어봐요', V2Tone.neutral, V2Icons.info),
      OsPermission.unknown => ('확인할 수 없어요', V2Tone.neutral, V2Icons.info),
      null => ('확인하는 중', V2Tone.neutral, V2Icons.info),
    };
    return V2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: t.soft,
                  borderRadius: BorderRadius.circular(V2Radius.ctl),
                ),
                child: Icon(icon, color: t.text, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: V2Text.head)),
              V2Chip(label: label, tone: chipTone, icon: icon2),
            ],
          ),
          const SizedBox(height: 10),
          Text(purpose, style: V2Text.cap),
          if (state == OsPermission.denied && canOpenSettings) ...[
            const SizedBox(height: 12),
            V2Button(
              label: '휴대폰 설정에서 켜기',
              variant: V2ButtonVariant.soft,
              size: V2ButtonSize.sm,
              onPressed: onOpenSettings,
            ),
          ],
        ],
      ),
    );
  }
}
