// Resized copies of uploaded photos for list/thumbnail views.
//
// GET /uploads/w/:width/:file → a WebP no wider than :width, made with sharp
// on the first request and kept under <UPLOADS_ROOT>/.thumbs/w<width>/.
// Upload names are unique (time + random), so originals and thumbnails are
// cached by browsers for a year ("immutable").
import { mkdir, readFile, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';

export const THUMB_WIDTHS = Object.freeze([160, 480, 1080]);
const IMAGE_EXT = /\.(jpe?g|png|webp|gif|heic|heif)$/i;
const SAFE_NAME = /^[A-Za-z0-9._-]+$/;
export const IMMUTABLE = 'public, max-age=31536000, immutable';

let sharpLoader;
async function loadSharp() {
  sharpLoader ??= import('sharp').then((m) => m.default ?? m);
  return sharpLoader;
}

const inflight = new Map();

/** Returns the cached thumbnail path, creating it if needed. */
export async function ensureThumb(uploadsRoot, width, file, { sharp } = {}) {
  const root = path.resolve(uploadsRoot);
  const src = path.join(root, file);
  const dir = path.join(root, '.thumbs', `w${width}`);
  const out = path.join(dir, `${file}.webp`);
  try {
    await stat(out);
    return out;
  } catch {
    // not made yet
  }
  const key = out;
  if (!inflight.has(key)) {
    inflight.set(
      key,
      (async () => {
        const lib = sharp ?? (await loadSharp());
        const input = await readFile(src);
        const data = await lib(input, { failOn: 'none' })
          .rotate()
          .resize({ width, withoutEnlargement: true })
          .webp({ quality: 78 })
          .toBuffer();
        await mkdir(dir, { recursive: true });
        await writeFile(out, data);
        return out;
      })().finally(() => inflight.delete(key)),
    );
  }
  return inflight.get(key);
}

/**
 * Express handler for /uploads/w/:width/:file. Anything it can't resize
 * (unknown width, odd name, video, broken image) redirects to the original,
 * so clients can always use the thumbnail URL.
 */
export function thumbHandler(uploadsRoot, options = {}) {
  return async (req, res) => {
    const width = Number(req.params.width);
    const file = String(req.params.file ?? '');
    const original = `/uploads/${encodeURIComponent(file)}`;
    if (!THUMB_WIDTHS.includes(width) || !SAFE_NAME.test(file) || file.startsWith('.')) {
      return res.status(404).end();
    }
    if (!IMAGE_EXT.test(file)) return res.redirect(302, original);
    try {
      await stat(path.join(uploadsRoot, file));
    } catch {
      return res.status(404).end();
    }
    try {
      const out = await ensureThumb(uploadsRoot, width, file, options);
      res.setHeader('Cache-Control', IMMUTABLE);
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.type('image/webp');
      return res.sendFile(out);
    } catch (err) {
      console.error('[uploads] thumbnail failed', file, width, err?.message ?? err);
      return res.redirect(302, original);
    }
  };
}
