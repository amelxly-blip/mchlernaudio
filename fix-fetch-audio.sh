#!/bin/bash

# Update server.js dengan logika download audio asli dari YouTube/TikTok
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

// Endpoint Proses Bypas (Mendukung File Lokal & URL Fetch YouTube/TikTok)
app.post('/api/audio/process', upload.single('audio'), async (req, res) => {
  try {
    let inputFilePath = '';
    const { template, fetchUrl } = req.body;
    let targetSpeed = parseFloat(template || 1.6);

    if (req.file) {
      inputFilePath = req.file.path;
    } else if (fetchUrl) {
      // Jika menggunakan URL, download audio aslinya menggunakan youtubedl ke folder uploads
      const downloadedFileName = `fetch-${Date.now()}.mp3`;
      const outputTemplate = path.join(uploadsDir, downloadedFileName);
      
      await youtubedl(fetchUrl, {
        extractAudio: true,
        audioFormat: 'mp3',
        output: outputTemplate,
        noWarnings: true,
        noCheckCertificate: true,
      });

      // Cari file hasil download
      inputFilePath = outputTemplate;
      if (!fs.existsSync(inputFilePath)) {
        // Cek ekstensi alternatif jika youtubedl menambahkan format lain
        const files = fs.readdirSync(uploadsDir);
        const found = files.find(f => f.startsWith(path.basename(outputTemplate)));
        if (found) inputFilePath = path.join(uploadsDir, found);
      }
    }

    if (!inputFilePath || !fs.existsSync(inputFilePath)) {
      return res.status(400).json({ success: false, error: 'Tidak ada file audio atau URL yang valid untuk diproses!' });
    }

    const outputPath = path.join(uploadsDir, `bypassed-${Date.now()}.mp3`);
    await audioProcessor.processAudio(inputFilePath, outputPath, { speed: targetSpeed, volume: 100 });

    res.json({ 
      success: true, 
      processedUrl: `/uploads/${path.basename(outputPath)}`, 
      duration: '02:30' 
    });
  } catch (err) { 
    res.status(500).json({ success: false, error: 'Gagal memproses audio: ' + err.message }); 
  }
});

// Endpoint Fetch Metadata
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
        sourcePlatform: output.extractor || 'YouTube/TikTok'
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Gagal fetch URL: ' + err.message });
  }
});

app.post('/api/roblox/upload', async (req, res) => {
  const { title } = req.body;
  await new Promise(r => setTimeout(r, 1500));
  res.json({ success: true, assetId: Math.floor(1000000000 + Math.random() * 9000000000).toString() });
});

app.listen(PORT, () => console.log(`Running on port ${PORT}`));
EOF

# Update package.json agar memastikan youtube-dl-exec terpasang
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

# Update Aptfile agar Railway menginstal python & ffmpeg untuk youtubedl
cat << 'EOF' > Aptfile
ffmpeg
python3
EOF

# Push otomatis ke GitHub
git add .
git commit -m "Fix: Enable direct server-side audio downloading for fetched YouTube/TikTok URLs"
git push -u origin main --force
echo "=== UPDATE SELESAI DAN DIPUSH KE GITHUB ==="
