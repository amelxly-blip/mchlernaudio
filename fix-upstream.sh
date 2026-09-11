#!/bin/bash

# Perbarui server.js dengan penanganan payload besar & penangkapan error JSON yang aman
cat << 'EOF' > server.js
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;
const uploadsDir = path.join(__dirname, 'uploads');
const storageDir = path.join(__dirname, 'storage');
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });
if (!fs.existsSync(storageDir)) fs.mkdirSync(storageDir, { recursive: true });

app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
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
const upload = multer({ 
  dest: 'uploads/',
  limits: { fileSize: 50 * 1024 * 1024 } // Batas file 50MB
});
const audioProcessor = require('./services/audioProcessor');

let pendingJobs = [];
const activeJobs = new Map();

app.post('/api/audio/process', upload.single('audio'), async (req, res) => {
  try {
    let inputFilePath = '';
    const { template } = req.body;
    let targetSpeed = parseFloat(template || 1.6);
    if (req.file) inputFilePath = req.file.path;
    if (!inputFilePath || !fs.existsSync(inputFilePath)) {
      return res.status(400).json({ success: false, error: 'Pilih file audio lokal terlebih dahulu!' });
    }
    const outputPath = path.join(uploadsDir, `bypassed-${Date.now()}.mp3`);
    await audioProcessor.processAudio(inputFilePath, outputPath, { speed: targetSpeed, volume: 100 });
    res.json({ success: true, processedUrl: `/uploads/${path.basename(outputPath)}`, duration: '02:30' });
  } catch (err) { res.status(500).json({ success: false, error: err.message }); }
});

app.post('/api/audio/fetch', async (req, res) => {
  const { url } = req.body;
  if (!url) return res.status(400).json({ success: false, error: 'URL required' });

  const jobId = Date.now().toString();
  const jobToken = Math.random().toString(36).substring(2);
  
  pendingJobs.push({ id: jobId, token: jobToken, url, status: 'pending' });

  const timeout = 300000; // 5 menit
  const start = Date.now();

  const checkInterval = setInterval(() => {
    if (activeJobs.has(jobId)) {
      clearInterval(checkInterval);
      const result = activeJobs.get(jobId);
      activeJobs.delete(jobId);
      if (result.error) return res.status(500).json({ success: false, error: result.error });
      return res.json({ success: true, metadata: result.metadata });
    }
    if (Date.now() - start > timeout) {
      clearInterval(checkInterval);
      pendingJobs = pendingJobs.filter(j => j.id !== jobId);
      return res.status(504).json({ success: false, error: 'Worker timeout: Proses download melebihi batas waktu.' });
    }
  }, 1000);
});

app.post('/api/fetch-worker/claim', (req, res) => {
  if (pendingJobs.length === 0) return res.json({ job: null });
  res.json({ job: pendingJobs.shift() });
});

const uploadWorker = multer({ 
  dest: 'uploads/',
  limits: { fileSize: 50 * 1024 * 1024 }
});

app.post('/api/fetch-worker/complete', uploadWorker.single('file'), (req, res) => {
  try {
    const { job_id, title, thumbnail, error } = req.body;
    if (error) {
      if (job_id) activeJobs.set(job_id, { error });
      return res.json({ success: true });
    }

    let audioUrl = req.file ? `/uploads/${path.basename(req.file.path)}` : '';
    if (job_id) {
      activeJobs.set(job_id, {
        metadata: {
          title: title || 'MCHLERN Track',
          thumbnail: thumbnail || 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300',
          duration: '03:00',
          sourcePlatform: 'YouTube/TikTok',
          downloadUrl: audioUrl
        }
      });
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/roblox/upload', async (req, res) => {
  const { title } = req.body;
  await new Promise(r => setTimeout(r, 1500));
  res.json({ success: true, assetId: Math.floor(1000000000 + Math.random() * 9000000000).toString() });
});

app.listen(PORT, () => console.log(`Running on port ${PORT}`));
EOF

git add .
git commit -m "Fix payload size limit and robust error handling for worker complete route"
git push -u origin main --force
echo "=== UPDATE UPSTREAM SELESAI DIPUSH ==="
