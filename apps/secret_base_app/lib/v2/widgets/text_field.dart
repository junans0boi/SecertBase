import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../tokens.dart';
import '../typography.dart';
import 'icons.dart';

/// Labelled 52px text field (ds.css `.field .inp .help`) with a rose focus
/// ring, error state and optional password visibility toggle.
///
/// ```dart
/// V2TextField(label: '이메일', hint: 'name@example.com', controller: email,
///     keyboardType: TextInputType.emailAddress)
/// V2TextField(label: '비밀번호', password: true, error: '8자 이상 입력해 주세요')
/// V2TextField(label: '한마디', maxLines: 4, help: '서윤에게만 보여요')
/// ```
class V2TextField extends StatefulWidget {
  const V2TextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.help,
    this.error,
    this.password = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.maxLines = 1,
    this.maxLength,
    this.autofillHints,
    this.inputFormatters,
    this.prefixIcon,
    this.suffix,
    this.readOnly = false,
    this.onTap,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;

  /// Helper text under the field (hidden while [error] is shown).
  final String? help;

  /// Error message; turns the field red and announces it.
  final String? error;

  /// Obscures text and adds a 보기/숨기기 toggle.
  final bool password;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final int maxLines;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  State<V2TextField> createState() => _V2TextFieldState();
}

class _V2TextFieldState extends State<V2TextField> {
  FocusNode? _ownFocus;
  bool _obscure = true;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(V2TextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final hasError = widget.error != null && widget.error!.isNotEmpty;
    final focused = _focus.hasFocus;
    final borderColor = !widget.enabled
        ? p.line
        : hasError
        ? p.err
        : focused
        ? p.primary
        : (p.dark ? p.line2 : V2Colors.fieldBorder);
    final ring = !widget.enabled
        ? null
        : hasError
        ? p.errSoft
        : focused
        ? p.primarySoft
        : null;
    final multiline = widget.maxLines > 1;

    final field = TextField(
      controller: widget.controller,
      focusNode: _focus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      autofocus: widget.autofocus,
      obscureText: widget.password && _obscure,
      enableSuggestions: !widget.password,
      autocorrect: !widget.password,
      keyboardType: widget.password
          ? TextInputType.visiblePassword
          : (widget.keyboardType ??
                (multiline ? TextInputType.multiline : null)),
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      maxLines: widget.password ? 1 : widget.maxLines,
      minLines: multiline ? 3 : 1,
      maxLength: widget.maxLength,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      cursorColor: p.primary,
      style: V2Text.body.copyWith(
        fontSize: 16,
        color: widget.enabled ? p.ink : p.disabled,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        hintText: widget.hint,
        hintStyle: V2Text.body.copyWith(fontSize: 16, color: p.muted),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        counterText: '',
        contentPadding: EdgeInsets.symmetric(
          horizontal: widget.prefixIcon == null ? 16 : 4,
          vertical: multiline ? 14 : 15,
        ),
      ),
    );

    final row = Row(
      crossAxisAlignment: multiline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (widget.prefixIcon != null)
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Icon(widget.prefixIcon, size: 20, color: p.muted),
          ),
        Expanded(child: field),
        ?widget.suffix,
        if (widget.password)
          IconButton(
            tooltip: _obscure ? '비밀번호 보기' : '비밀번호 숨기기',
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure ? V2Icons.visibility : V2Icons.visibilityOff,
              size: 20,
              color: p.sub,
            ),
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          ),
      ],
    );

    final message = hasError ? widget.error : widget.help;
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 6),
            child: Text(
              widget.label,
              style: V2Text.cap.copyWith(
                color: p.sub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AnimatedContainer(
            duration: V2Motion.of(context, V2Motion.fast),
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              color: widget.enabled ? p.surface : p.soft,
              borderRadius: V2Radius.ctlAll,
              border: Border.all(
                color: borderColor,
                width: focused || hasError ? 2 : 1.5,
              ),
              boxShadow: ring == null
                  ? null
                  : [BoxShadow(color: ring, spreadRadius: 4)],
            ),
            alignment: multiline ? Alignment.topLeft : Alignment.centerLeft,
            child: row,
          ),
          if (message != null && message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 2, right: 2, top: 6),
              child: Semantics(
                liveRegion: hasError,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasError) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 1, right: 4),
                        child: Icon(V2Icons.error, size: 16, color: p.err),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        message,
                        style: V2Text.cap.copyWith(
                          color: hasError ? p.err : p.sub,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
