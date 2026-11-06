import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import '../typography.dart';
import 'button.dart';
import 'check.dart';
import 'icons.dart';
import 'illustration.dart';
import 'sheet.dart';

/// Sheet for heavy destructive actions (탈퇴, 연결 끊기, 전체 삭제): lists
/// consequences and can require an acknowledgement checkbox before the
/// red button enables. Returns true only when confirmed.
///
/// ```dart
/// final ok = await showV2ConfirmDestructiveSheet(context,
///   title: '정말 탈퇴할까요?',
///   message: '탈퇴하면 아래 내용이 모두 사라져요.',
///   consequences: ['서윤과의 연결이 끊어져요', '기록과 사진이 삭제돼요'],
///   acknowledgement: '모두 삭제되는 것을 확인했어요',
///   confirmLabel: '탈퇴하기',
/// );
/// ```
Future<bool> showV2ConfirmDestructiveSheet(
  BuildContext context, {
  required String title,
  String? message,
  List<String> consequences = const [],
  String? acknowledgement,
  String confirmLabel = '삭제하기',
  String cancelLabel = '취소',
}) async {
  final result = await showV2Sheet<bool>(
    context,
    builder: (ctx) => V2ConfirmDestructiveSheet(
      title: title,
      message: message,
      consequences: consequences,
      acknowledgement: acknowledgement,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      onResult: (v) => Navigator.of(ctx).pop(v),
    ),
  );
  return result ?? false;
}

/// Body of [showV2ConfirmDestructiveSheet].
class V2ConfirmDestructiveSheet extends StatefulWidget {
  const V2ConfirmDestructiveSheet({
    super.key,
    required this.title,
    required this.onResult,
    this.message,
    this.consequences = const [],
    this.acknowledgement,
    this.confirmLabel = '삭제하기',
    this.cancelLabel = '취소',
  });

  final String title;
  final String? message;
  final List<String> consequences;
  final String? acknowledgement;
  final String confirmLabel;
  final String cancelLabel;
  final ValueChanged<bool> onResult;

  @override
  State<V2ConfirmDestructiveSheet> createState() =>
      _V2ConfirmDestructiveSheetState();
}

class _V2ConfirmDestructiveSheetState extends State<V2ConfirmDestructiveSheet> {
  bool _ack = false;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final needsAck = widget.acknowledgement != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: V2Art(icon: V2Icons.warn, tone: V2Tone.err, size: 72),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            widget.title,
            textAlign: TextAlign.center,
            style: V2Text.title.copyWith(color: p.ink),
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.message!,
            textAlign: TextAlign.center,
            style: V2Text.body.copyWith(color: p.sub),
          ),
        ],
        if (widget.consequences.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.dark ? p.soft : V2Colors.errSoft,
              borderRadius: V2Radius.buttonAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in widget.consequences)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Icon(
                            V2Icons.close,
                            size: 14,
                            color: p.dark ? p.err : V2Colors.errText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c,
                            style: V2Text.body.copyWith(
                              fontSize: 14,
                              height: 20 / 14,
                              color: p.dark ? p.ink : V2Colors.errText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (needsAck) ...[
          const SizedBox(height: 8),
          V2Check(
            value: _ack,
            label: widget.acknowledgement,
            onChanged: (v) => setState(() => _ack = v),
          ),
        ],
        const SizedBox(height: 20),
        V2Button(
          label: widget.confirmLabel,
          variant: V2ButtonVariant.danger,
          onPressed: !needsAck || _ack ? () => widget.onResult(true) : null,
        ),
        const SizedBox(height: 4),
        V2Button(
          label: widget.cancelLabel,
          variant: V2ButtonVariant.text,
          onPressed: () => widget.onResult(false),
        ),
      ],
    );
  }
}
