
import 'package:flutter/services.dart';

/// Non-web fallback: no gallery/share plugin is bundled, so copy the caption
/// and report that the image itself was not saved.
Future<ShareImageResult> saveOrShareImage(
  Uint8List bytes,
  String fileName,
  String caption,
) async {
  await Clipboard.setData(ClipboardData(text: caption));
  return ShareImageResult.copiedText;
}

enum ShareImageResult { downloaded, copiedText, failed }
