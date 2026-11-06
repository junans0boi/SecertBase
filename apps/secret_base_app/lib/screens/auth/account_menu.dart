import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth_service.dart';
import '../../core/legal_urls.dart';
import '../../core/support_contact.dart';
import '../../v2/v2.dart';
import 'auth_parts.dart';
import 'withdraw_screen.dart';

/// 연결 전에도 닿는 계정 메뉴: 고객센터·약관·개인정보처리방침·로그아웃·회원 탈퇴.
Future<void> showAccountSheet(BuildContext context) {
  final auth = AuthService();
  final nick = '${auth.user?['Nickname'] ?? auth.user?['UserName'] ?? ''}'
      .trim();
  final email = '${auth.user?['Email'] ?? auth.user?['email'] ?? ''}'.trim();
  final paired = auth.user?['PartnerCode']?.toString().isNotEmpty == true;
  final rootContext = context;
  return showV2Sheet<void>(
    context,
    title: '계정',
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        V2ListTile(
          icon: V2Icons.person,
          title: nick.isEmpty ? '내 계정' : nick,
          subtitle: [
            if (email.isNotEmpty) email,
            if (!paired) '연결 전',
          ].join(' · '),
        ),
        const SizedBox(height: V2Space.x2),
        V2List(
          children: [
            V2ListTile(
              icon: V2Icons.help,
              tone: V2Tone.sky,
              title: '고객센터',
              subtitle: kSupportEmail,
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  await launchUrl(
                    Uri(
                      scheme: 'mailto',
                      path: kSupportEmail,
                      queryParameters: {'subject': '[비밀기지] 문의'},
                    ),
                  );
                } catch (_) {}
              },
            ),
            V2ListTile(
              icon: V2Icons.text,
              title: '이용약관',
              onTap: () => openLegalUrl(kTermsUrl),
            ),
            V2ListTile(
              icon: V2Icons.shield,
              title: '개인정보처리방침',
              onTap: () => openLegalUrl(kPrivacyUrl),
            ),
            V2ListTile(
              icon: V2Icons.logout,
              title: '로그아웃',
              onTap: () async {
                Navigator.pop(sheetContext);
                if (!rootContext.mounted) return;
                final ok = await showV2Confirm(
                  rootContext,
                  title: '로그아웃할까요?',
                  message: '언제든 다시 로그인할 수 있어요.',
                  confirmLabel: '로그아웃',
                );
                if (ok) await auth.logout();
              },
            ),
            V2ListTile(
              icon: V2Icons.delete,
              title: '회원 탈퇴',
              destructive: true,
              onTap: () {
                Navigator.pop(sheetContext);
                if (!rootContext.mounted) return;
                Navigator.push(
                  rootContext,
                  MaterialPageRoute(builder: (_) => const WithdrawScreen()),
                );
              },
            ),
          ],
        ),
      ],
    ),
  );
}
