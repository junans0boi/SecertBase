import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/support_contact.dart';
import '../../v2/v2.dart';
import 'settings_common.dart';

class _Faq {
  const _Faq(this.category, this.question, this.answer);
  final String category;
  final String question;
  final String answer;
}

const _faqCategories = ['전체', '연결', '기록', '알림', '코인'];

const _faqs = [
  _Faq(
    '연결',
    '파트너와 연결이 안 돼요',
    '연결 코드가 잘못 입력됐거나 만료됐을 수 있어요. 새 코드를 받아 다시 입력해 보세요. 두 사람 모두 같은 앱 버전인지도 확인해 주세요.',
  ),
  _Faq(
    '알림',
    '알림이 오지 않아요',
    '더보기의 알림에서 받고 싶은 알림이 켜져 있는지 확인해 주세요. 휴대폰 설정에서 알림이 꺼져 있으면 개인정보·권한에서 켜는 방법을 볼 수 있어요.',
  ),
  _Faq(
    '기록',
    '사진이나 영상이 올라가지 않아요',
    '인터넷 연결을 확인하고 다시 시도해 주세요. 영상은 길이가 길면 올라가지 않을 수 있어요. 올리지 못한 기록은 기기에 남아 있다가 연결되면 다시 올려요.',
  ),
  _Faq(
    '기록',
    '탈퇴하면 기록은 어떻게 되나요?',
    '탈퇴하면 내가 남긴 기록과 미디어가 영구 삭제되고, 연결된 커플 공간이 닫혀요. 되돌릴 수 없으니 신중하게 결정해 주세요.',
  ),
  _Faq(
    '연결',
    '개인 보관함이 뭔가요?',
    '파트너와 연결하기 전에 남긴 나만의 기록이에요. 연결을 해제하면 내가 남긴 기록이 개인 보관함에 남아요.',
  ),
  _Faq(
    '코인',
    '코인은 어떻게 얻나요?',
    '게임에서 이기거나 미션을 완료하면 코인을 얻어요. 상점의 ‘코인 얻는 법’에서 자세히 볼 수 있어요.',
  ),
];

/// 고객센터·FAQ 시트. 문의 이메일 복사, 메일 앱 열기(안 열리면 안내).
Future<void> showSupportSheet(
  BuildContext context, {
  LinkOpener opener = openExternalLink,
}) {
  return showV2Sheet<void>(
    context,
    title: '고객센터',
    builder: (_) => SupportSheetBody(opener: opener),
  );
}

class SupportSheetBody extends StatefulWidget {
  const SupportSheetBody({super.key, this.opener = openExternalLink});

  final LinkOpener opener;

  @override
  State<SupportSheetBody> createState() => _SupportSheetBodyState();
}

class _SupportSheetBodyState extends State<SupportSheetBody> {
  String _category = _faqCategories.first;
  int? _open;
  String? _notice;

  Future<void> _copy() async {
    await Clipboard.setData(const ClipboardData(text: kSupportEmail));
    if (mounted) setState(() => _notice = '이메일 주소를 복사했어요.');
  }

  Future<void> _mail() async {
    final ok = await widget.opener(Uri(scheme: 'mailto', path: kSupportEmail));
    if (!ok && mounted) {
      await Clipboard.setData(const ClipboardData(text: kSupportEmail));
      if (mounted) {
        setState(() => _notice = '메일 앱을 열 수 없어요. 주소를 복사했으니 직접 보내 주세요.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final shown = [
      for (final f in _faqs)
        if (_category == '전체' || f.category == _category) f,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in _faqCategories)
              V2Chip(
                label: c,
                selected: _category == c,
                onTap: () => setState(() {
                  _category = c;
                  _open = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        V2List(
          children: [
            for (var i = 0; i < shown.length; i++)
              V2ListTile(
                icon: _open == i ? V2Icons.expand : V2Icons.help,
                tone: V2Tone.sky,
                title: shown[i].question,
                subtitle: _open == i ? shown[i].answer : null,
                showChevron: false,
                onTap: () => setState(() => _open = _open == i ? null : i),
              ),
          ],
        ),
        const SizedBox(height: 16),
        V2Card(
          variant: V2CardVariant.soft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('찾는 답이 없나요?', style: V2Text.bodyStrong),
              const SizedBox(height: 4),
              Text('아래 이메일로 문의해 주세요.', style: V2Text.cap),
              const SizedBox(height: 8),
              SelectableText(
                kSupportEmail,
                style: V2Text.bodyStrong.copyWith(color: p.primary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: V2Button(
                      label: '복사',
                      icon: V2Icons.copy,
                      variant: V2ButtonVariant.ghost,
                      size: V2ButtonSize.sm,
                      onPressed: _copy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: V2Button(
                      label: '메일 앱 열기',
                      icon: V2Icons.send,
                      size: V2ButtonSize.sm,
                      onPressed: _mail,
                    ),
                  ),
                ],
              ),
              if (_notice != null) ...[
                const SizedBox(height: 8),
                Text(_notice!, style: V2Text.cap.copyWith(color: p.primary)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
