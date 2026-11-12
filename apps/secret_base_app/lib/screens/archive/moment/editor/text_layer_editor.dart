import 'package:flutter/material.dart';

import '../../../../v2/v2.dart';
import 'editor_item.dart';

/// Result of the text overlay: the edited layer, or [deleted] when the
/// user cleared the text of an existing layer.
class TextLayerResult {
  final TextLayer? layer;
  final bool deleted;
  const TextLayerResult.save(TextLayer this.layer) : deleted = false;
  const TextLayerResult.delete() : layer = null, deleted = true;
}

/// Full-screen dim overlay for typing text onto a photo (Aa).
Future<TextLayerResult?> showTextLayerEditor(
  BuildContext context, {
  TextLayer? existing,
}) {
  return Navigator.of(context).push<TextLayerResult>(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (_, _, _) => _TextLayerEditor(existing: existing),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _TextLayerEditor extends StatefulWidget {
  const _TextLayerEditor({this.existing});
  final TextLayer? existing;

  @override
  State<_TextLayerEditor> createState() => _TextLayerEditorState();
}

class _TextLayerEditorState extends State<_TextLayerEditor> {
  late final _controller = TextEditingController(text: widget.existing?.text);
  late Color _color = widget.existing?.color ?? textLayerColors.first;
  late bool _boxed = widget.existing?.boxed ?? false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      Navigator.pop(
        context,
        widget.existing == null ? null : const TextLayerResult.delete(),
      );
      return;
    }
    final layer = widget.existing ?? TextLayer(text: text, color: _color);
    layer
      ..text = text
      ..color = _color
      ..boxed = _boxed;
    Navigator.pop(context, TextLayerResult.save(layer));
  }

  @override
  Widget build(BuildContext context) {
    final light = _color.computeLuminance() > .5;
    final textColor = _boxed
        ? (light ? const Color(0xFF111111) : Colors.white)
        : _color;
    return Material(
      color: Colors.black.withValues(alpha: .72),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    selected: _boxed,
                    label: _boxed ? '글자 배경 끄기' : '글자 배경 켜기',
                    child: IconButton(
                      key: const Key('text_layer_boxed'),
                      onPressed: () => setState(() => _boxed = !_boxed),
                      icon: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _boxed ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          'A',
                          style: V2Text.bodyStrong.copyWith(
                            color: _boxed ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('text_layer_done'),
                    onPressed: _done,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(56, 44),
                    ),
                    child: Text(
                      '완료',
                      style: V2Text.button.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _boxed ? _color : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: IntrinsicWidth(
                        child: TextField(
                          key: const Key('text_layer_field'),
                          controller: _controller,
                          autofocus: true,
                          maxLines: null,
                          maxLength: 80,
                          textAlign: TextAlign.center,
                          cursorColor: textColor,
                          style: V2Text.sans(
                            size: 28,
                            weight: FontWeight.w700,
                            color: textColor,
                            height: 1.25,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            counterText: '',
                            hintText: '글자 입력',
                            hintStyle: V2Text.sans(
                              size: 28,
                              weight: FontWeight.w700,
                              color: Colors.white38,
                            ),
                          ),
                          onSubmitted: (_) => _done(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final (i, c) in textLayerColors.indexed)
                    Semantics(
                      button: true,
                      selected: c == _color,
                      label: '글자색 ${i + 1}',
                      child: GestureDetector(
                        key: Key('text_layer_color_$i'),
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: Container(
                            width: c == _color ? 32 : 26,
                            height: c == _color ? 32 : 26,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ),
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
