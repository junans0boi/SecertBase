import { spawn } from 'node:child_process';
import { rm } from 'node:fs/promises';
import path from 'node:path';
import ffmpegPath from 'ffmpeg-static';

const run = (args) => new Promise((resolve, reject) => {
  const child = spawn(ffmpegPath, args);
  let stderr = '';
  child.stderr.on('data', (chunk) => { stderr += chunk; });
  child.once('error', reject);
  child.once('close', (code) => resolve({ code, stderr }));
});

export async function normalizeMomentClip(inputPath) {
  const probe = await run(['-hide_banner', '-i', inputPath]);
  const durationMatch = probe.stderr.match(/Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)/);
  if (!durationMatch) throw new Error('clip_duration_unreadable');
  const duration = Number(durationMatch[1]) * 3600
    + Number(durationMatch[2]) * 60
    + Number(durationMatch[3]);
  if (duration > 10.05) throw new Error('clip_too_long');

  const outputPath = path.join(
    path.dirname(inputPath),
    `${path.parse(inputPath).name}-normalized.mp4`,
  );
  try {
    const converted = await run([
      '-y', '-i', inputPath,
      '-vf', 'scale=w=1280:h=720:force_original_aspect_ratio=decrease:force_divisible_by=2',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
      '-c:a', 'aac', '-b:a', '128k',
      outputPath,
    ]);
    if (converted.code !== 0) throw new Error('clip_conversion_failed');
    await rm(inputPath, { force: true });
    return outputPath;
  } catch (error) {
    await rm(outputPath, { force: true });
    throw error;
  }
}
