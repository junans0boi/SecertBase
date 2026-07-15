import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import ffmpegPath from 'ffmpeg-static';
import { normalizeMomentClip } from '../src/moment-clip.js';

const createClip = (file, seconds) => {
  const result = spawnSync(ffmpegPath, [
    '-y', '-f', 'lavfi', '-i', `testsrc=size=320x240:rate=10:duration=${seconds}`,
    '-f', 'lavfi', '-i', `sine=frequency=440:duration=${seconds}`,
    '-c:v', 'libx264', '-preset', 'ultrafast', '-c:a', 'aac', '-shortest', file,
  ]);
  assert.equal(result.status, 0, result.stderr.toString());
};

test('Moment Clip normalizes short input and rejects clips over ten seconds', async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'moment-clip-'));
  try {
    const shortInput = path.join(directory, 'short.mov');
    createClip(shortInput, 1);
    const output = await normalizeMomentClip(shortInput);
    assert.equal(path.extname(output), '.mp4');
    assert.ok((await readFile(output)).length > 0);

    const longInput = path.join(directory, 'long.mp4');
    createClip(longInput, 10.5);
    await assert.rejects(normalizeMomentClip(longInput), /clip_too_long/);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
