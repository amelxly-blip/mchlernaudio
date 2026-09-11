const ffmpeg = require('fluent-ffmpeg');
class AudioProcessor {
  processAudio(inputPath, outputPath, options) {
    return new Promise((resolve, reject) => {
      let command = ffmpeg(inputPath);
      let filters = [];
      if (options.volume) filters.push(`volume=${parseFloat(options.volume) / 100}`);
      if (options.speed) filters.push(`atempo=${options.speed}`);
      if (filters.length > 0) command.audioFilters(filters);
      command.toFormat('mp3').on('end', () => resolve(outputPath)).on('error', err => reject(err)).save(outputPath);
    });
  }
}
module.exports = new AudioProcessor();
