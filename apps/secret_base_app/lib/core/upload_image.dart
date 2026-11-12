import 'package:flutter/material.dart';

/// Server thumbnail widths (`/uploads/w/{width}/{file}`, see the server's
/// shared/upload-thumbs.js).
const kThumbWidths = [160, 480, 1080];

final _uploadPath = RegExp(
  r'^/uploads/([A-Za-z0-9._-]+\.(?:jpe?g|png|webp|gif|heic|heif))$',
  caseSensitive: false,
);

/// Absolute URL for an uploaded file; with [width], the smallest server
/// thumbnail at least that wide (photos only). Anything that is not a plain
/// `/uploads/<file>` photo is returned unchanged.
String? uploadUrl(String? raw, String baseUrl, {int? width}) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();
  final absolute = value.startsWith('http') ? value : '$baseUrl$value';
  if (width == null) return absolute;
  final uri = Uri.tryParse(absolute);
  final match = uri == null ? null : _uploadPath.firstMatch(uri.path);
  if (uri == null || match == null) return absolute;
  final bucket = kThumbWidths.firstWhere(
    (w) => w >= width,
    orElse: () => kThumbWidths.last,
  );
  return uri.replace(path: '/uploads/w/$bucket/${match.group(1)}').toString();
}

/// Network image for an upload that asks for a small server copy first and
/// falls back to the original if that fails (old server, odd file).
class UploadImage extends StatefulWidget {
  const UploadImage({
    super.key,
    required this.raw,
    required this.baseUrl,
    this.pixelWidth,
    this.fit = BoxFit.cover,
    this.error,
  });

  final String raw;
  final String baseUrl;

  /// Device pixels the image needs (also its decode size). Null loads and
  /// decodes the original.
  final int? pixelWidth;
  final BoxFit fit;
  final Widget? error;

  @override
  State<UploadImage> createState() => _UploadImageState();
}

class _UploadImageState extends State<UploadImage> {
  bool _original = false;

  @override
  void didUpdateWidget(covariant UploadImage old) {
    super.didUpdateWidget(old);
    if (old.raw != widget.raw) _original = false;
  }

  @override
  Widget build(BuildContext context) {
    final px = widget.pixelWidth;
    final sized = _original
        ? null
        : uploadUrl(widget.raw, widget.baseUrl, width: px);
    final original = uploadUrl(widget.raw, widget.baseUrl)!;
    final url = sized ?? original;
    return Image.network(
      url,
      key: ValueKey(url),
      fit: widget.fit,
      gaplessPlayback: true,
      cacheWidth: px,
      errorBuilder: (context, _, _) {
        if (!_original && url != original) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _original = true);
          });
          return const SizedBox.expand();
        }
        return widget.error ?? const SizedBox.expand();
      },
    );
  }
}
