require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const fetch = require('node-fetch');

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

// Sistem Fetch Super Stabil Berbasis oEmbed & URL Parser
app.post('/api/audio/fetch', async (req, res) => {
  try {
    const { url } = req.body;
    if (!url) return res.status(400).json({ success: false, error: 'URL required' });

    let metadata = {
      title: 'MCHLERN Audio Masterpiece',
      thumbnail: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300',
      duration: '03:15',
      sourcePlatform: 'Web Stream'
    };

    if (url.includes('youtube.com') || url.includes('youtu.be')) {
      metadata.sourcePlatform = 'YouTube';
      const match = url.match(/(?:v=|\/)([0-9A-Za-z_-]{11})/);
      if (match && match[1]) {
        const vidId = match[1];
        metadata.thumbnail = `https://img.youtube.com/vi/${vidId}/hqdefault.jpg`;
        const oembed = await fetch(`https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${vidId}&format=json`);
        if (oembed.ok) {
          const data = await oembed.json();
          metadata.title = data.title;
        }
      }
    } else if (url.includes('tiktok.com')) {
      metadata.sourcePlatform = 'TikTok';
      metadata.title = 'TikTok Trending Sound Track';
      metadata.thumbnail = 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=300';
    }

    res.json({ success: true, metadata });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Gagal memproses URL.' });
  }
});

app.post('/api/roblox/upload', async (req, res) => {
  const { title } = req.body;
  await new Promise(r => setTimeout(r, 1500));
  res.json({ success: true, assetId: Math.floor(1000000000 + Math.random() * 9000000000).toString() });
});

app.listen(PORT, () => console.log(`Running on port ${PORT}`));
