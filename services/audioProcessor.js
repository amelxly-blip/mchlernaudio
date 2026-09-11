const ffmpeg = require('fluent-ffmpeg');
const fs = require('fs');

function getFfmpegPath() {
  try {
    const ffmpegStatic = require('ffmpeg-static');
    if (ffmpegStatic && fs.existsSync(ffmpegStatic)) {
      return ffmpegStatic;
    }
  } catch (e) {}

  if (fs.existsSync('/usr/bin/ffmpeg')) return '/usr/bin/ffmpeg';
  if (fs.existsSync('/usr/local/bin/ffmpeg')) return '/usr/local/bin/ffmpeg';
  
  return 'ffmpeg';
}

const resolvedPath = getFfmpegPath();
ffmpeg.setFfmpegPath(resolvedPath);
console.log("FFmpeg detected ✓ Path:", resolvedPath);

class AudioProcessor {
  processAudio(inputPath, outputPath, options) {
    return new Promise((resolve, reject) => {
      let command = ffmpeg(inputPath);
      let filters = [];
      
      if (options.volume) filters.push(`volume=${parseFloat(options.volume) / 100}`);
      if (options.speed) filters.push(`atempo=${options.speed}`);
      
      if (filters.length > 0) {
        command.audioFilters(filters);
      }

      command
        .toFormat('mp3')
        .on('end', () => resolve(outputPath))
        .on('error', (err) => reject(new Error("Gagal memproses audio FFmpeg: " + err.message)))
        .save(outputPath);
    });
  }
}

module.exports = new AudioProcessor();
