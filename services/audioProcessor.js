const ffmpeg = require('fluent-ffmpeg');
const fs = require('fs');

function getFfmpegPath() {
  try {
    const ffmpegStatic = require('ffmpeg-static');
    if (ffmpegStatic && fs.existsSync(ffmpegStatic)) return ffmpegStatic;
  } catch (e) {}
  if (fs.existsSync('/usr/bin/ffmpeg')) return '/usr/bin/ffmpeg';
  if (fs.existsSync('/usr/local/bin/ffmpeg')) return '/usr/local/bin/ffmpeg';
  if (fs.existsSync('/app/.apt/usr/bin/ffmpeg')) return '/app/.apt/usr/bin/ffmpeg';
  return 'ffmpeg';
}

ffmpeg.setFfmpegPath(getFfmpegPath());

class AudioProcessor {
  processAudio(inputPath, outputPath, options) {
    return new Promise((resolve, reject) => {
      let command = ffmpeg(inputPath);
      let filters = [];

      let speed = Number(options.speed);
      let pitch = Number(options.pitch);
      let volume = Number(options.volume);

      const safeSpeed = Number.isFinite(speed) ? speed : 1.6;
      const safePitch = Number.isFinite(pitch) ? pitch : 0.9;
      const safeVolume = Number.isFinite(volume) ? volume : 100;

      if (safeVolume !== 100) {
        filters.push(`volume=${safeVolume / 100}`);
      }

      if (safeSpeed !== 1.0) {
        let s = safeSpeed;
        while (s > 2.0) {
          filters.push('atempo=2.0');
          s /= 2.0;
        }
        if (s !== 1.0) {
          filters.push(`atempo=${s}`);
        }
      }

      if (safePitch !== 1.0) {
        filters.push(`asetrate=44100*${safePitch},aresample=44100`);
      }

      if (filters.length > 0) {
        command.audioFilters(filters);
      }

      command
        .toFormat('mp3')
        .audioCodec('libmp3lame')
        .on('end', () => {
          if (!fs.existsSync(outputPath)) {
            return reject(new Error('Output audio gagal dibuat'));
          }
          const stat = fs.statSync(outputPath);
          if (stat.size === 0) {
            return reject(new Error('Output audio kosong'));
          }
          resolve(outputPath);
        })
        .on('error', (err) => reject(new Error("FFmpeg Processing Error: " + err.message)))
        .save(outputPath);
    });
  }
}

module.exports = new AudioProcessor();
