#!/bin/bash

cat << 'EOT' > services/audioProcessor.js
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
  if (fs.existsSync('/data/data/com.termux/files/usr/bin/ffmpeg')) return '/data/data/com.termux/files/usr/bin/ffmpeg';
  
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
EOT

git add .
git commit -m "Fix cross-platform FFmpeg path resolution for Railway and Termux"
git push -u origin main --force
echo "=== SELESAI DIPUSH KE GITHUB ==="
