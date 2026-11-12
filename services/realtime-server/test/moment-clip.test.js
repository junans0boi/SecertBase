import assert from 'node:assert/strict';
import { access, mkdtemp, readFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import ffmpegPath from 'ffmpeg-static';
import {
  MOMENT_CLIP_MAX_SECONDS,
  chooseClipMode,
  normalizeMomentClip,
  probeClip,
} from '../src/moment-clip.js';

// Keep fixtures cheap: tiny frame rates unless the size itself is under test.
const createClip = (file, {
  seconds,
  size = '320x240',
  rate = 2,
  audio = true,
  pixFmt = 'yuv420p',
}) => {
  const args = [
    '-y', '-f', 'lavfi', '-i', `testsrc=size=${size}:rate=${rate}:duration=${seconds}`,
  ];
  if (audio) args.push('-f', 'lavfi', '-i', `sine=frequency=440:duration=${seconds}`);
  args.push('-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', pixFmt);
  if (audio) args.push('-c:a', 'aac', '-shortest');
  args.push(file);
  const result = spawnSync(ffmpegPath, args);
  assert.equal(result.status, 0, result.stderr.toString());
};

const withDirectory = async (callback) => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'moment-clip-'));
  try {
    await callback(directory);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
};

const exists = (file) => access(file).then(() => true, () => false);

test('Moment Clip limit is 60 seconds plus container slack', () => {
  assert.equal(MOMENT_CLIP_MAX_SECONDS, 60.5);
});

test('chooseClipMode copies only 720p-or-smaller h264/yuv420p with aac or no audio', () => {
  const video = { codec: 'h264', pixFmt: 'yuv420p', width: 1280, height: 720 };
  assert.equal(chooseClipMode({ video, audio: { codec: 'aac' } }), 'copy');
  assert.equal(chooseClipMode({ video, audio: null }), 'copy');
  assert.equal(chooseClipMode({ video: { ...video, width: 720, height: 1280 }, audio: null }), 'copy');
  assert.equal(chooseClipMode({ video, audio: { codec: 'opus' } }), 'transcode');
  assert.equal(chooseClipMode({ video: { ...video, codec: 'hevc' }, audio: null }), 'transcode');
  assert.equal(chooseClipMode({ video: { ...video, pixFmt: 'yuv444p' }, audio: null }), 'transcode');
  assert.equal(chooseClipMode({ video: { ...video, width: 1920, height: 1080 }, audio: null }), 'transcode');
  assert.equal(chooseClipMode({ video: { ...video, width: 1280, height: 960 }, audio: null }), 'transcode');
  assert.equal(chooseClipMode({ video: null, audio: null }), 'transcode');
});

test('Moment Clip accepts a 20 second clip and rejects one over 60 seconds', async () => {
  await withDirectory(async (directory) => {
    const shortInput = path.join(directory, 'short.mov');
    createClip(shortInput, { seconds: 20, size: '64x64', rate: 1 });
    const output = await normalizeMomentClip(shortInput);
    assert.equal(path.extname(output), '.mp4');
    assert.ok((await readFile(output)).length > 0);
    assert.equal(await exists(shortInput), false, 'input is removed on success');
    const normalized = await probeClip(output);
    assert.ok(Math.abs(normalized.duration - 20) < 0.5, `duration ${normalized.duration}`);

    const longInput = path.join(directory, 'long.mp4');
    createClip(longInput, { seconds: 61, size: '64x64', rate: 1 });
    await assert.rejects(normalizeMomentClip(longInput), /clip_too_long/);
    assert.equal(await exists(longInput), true, 'rejected input is left for the caller');
  });
});

test('Moment Clip remuxes an already 720p h264/aac clip without re-encoding', async () => {
  await withDirectory(async (directory) => {
    const input = path.join(directory, 'ready.mp4');
    createClip(input, { seconds: 2, size: '1280x720', rate: 5 });
    const before = await probeClip(input);
    assert.equal(before.mode, 'copy');
    assert.deepEqual(before.video, { codec: 'h264', pixFmt: 'yuv420p', width: 1280, height: 720 });
    assert.deepEqual(before.audio, { codec: 'aac' });

    const output = await normalizeMomentClip(input);
    assert.match(output, /ready-normalized\.mp4$/);
    const after = await probeClip(output);
    assert.deepEqual(after.video, before.video);
    assert.deepEqual(after.audio, { codec: 'aac' });
    // ultrafast input is Constrained Baseline; our veryfast re-encode would be High.
    const header = spawnSync(ffmpegPath, ['-hide_banner', '-i', output]).stderr.toString();
    assert.match(header, /Video: h264 \(Constrained Baseline\)/);
  });
});

test('Moment Clip re-encodes 1080p down to 1280x720 h264/aac', async () => {
  await withDirectory(async (directory) => {
    const input = path.join(directory, 'big.mov');
    createClip(input, { seconds: 1, size: '1920x1080', rate: 2 });
    assert.equal((await probeClip(input)).mode, 'transcode');

    const output = await normalizeMomentClip(input);
    const after = await probeClip(output);
    assert.deepEqual(after.video, { codec: 'h264', pixFmt: 'yuv420p', width: 1280, height: 720 });
    assert.deepEqual(after.audio, { codec: 'aac' });
    assert.equal(after.mode, 'copy');
  });
});

test('Moment Clip keeps portrait clips at 720x1280 instead of squeezing them', async () => {
  await withDirectory(async (directory) => {
    const input = path.join(directory, 'portrait.mov');
    createClip(input, { seconds: 1, size: '1080x1920', rate: 2, audio: false });
    const output = await normalizeMomentClip(input);
    const after = await probeClip(output);
    assert.deepEqual(after.video, { codec: 'h264', pixFmt: 'yuv420p', width: 720, height: 1280 });
  });
});

test('Moment Clip re-encodes non-yuv420p or audio-less input', async () => {
  await withDirectory(async (directory) => {
    const input = path.join(directory, 'rgb.mov');
    createClip(input, { seconds: 1, size: '320x240', audio: false, pixFmt: 'yuv444p' });
    assert.equal((await probeClip(input)).mode, 'transcode');
    const output = await normalizeMomentClip(input);
    const after = await probeClip(output);
    // Small clips are not upscaled.
    assert.deepEqual(after.video, { codec: 'h264', pixFmt: 'yuv420p', width: 320, height: 240 });
    assert.equal(after.audio, null);
  });
});

test('Moment Clip kills ffmpeg past the time budget and cleans up output', async () => {
  await withDirectory(async (directory) => {
    const input = path.join(directory, 'slow.mov');
    createClip(input, { seconds: 4, size: '1920x1080', rate: 30 });
    const startedAt = Date.now();
    await assert.rejects(
      normalizeMomentClip(input, { timeoutMs: 150 }),
      /clip_conversion_failed/,
    );
    assert.ok(Date.now() - startedAt < 5_000, 'ffmpeg was killed promptly');
    assert.equal(await exists(path.join(directory, 'slow-normalized.mp4')), false);
    assert.equal(await exists(input), true, 'input is left for the caller to remove');
  });
});
