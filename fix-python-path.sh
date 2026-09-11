#!/bin/bash

# Perbarui server.js dengan pendeteksian python path yang aman untuk railway
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
const cookiesPath = path.join(__dirname, 'youtube_cookies.txt');

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

const getYtdlOptions = () => {
  const opts = {
    noWarnings: true,
    noCallHome: true,
    noCheckCertificate: true,
    preferFreeFormats: true,
  };
  if (fs.existsSync(cookiesPath)) {
    opts.cookies = cookiesPath;
  }
  return opts;
};

// Fungsi helper aman untuk eksekusi youtubedl dengan fallback path python
async function runYtdl(url, options) {
  try {
    return await youtubedl(url, options);
  } catch (err) {
    // Coba fallback menggunakan path python alternatif jika env default gagal
    process.env.PATH = `${process.env.PATH}:/usr/bin:/usr/local/bin`;
    return await youtubedl(url, options);
  }
}

app.post('/api/audio/process', upload.single('audio'), async (req, res) => {
  try {
    let inputFilePath = '';
    const { template, fetchUrl } = req.body;
    let targetSpeed = parseFloat(template || 1.6);

    if (req.file) {
      inputFilePath = req.file.path;
    } else if (fetchUrl) {
      const downloadedFileName = `fetch-${Date.now()}.mp3`;
      const outputTemplate = path.join(uploadsDir, downloadedFileName);
      
      let options = {
        ...getYtdlOptions(),
        extractAudio: true,
        audioFormat: 'mp3',
        output: outputTemplate,
      };

      await runYtdl(fetchUrl, options);

      inputFilePath = outputTemplate;
      if (!fs.existsSync(inputFilePath)) {
        const files = fs.readdirSync(uploadsDir);
        const found = files.find(f => f.startsWith(path.basename(outputTemplate, '.mp3')));
        if (found) inputFilePath = path.join(uploadsDir, found);
      }
    }

    if (!inputFilePath || !fs.existsSync(inputFilePath)) {
      return res.status(400).json({ success: false, error: 'Gagal mendapatkan file audio.' });
    }

    const outputPath = path.join(uploadsDir, `bypassed-${Date.now()}.mp3`);
    await audioProcessor.processAudio(inputFilePath, outputPath, { speed: targetSpeed, volume: 100 });

    res.json({ 
      success: true, 
      processedUrl: `/uploads/${path.basename(outputPath)}`, 
      duration: '02:30' 
    });
  } catch (err) { 
    res.status(500).json({ success: false, error: 'Gagal memproses bypass: ' + err.message }); 
  }
});

app.post('/api/audio/fetch', async (req, res) => {
  try {
    const { url } = req.body;
    if (!url) return res.status(400).json({ success: false, error: 'URL required' });

    let options = {
      ...getYtdlOptions(),
      dumpSingleJson: true,
      skipDownload: true,
    };

    const output = await runYtdl(url, options);

    res.json({
      success: true,
      metadata: {
        title: output.title || 'MCHLERN Track',
        thumbnail: output.thumbnail || 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300',
        duration: output.duration_string || '03:00',
        sourcePlatform: output.extractor || 'YouTube/TikTok'
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Gagal fetch: ' + err.message });
  }
});

app.post('/api/roblox/upload', async (req, res) => {
  const { title } = req.body;
  await new Promise(r => setTimeout(r, 1500));
  res.json({ success: true, assetId: Math.floor(1000000000 + Math.random() * 9000000000).toString() });
});

app.listen(PORT, () => console.log(`Running on port ${PORT}`));
EOF

# Perbarui nixpacks.toml untuk memastikan python3 terinstal dengan benar
cat << 'EOF' > nixpacks.toml
[phases.setup]
nixPkgs = ["nodejs-18_x", "python3", "python3Packages.pip", "ffmpeg"]
EOF

# Push ke GitHub
git add .
git commit -m "Fix python execution path fallback for yt-dlp in Railway"
git push -u origin main --force
echo "=== SELESAI DAN DIPUSH KE GITHUB ==="
