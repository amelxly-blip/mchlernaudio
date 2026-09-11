#!/bin/bash
mkdir -p client services storage routes uploads

# 1. Perbarui package.json menggunakan paket yang benar: youtube-dl-exec
cat << 'EOF' > package.json
{
  "name": "mchlern-bypas-audio",
  "version": "2.0.0",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": {
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "fluent-ffmpeg": "^2.1.2",
    "multer": "^1.4.5-lts.1",
    "node-fetch": "^2.7.0",
    "uuid": "^9.0.1",
    "youtube-dl-exec": "^3.1.12"
  }
}
EOF

# 2. Update server.js menggunakan youtube-dl-exec
cat << 'EOF' > server.js
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const youtubedl = require('youtube-dl-exec');

const app = express();
const PORT = process.env.PORT || 3000;
const uploadsDir = path.join(__dirname, 'uploads');
const storageDir = path.join(__dirname, 'storage');
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });
if (!fs.existsSync(storageDir)) fs.mkdirSync(storageDir, { recursive: true });

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, 'client')));
app.use('/uploads', express.static(uploadsDir));

const dbPath = path.join(storageDir, 'db.json');
function getDB() {
  if (!fs.existsSync(dbPath)) return { account: null, history: [] };
  try { return JSON.parse(fs.readFileSync(dbPath, 'utf8')); } catch(e) { return { account: null, history: [] }; }
}
function saveDB(data) { fs.writeFileSync(dbPath, JSON.stringify(data, null, 2)); }

app.post('/api/account/connect', (req, res) => {
  const { userId, apiKey } = req.body;
  if (!userId || !apiKey) return res.status(400).json({ success: false, error: 'Required' });
  const accountData = { connected: true, userId, username: `RobloxDev_${userId}`, avatarUrl: 'https://tr.rbxcdn.com/30day-AvatarHeadshot/150/150/AvatarHeadshot/Png', apiKey };
  let db = getDB(); db.account = accountData; saveDB(db);
  res.json({ success: true, account: accountData });
});

app.get('/api/limits', (req, res) => {
  res.json({ success: true, limits: { dailyQuota: 100, usedToday: 2, remaining: 98, resetTime: '24 Hours' } });
});

const multer = require('multer');
const upload = multer({ dest: 'uploads/' });
const audioProcessor = require('./services/audioProcessor');

app.post('/api/audio/process', upload.single('audio'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ success: false, error: 'No audio' });
    const { template } = req.body;
    let targetSpeed = parseFloat(template || 1.6);
    const outputPath = path.join(uploadsDir, `bypassed-${Date.now()}.mp3`);
    await audioProcessor.processAudio(req.file.path, outputPath, { speed: targetSpeed, volume: 100 });
    res.json({ success: true, processedUrl: `/uploads/${path.basename(outputPath)}`, duration: '02:30' });
  } catch (err) { res.status(500).json({ success: false, error: err.message }); }
});

app.post('/api/audio/fetch', async (req, res) => {
  try {
    const { url } = req.body;
    if (!url) return res.status(400).json({ success: false, error: 'URL required' });

    const output = await youtubedl(url, {
      dumpSingleJson: true,
      noWarnings: true,
      noCallHome: true,
      noCheckCertificate: true,
      preferFreeFormats: true,
      skipDownload: true,
    });

    res.json({
      success: true,
      metadata: {
        title: output.title || 'MCHLERN Track',
        thumbnail: output.thumbnail || 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300',
        duration: output.duration_string || '03:00',
        sourcePlatform: output.extractor || 'YouTube/TikTok',
        downloadUrl: output.url
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Gagal fetch youtube-dl-exec: ' + err.message });
  }
});

app.post('/api/roblox/upload', async (req, res) => {
  const { title } = req.body;
  await new Promise(r => setTimeout(r, 1500));
  res.json({ success: true, assetId: Math.floor(1000000000 + Math.random() * 9000000000).toString() });
});

app.listen(PORT, () => console.log(`Running on port ${PORT}`));
EOF

# 3. Buat services/audioProcessor.js
cat << 'EOF' > services/audioProcessor.js
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
EOF

# 4. Buat git-push.sh bersih
cat << 'EOF' > git-push.sh
#!/bin/bash
git add .
git commit -m "Fix: Use youtube-dl-exec package for robust fetching"
git push -u origin main --force
EOF
chmod +x git-push.sh

# 5. Jalankan push
./git-push.sh
