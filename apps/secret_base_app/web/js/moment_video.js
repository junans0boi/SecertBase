// Shrinks a picked video in the browser before upload, so clips over the
// 30MB upload limit still go through: 720p H.264 MP4 (~2.5Mbps), AAC audio
// copied as is when it already is AAC.
//
// Uses WebCodecs (hardware encoder on phones) through Mediabunny
// (MPL-2.0, web/js/mediabunny-LICENSE.txt), which is only fetched the first
// time a video actually needs shrinking.
//
// window.secretBaseVideo:
//   supported()                       -> boolean
//   shrink(id, srcUrl, options, onProgress(0..1)) -> Promise<Uint8Array>
//     options: {startMs?, endMs?, maxShortSide=720, maxLongSide=1280,
//               videoBitrate=2500000, audioBitrate=128000}
//     Rejects with Error whose message is 'cancelled', 'unsupported' or
//     'failed: ...' (same codes as the Android channel).
//   cancel(id)
(function () {
  'use strict';

  const MEDIABUNNY = 'js/mediabunny-1.62.1.min.mjs';
  let mediabunny = null;
  const jobs = new Map();

  const load = () => {
    if (!mediabunny) {
      const url = new URL(MEDIABUNNY, document.baseURI).href;
      mediabunny = import(url).catch((error) => {
        mediabunny = null;
        throw error;
      });
    }
    return mediabunny;
  };

  const supported = () =>
    typeof window.VideoEncoder === 'function' &&
    typeof window.VideoDecoder === 'function';

  const even = (n) => Math.max(2, Math.round(n / 2) * 2);

  const fail = (code) => new Error(code);

  async function shrink(id, srcUrl, options, onProgress) {
    if (!supported()) throw fail('unsupported');
    if (jobs.has(id)) throw fail('failed: a conversion with this id is running');
    const job = { cancelled: false, conversion: null };
    jobs.set(id, job);
    try {
      const opts = options || {};
      const maxShort = opts.maxShortSide || 720;
      const maxLong = opts.maxLongSide || 1280;
      const videoBitrate = opts.videoBitrate || 2500000;
      const audioBitrate = opts.audioBitrate || 128000;

      const mb = await load();
      if (job.cancelled) throw fail('cancelled');
      const blob = await (await fetch(srcUrl)).blob();
      const input = new mb.Input({
        formats: mb.ALL_FORMATS,
        source: new mb.BlobSource(blob),
      });
      const video = await input.getPrimaryVideoTrack();
      if (!video) throw fail('unsupported');
      const width = await video.getDisplayWidth();
      const height = await video.getDisplayHeight();
      const scale = Math.min(
        1,
        maxShort / Math.min(width, height),
        maxLong / Math.max(width, height),
      );
      const outWidth = even(width * scale);
      const outHeight = even(height * scale);
      const encodable = await mb.canEncodeVideo('avc', {
        width: outWidth,
        height: outHeight,
        quality: new mb.Quality(videoBitrate),
      });
      if (!encodable) throw fail('unsupported');

      const output = new mb.Output({
        format: new mb.Mp4OutputFormat({ fastStart: 'in-memory' }),
        target: new mb.BufferTarget(),
      });
      const trim = {};
      if (opts.startMs != null) trim.start = opts.startMs / 1000;
      if (opts.endMs != null) trim.end = opts.endMs / 1000;

      const conversion = await mb.Conversion.init({
        input,
        output,
        tracks: 'primary',
        video: {
          width: outWidth,
          height: outHeight,
          fit: 'fill',
          codec: 'avc',
          quality: new mb.Quality({
            bitrate: videoBitrate,
            bitrateMode: opts.bitrateMode || 'variable',
          }),
          forceTranscode: true,
        },
        // AAC is copied untouched; anything else is re-encoded to AAC.
        audio: async (track) => ((await track.getCodec()) === 'aac'
          ? { codec: 'aac' }
          : { codec: 'aac', quality: new mb.Quality(audioBitrate) }),
        trim: Object.keys(trim).length ? trim : undefined,
        showWarnings: false,
      });
      // A clip that silently lost its sound would be worse than an error.
      if (!conversion.isValid || conversion.discardedTracks.length > 0) {
        throw fail('unsupported');
      }
      job.conversion = conversion;
      if (job.cancelled) throw fail('cancelled');
      if (onProgress) {
        conversion.onProgress = (progress) => {
          try { onProgress(Math.min(0.99, progress)); } catch (_) {}
        };
      }
      await conversion.execute();
      if (job.cancelled) throw fail('cancelled');
      if (onProgress) {
        try { onProgress(1); } catch (_) {}
      }
      return new Uint8Array(output.target.buffer);
    } catch (error) {
      if (job.cancelled) throw fail('cancelled');
      const message = error && error.message ? error.message : String(error);
      if (message === 'unsupported' || message === 'cancelled' ||
          message.startsWith('failed')) {
        throw error;
      }
      throw fail('failed: ' + message);
    } finally {
      jobs.delete(id);
    }
  }

  function cancel(id) {
    const job = jobs.get(id);
    if (!job) return;
    job.cancelled = true;
    if (job.conversion) job.conversion.cancel().catch(() => {});
  }

  window.secretBaseVideo = { supported, shrink, cancel };
})();
