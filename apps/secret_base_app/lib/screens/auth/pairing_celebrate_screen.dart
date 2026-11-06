import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/push/push_service.dart';
import '../../v2/v2.dart';
import 'auth_parts.dart';

/// 연결 직후 한 번 보여 주는 축하 화면 + 첫 사용 체크리스트(시작일·첫 순간·알림).
/// 알림은 이 화면에서 용도 안내 시트를 거친 뒤에만 OS에 묻는다.
class PairingCelebrateScreen extends StatefulWidget {
  const PairingCelebrateScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<PairingCelebrateScreen> createState() => _PairingCelebrateScreenState();
}

class _PairingCelebrateScreenState extends State<PairingCelebrateScreen> {
  final _auth = AuthService();
  bool _notificationOn = false;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    PushService.instance.isPermissionGranted().then((granted) {
      if (!mounted) return;
      setState(() => _notificationOn = granted);
      if (!granted) {
        // 축하를 먼저 보여 주고 잠시 뒤 알림 안내를 띄운다.
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _askNotification();
        });
      }
    });
  }

  String get _partnerName {
    final v = _auth.user?['PartnerName'];
    return v is String && v.trim().isNotEmpty ? v.trim() : '상대';
  }

  String get _myName {
    final v = '${_auth.user?['Nickname'] ?? _auth.user?['UserName'] ?? ''}'
        .trim();
    return v.isEmpty ? '나' : v;
  }

  Future<void> _askNotification() async {
    if (_asking || _notificationOn) return;
    _asking = true;
    try {
      final choice = await showV2PermissionSheet(
        context,
        V2PermissionKind.notification,
        purpose: '$_partnerName님이 순간을 남기거나 기념일이 다가오면 알려드려요.',
        points: ['$_partnerName님이 순간을 남기면', '기념일 하루 전에', '광고 알림은 보내지 않아요'],
      );
      if (choice != V2PermissionChoice.allow || !mounted) return;
      final granted = await PushService.instance.requestPermissionFromUser();
      if (!mounted) return;
      setState(() => _notificationOn = granted);
      if (!granted) {
        await showV2PermissionSheet(
          context,
          V2PermissionKind.notification,
          denied: true,
        );
      }
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = 1 + (_notificationOn ? 1 : 0);
    return AuthFrame(
      hero: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: V2Space.x6),
          Center(
            child: V2AvatarPair(me: _myName, partner: _partnerName),
          ),
          const SizedBox(height: V2Space.x5),
          Text('연결됐어요!', textAlign: TextAlign.center, style: V2Text.display),
          const SizedBox(height: V2Space.x1),
          Text(
            '둘만의 비밀기지가 열렸어요',
            textAlign: TextAlign.center,
            style: V2Text.body,
          ),
          const SizedBox(height: V2Space.x8),
          Row(
            children: [
              Expanded(child: Text('이렇게 시작해 보세요', style: V2Text.head)),
              Text('$done/3', style: V2Text.cap),
            ],
          ),
          const SizedBox(height: V2Space.x3),
          V2List(
            children: [
              V2ListTile(
                icon: V2Icons.ok,
                tone: V2Tone.sage,
                title: '$_partnerName님과 연결하기',
                subtitle: '완료했어요',
              ),
              V2ListTile(
                icon: V2Icons.calendar,
                tone: V2Tone.peach,
                title: '처음 만난 날 정하기',
                subtitle: '홈에서 D+ 날짜를 정할 수 있어요',
                onTap: widget.onDone,
              ),
              V2ListTile(
                icon: V2Icons.camera,
                tone: V2Tone.sky,
                title: '첫 순간 남기기',
                subtitle: '오늘의 사진 한 장이면 충분해요',
                onTap: widget.onDone,
              ),
              V2ListTile(
                icon: _notificationOn ? V2Icons.ok : V2Icons.bell,
                tone: _notificationOn ? V2Tone.sage : V2Tone.lilac,
                title: '알림 켜기',
                subtitle: _notificationOn
                    ? '켜 두었어요'
                    : '$_partnerName님의 기록을 바로 알려드려요',
                onTap: _notificationOn ? null : _askNotification,
              ),
            ],
          ),
        ],
      ),
      footer: V2Button(label: '홈으로 가기', onPressed: widget.onDone),
    );
  }
}
