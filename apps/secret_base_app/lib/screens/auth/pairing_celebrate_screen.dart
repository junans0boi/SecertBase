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
        title: '$_partnerName님의 소식을 알려드릴까요?',
        purpose: '$_partnerName님이 순간을 남기거나 기념일이 다가오면 알려드려요.',
        points: ['$_partnerName님이 순간을 남기면', '기념일 하루 전에', '광고 알림은 보내지 않아요'],
        pointIcons: const [
          V2Icons.heartOutline,
          V2Icons.calendar,
          V2Icons.shield,
        ],
        allowLabel: '알림 받기',
        laterLabel: '나중에 할게요',
        footnote: '다음에 나오는 안내에서 “허용”을 눌러 주세요',
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
    final p = V2Palette.of(context);
    final done = 1 + (_notificationOn ? 1 : 0);
    return V2Theme(
      child: Scaffold(
        backgroundColor: p.bg,
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _hero(context),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            V2Space.page,
                            V2Space.x6,
                            V2Space.page,
                            V2Space.x4,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '이렇게 시작해 보세요',
                                      style: V2Text.head,
                                    ),
                                  ),
                                  Text(
                                    '$done/3',
                                    style: V2Text.bodyStrong.copyWith(
                                      color: p.sub,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: V2Space.x3),
                              _checklist(p),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      V2Space.page,
                      V2Space.x2,
                      V2Space.page,
                      V2Space.x4,
                    ),
                    child: V2Button(label: '홈으로 가기', onPressed: widget.onDone),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 장미빛 그라데이션 상단: 두 사람의 이니셜 원 사이에 하트, 반짝이.
  Widget _hero(BuildContext context) {
    final p = V2Palette.of(context);
    Widget initial(String name, Color color) => Container(
      width: 76,
      height: 76,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Text(
        name.isEmpty ? '?' : String.fromCharCode(name.runes.first),
        textScaler: TextScaler.noScaling,
        style: V2Text.sans(
          size: 30,
          weight: FontWeight.w800,
          color: color,
          height: 1,
        ),
      ),
    );
    return AuthHeroBlock(
      padding: const EdgeInsets.fromLTRB(
        V2Space.page,
        V2Space.x12 + V2Space.x10,
        V2Space.page,
        V2Space.x4,
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          const Positioned(
            right: 24,
            top: 0,
            child: Icon(V2Icons.sparkle, size: 22, color: Colors.white),
          ),
          const Positioned(
            left: 30,
            bottom: 0,
            child: Icon(V2Icons.sparkle, size: 24, color: Colors.white),
          ),
          Column(
            children: [
              Semantics(
                label: '$_myName, $_partnerName',
                excludeSemantics: true,
                child: SizedBox(
                  width: 176,
                  height: 76,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(left: 0, child: initial(_myName, p.primary)),
                      Positioned(
                        right: 0,
                        child: initial(_partnerName, V2Avatar.partnerColor),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: V2Shadow.level2,
                        ),
                        child: Icon(V2Icons.heart, size: 24, color: p.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: V2Space.x5),
              Semantics(
                header: true,
                child: Text(
                  '연결됐어요!',
                  textAlign: TextAlign.center,
                  style: V2Text.display.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: V2Space.x1),
              Text(
                '둘만의 비밀기지가 열렸어요',
                textAlign: TextAlign.center,
                style: V2Text.head.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: V2Space.x12),
            ],
          ),
        ],
      ),
    );
  }

  Widget _checklist(V2Palette p) {
    final rows = <Widget>[
      _StartTile(done: true, title: '$_partnerName님과 연결하기'),
      _StartTile(
        title: '처음 만난 날 정하기',
        subtitle: '홈에서 D+ 날짜를 정할 수 있어요',
        onTap: widget.onDone,
      ),
      _StartTile(
        title: '첫 순간 남기기',
        subtitle: '오늘의 사진 한 장이면 충분해요',
        onTap: widget.onDone,
      ),
      _StartTile(
        done: _notificationOn,
        title: '알림 켜기',
        subtitle: _notificationOn ? '켜 두었어요' : '$_partnerName님의 기록을 바로 알려드려요',
        onTap: _notificationOn ? null : _askNotification,
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: V2Radius.cardAll,
        border: Border.all(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: p.line),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// 체크리스트 한 줄: 동그라미 체크 + 제목/설명 + (눌러 갈 수 있으면) 화살표.
class _StartTile extends StatelessWidget {
  const _StartTile({
    required this.title,
    this.subtitle,
    this.done = false,
    this.onTap,
  });
  final String title;
  final String? subtitle;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Semantics(
      button: onTap != null,
      label:
          '$title${done ? ', 완료' : ''}${subtitle == null ? '' : ', $subtitle'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: V2Space.x4,
              vertical: V2Space.x3,
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? p.primary : null,
                    border: done ? null : Border.all(color: p.line2, width: 2),
                  ),
                  child: done
                      ? Icon(V2Icons.check, size: 16, color: p.onPrimary)
                      : null,
                ),
                const SizedBox(width: V2Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: V2Text.bodyStrong.copyWith(
                          fontSize: 16,
                          color: done ? p.sub : p.ink,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (subtitle != null) Text(subtitle!, style: V2Text.cap),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(V2Icons.chevron, size: 20, color: p.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
