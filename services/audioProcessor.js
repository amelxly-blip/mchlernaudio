const ffmpeg = require('fluent-ffmpeg');
const fs = require('fs');

function getFfmpegPath() {
  try {
    const ffmpegStatic = require('ffmpeg-static');
    if (ffmpegStatic && fs.existsSync(ffmpegStatic)) return ffmpegStatic;
  } catch (e) {}
  if (fs.existsSync('/usr/bin/ffmpeg')) return '/usr/bin/ffmpeg';
  if (fs.existsSync('/usr/local/bin/ffmpeg')) return '/usr/local/bin/ffmpeg';
  return 'ffmpeg';
}

ffmpeg.setFfmpegPath(getFfmpegPath());

class AudioProcessor {
  processAudio(inputPath, outputPath, options) {
    return new Promise((resolve, reject) => {
      let command = ffmpeg(inputPath);
      let filters = [];

      let speed = parseFloat(options.speed || 1.6);
      let pitch = parseFloat(options.pitch || 1.0);
      let volume = parseFloat(options.volume || 100);

      // Filter volume
      if (volume !== 100) {
        filters.push(`volume=${volume / 100}`);
      }

      // Filter atempo untuk speed (bisa dirangkai jika > 2.0)
      if (speed !== 1.0) {
        let s = speed;
        while (s > 2.0) {
          filters.push('atempo=2.0');
          s /= 2.0;
        }
        if (s !== 1.0) {
          filters.push(`atempo=${s}`);
        }
      }

      // Filter pitch menggunakan aset / rubberband jika ada, atauasetrate
      if (pitch !== 1.0) {
        filters.push(`asetrate=44100*${pitch},aresample=44100`);
      }

      if (filters.length > 0) {
        command.audioFilters(filters);
      }

      command
        .toFormat('mp3')
        .on('end', () => resolve(outputPath))
        .on('error', (err) => reject(new Error("FFmpeg Error: " + err.message)))
        .save(outputPath);
    });
  }
}

module.exports = new AudioProcessor();
