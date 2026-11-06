// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/services.dart';

enum ShareImageResult { downloaded, copiedText, failed }

/// Web: download the PNG; the caption is also copied for pasting.
Future<ShareImageResult> saveOrShareImage(
  Uint8List bytes,
  String fileName,
  String caption,
) async {
  try {
    final blob = html.Blob([bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    try {
      await Clipboard.setData(ClipboardData(text: caption));
    } catch (_) {}
    return ShareImageResult.downloaded;
  } catch (_) {
    try {
      await Clipboard.setData(ClipboardData(text: caption));
      return ShareImageResult.copiedText;
    } catch (_) {
      return ShareImageResult.failed;
    }
  }
}
