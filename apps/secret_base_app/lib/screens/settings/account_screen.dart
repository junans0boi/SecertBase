import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/socket_service.dart';
import '../../v2/v2.dart';
import 'delete_account_screen.dart';
import 'settings_common.dart';

/// 계정: 로그인 방법, 로그아웃, 위험 구역(회원 탈퇴).
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await showV2Confirm(
      context,
      title: '로그아웃할까요?',
      message: '다시 로그인하면 기록을 그대로 볼 수 있어요.',
      confirmLabel: '로그아웃',
      cancelLabel: '취소',
    );
    if (!ok || !context.mounted) return;
    await logoutToStart(context, before: SocketService().disconnect);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().user;
    final google = isGoogleAccount(user);
    final email = '${user?['Email'] ?? user?['email'] ?? ''}'.trim();
    return V2Theme(
      child: Scaffold(
        appBar: const V2Header(title: '계정'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            MoreInfoGroup(
              children: [
                MoreInfoRow(
                  label: '로그인 방법',
                  value: email.isEmpty
                      ? (google ? 'Google' : '이메일')
                      : '${google ? 'Google' : '이메일'} · $email',
                ),
              ],
            ),
            const SizedBox(height: 12),
            V2List(
              children: [
                V2ListTile(
                  icon: V2Icons.logout,
                  tone: V2Tone.neutral,
                  title: '로그아웃',
                  subtitle: '다시 로그인하면 기록은 그대로예요',
                  onTap: () => _logout(context),
                ),
              ],
            ),
            const SizedBox(height: 32),
            MoreDangerZone(
              title: '위험 구역',
              message: '탈퇴하면 기록, 사진, 코인과 아이템이 모두 삭제돼요. 되돌릴 수 없어요.',
              child: V2Button(
                label: '회원 탈퇴',
                variant: V2ButtonVariant.dangerSoft,
                onPressed: () =>
                    pushMorePage<void>(context, const DeleteAccountScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
