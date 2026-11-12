import { spawn } from 'node:child_process';
import { rm } from 'node:fs/promises';
import path from 'node:path';
import ffmpegPath from 'ffmpeg-static';

// The app lets people trim clips to 60s; allow a little container slack.
export const MOMENT_CLIP_MAX_SECONDS = 60.5;
// Hard ceiling for all ffmpeg work on one clip, so a stuck encode can't hold
// the upload request (the client gives up at 180s).
export const MOMENT_CLIP_TIMEOUT_MS = 120_000;

const MAX_LONG_SIDE = 1280;
const MAX_SHORT_SIDE = 720;

const run = (args, timeoutMs = MOMENT_CLIP_TIMEOUT_MS) => new Promise((resolve, reject) => {
  const child = spawn(ffmpegPath, args);
  let stderr = '';
  let timedOut = false;
  const timer = setTimeout(() => {
    timedOut = true;
    child.kill('SIGKILL');
  }, Math.max(1, timeoutMs));
  child.stderr.on('data', (chunk) => { stderr += chunk; });
  child.once('error', (error) => {
    clearTimeout(timer);
    reject(error);
  });
  child.once('close', (code) => {
    clearTimeout(timer);
    resolve({ code: timedOut ? null : code, stderr, timedOut });
  });
});

const parseDuration = (stderr) => {
  const match = stderr.match(/Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)/);
  if (!match) return null;
  return Number(match[1]) * 3600 + Number(match[2]) * 60 + Number(match[3]);
};

// e.g. "Stream #0:0[0x1](und): Video: h264 (High) (avc1 / 0x31637661), yuv420p(tv, bt709, progressive), 1280x720 [SAR 1:1 DAR 16:9], ..."
const parseVideoStream = (stderr) => {
  const line = stderr.split('\n').find((entry) => /Stream #\d+:\d+.*: Video: /.test(entry));
  if (!line) return null;
  const match = line.match(/: Video: (\w+)[^,]*, (\w+)(?:\([^)]*\))?, (\d+)x(\d+)/);
  if (!match) return { codec: line.match(/: Video: (\w+)/)?.[1] ?? null, pixFmt: null, width: null, height: null };
  return {
    codec: match[1],
    pixFmt: match[2],
    width: Number(match[3]),
    height: Number(match[4]),
  };
};

const parseAudioStream = (stderr) => {
  const match = stderr.match(/Stream #\d+:\d+.*: Audio: (\w+)/);
  return match ? { codec: match[1] } : null;
};

export const chooseClipMode = ({ video, audio }) => {
  if (!video || video.codec !== 'h264' || video.pixFmt !== 'yuv420p') return 'transcode';
  if (!video.width || !video.height) return 'transcode';
  const longSide = Math.max(video.width, video.height);
  const shortSide = Math.min(video.width, video.height);
  if (longSide > MAX_LONG_SIDE || shortSide > MAX_SHORT_SIDE) return 'transcode';
  if (audio && audio.codec !== 'aac') return 'transcode';
  return 'copy';
};

export async function probeClip(inputPath, { timeoutMs = MOMENT_CLIP_TIMEOUT_MS } = {}) {
  const probe = await run(['-hide_banner', '-i', inputPath], timeoutMs);
  const duration = parseDuration(probe.stderr);
  const video = parseVideoStream(probe.stderr);
  const audio = parseAudioStream(probe.stderr);
  return {
    duration,
    timedOut: probe.timedOut,
    video,
    audio,
    mode: chooseClipMode({ video, audio }),
  };
}

// Fit inside 1280x720 (720x1280 for portrait) without upscaling small clips.
const SCALE_FILTER = [
  `scale=w='if(gte(iw,ih),min(${MAX_LONG_SIDE},iw),min(${MAX_SHORT_SIDE},iw))'`,
  `h='if(gte(iw,ih),min(${MAX_SHORT_SIDE},ih),min(${MAX_LONG_SIDE},ih))'`,
  'force_original_aspect_ratio=decrease',
  'force_divisible_by=2',
].join(':');

const copyArgs = (inputPath, outputPath) => [
  '-y', '-i', inputPath,
  '-map', '0:v:0', '-map', '0:a:0?',
  '-c', 'copy', '-movflags', '+faststart',
  outputPath,
];

const transcodeArgs = (inputPath, outputPath) => [
  '-y', '-i', inputPath,
  '-vf', SCALE_FILTER,
  '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23',
  '-maxrate', '3M', '-bufsize', '6M',
  '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
  '-c:a', 'aac', '-b:a', '128k',
  outputPath,
];

export async function normalizeMomentClip(
  inputPath,
  { timeoutMs = MOMENT_CLIP_TIMEOUT_MS } = {},
) {
  const deadline = Date.now() + timeoutMs;
  const remaining = () => deadline - Date.now();

  const probe = await probeClip(inputPath, { timeoutMs });
  if (probe.timedOut) throw new Error('clip_conversion_failed');
  if (probe.duration === null) throw new Error('clip_duration_unreadable');
  if (probe.duration > MOMENT_CLIP_MAX_SECONDS) throw new Error('clip_too_long');

  const outputPath = path.join(
    path.dirname(inputPath),
    `${path.parse(inputPath).name}-normalized.mp4`,
  );
  try {
    let converted = null;
    if (probe.mode === 'copy') {
      converted = await run(copyArgs(inputPath, outputPath), remaining());
      // A remux can still fail on odd containers; fall back to a re-encode
      // with whatever time is left.
      if (converted.code !== 0 && !converted.timedOut && remaining() > 0) {
        converted = null;
      }
    }
    if (!converted) {
      if (remaining() <= 0) throw new Error('clip_conversion_failed');
      converted = await run(transcodeArgs(inputPath, outputPath), remaining());
    }
    if (converted.timedOut || converted.code !== 0) throw new Error('clip_conversion_failed');
    await rm(inputPath, { force: true });
    return outputPath;
  } catch (error) {
    await rm(outputPath, { force: true });
    throw error;
  }
}
