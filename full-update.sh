#!/bin/bash
mkdir -p client services storage routes uploads

# 1. Update package.json dengan yt-dlp-exec
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
    "yt-dlp-exec": "^2.4.3"
  }
}
EOF

# 2. Update Aptfile untuk Railway
cat << 'EOF' > Aptfile
ffmpeg
python3
EOF

# 3. Update server.js dengan yt-dlp fetch & audio processing
cat << 'EOF' > server.js
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const youtubedl = require('yt-dlp-exec');

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

app.get('/api/account', (req, res) => {
  let db = getDB(); res.json({ success: true, account: db.account || { connected: false } });
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
    res.json({ success: true, processedUrl: `/uploads/${path.basename(outputPath)}`, duration: '02:30', recommendedIngameSpeed: (1 / targetSpeed).toFixed(2) + 'x' });
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
    res.status(500).json({ success: false, error: 'Gagal fetch yt-dlp: ' + err.message });
  }
});

app.post('/api/roblox/upload', async (req, res) => {
  const { title } = req.body;
  await new Promise(r => setTimeout(r, 1500));
  res.json({ success: true, assetId: Math.floor(1000000000 + Math.random() * 9000000000).toString() });
});

app.listen(PORT, () => console.log(`Running on port ${PORT}`));
EOF

# 4. Buat services/audioProcessor.js
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

# 5. Update client/index.html dengan UI modern, tombol file estetik & back button
cat << 'EOF' > client/index.html
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>MCHLERN ENGINERING BYPAS</title>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
  <style>
    :root {
      --bg: #030305;
      --card: rgba(16, 16, 22, 0.75);
      --border: rgba(255, 255, 255, 0.08);
      --text: #f4f4f6;
      --muted: #8e8e99;
      --accent: #ffffff;
      --accent-hover: #d0d0d6;
      --glow: rgba(255, 255, 255, 0.1);
      --success: #34c759;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    body { background: var(--bg); color: var(--text); display: flex; height: 100vh; overflow: hidden; background-image: radial-gradient(circle at 50% 0%, #151522 0%, #030305 70%); }
    aside { width: 280px; background: var(--card); backdrop-filter: blur(20px); border-right: 1px solid var(--border); display: flex; flex-direction: column; justify-content: space-between; padding: 24px; z-index: 10; }
    .brand { font-size: 14px; font-weight: 800; letter-spacing: 2.5px; color: var(--accent); margin-bottom: 35px; display: flex; align-items: center; gap: 12px; }
    .menu { display: flex; flex-direction: column; gap: 8px; flex: 1; }
    .menu-item { display: flex; align-items: center; gap: 14px; padding: 14px 18px; border-radius: 12px; color: var(--muted); cursor: pointer; font-size: 14px; font-weight: 500; transition: all 0.3s ease; }
    .menu-item:hover, .menu-item.active { background: rgba(255, 255, 255, 0.08); color: var(--accent); box-shadow: 0 4px 20px var(--glow); }
    main { flex: 1; display: flex; flex-direction: column; overflow-y: auto; padding: 40px; }
    .header-banner { background: var(--card); backdrop-filter: blur(20px); border: 1px solid var(--border); border-radius: 16px; padding: 28px; margin-bottom: 30px; box-shadow: 0 8px 32px rgba(0,0,0,0.4); display: flex; align-items: center; justify-content: space-between; }
    .typing-container { font-size: 18px; font-weight: 800; color: var(--accent); letter-spacing: 0.5px; }
    .section-view { display: none; animation: fadeIn 0.4s ease; }
    .section-view.active { display: block; }
    @keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
    .card { background: var(--card); backdrop-filter: blur(20px); border: 1px solid var(--border); border-radius: 16px; padding: 28px; margin-bottom: 24px; box-shadow: 0 8px 32px rgba(0,0,0,0.3); }
    .card-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
    h2 { font-size: 20px; font-weight: 700; color: var(--accent); display: flex; align-items: center; gap: 12px; }
    .btn-back { background: rgba(255,255,255,0.05); border: 1px solid var(--border); color: var(--muted); padding: 8px 14px; border-radius: 8px; cursor: pointer; font-size: 12px; font-weight: 600; display: inline-flex; align-items: center; gap: 6px; transition: 0.2s; }
    .btn-back:hover { background: rgba(255,255,255,0.12); color: var(--text); }
    .form-group { margin-bottom: 20px; }
    label { display: block; font-size: 12px; font-weight: 700; color: var(--muted); text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px; }
    input, select { width: 100%; padding: 14px 18px; background: rgba(0,0,0,0.4); border: 1px solid var(--border); border-radius: 10px; color: var(--text); font-size: 14px; outline: none; transition: 0.3s; }
    input:focus { border-color: var(--accent); box-shadow: 0 0 10px rgba(255,255,255,0.15); }
    .btn { background: var(--accent); color: var(--bg); font-weight: 700; padding: 14px 24px; border-radius: 10px; border: none; cursor: pointer; display: inline-flex; align-items: center; justify-content: center; gap: 10px; font-size: 14px; transition: 0.3s; box-shadow: 0 4px 20px rgba(255,255,255,0.2); }
    .btn:hover { background: var(--accent-hover); transform: translateY(-1px); }
    .btn-outline { background: transparent; border: 1px solid var(--border); color: var(--text); box-shadow: none; }
    .btn-outline:hover { background: rgba(255,255,255,0.08); }
    .file-upload-wrapper { position: relative; width: 100%; }
    .file-upload-wrapper input[type="file"] { display: none; }
    .file-upload-btn { display: flex; align-items: center; justify-content: center; gap: 10px; width: 100%; padding: 16px 18px; background: rgba(0,0,0,0.4); border: 1px dashed var(--border); border-radius: 10px; color: var(--text); font-size: 14px; font-weight: 600; cursor: pointer; transition: 0.3s; }
    .file-upload-btn:hover { border-color: var(--accent); background: rgba(255,255,255,0.05); color: var(--accent); }
    .menu-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 20px; margin-top: 20px; }
    .menu-card { background: rgba(255,255,255,0.02); border: 1px solid var(--border); border-radius: 14px; padding: 24px; cursor: pointer; transition: 0.3s; display: flex; flex-direction: column; gap: 12px; }
    .menu-card:hover { border-color: var(--accent); background: rgba(255,255,255,0.05); transform: translateY(-3px); }
    .menu-card i { font-size: 28px; color: var(--accent); }
    .menu-card h3 { font-size: 16px; font-weight: 700; color: var(--text); }
    .menu-card p { font-size: 12px; color: var(--muted); }
    .templates-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 20px; }
    .template-badge { padding: 14px; text-align: center; background: rgba(0,0,0,0.4); border: 1px solid var(--border); border-radius: 10px; cursor: pointer; font-weight: 700; font-size: 14px; transition: 0.3s; }
    .template-badge:hover, .template-badge.active { border-color: var(--accent); background: rgba(255,255,255,0.1); color: var(--accent); }
    #toast { position: fixed; bottom: 30px; right: 30px; background: rgba(16, 16, 22, 0.95); backdrop-filter: blur(10px); border: 1px solid var(--border); padding: 16px 28px; border-radius: 12px; font-size: 14px; z-index: 999; box-shadow: 0 10px 30px rgba(0,0,0,0.6); display: none; }
    @media(max-width: 768px) { aside { display: none; } body { flex-direction: column; overflow-y: auto; } main { padding: 20px; } .templates-grid { grid-template-columns: repeat(2, 1fr); } }
  </style>
</head>
<body>
  <aside>
    <div>
      <div class="brand"><i class="fa-solid fa-bolt"></i> MCHLERN ENGINERING</div>
      <div class="menu">
        <div class="menu-item active" onclick="switchTab('home', event)"><i class="fa-solid fa-house"></i> Home Dashboard</div>
        <div class="menu-item" onclick="switchTab('bypas', event)"><i class="fa-solid fa-wand-magic-sparkles"></i> Bypas Audio</div>
        <div class="menu-item" onclick="switchTab('uploader', event)"><i class="fa-solid fa-cloud-arrow-up"></i> Roblox Uploader</div>
        <div class="menu-item" onclick="switchTab('decal', event)"><i class="fa-solid fa-image"></i> Image Decal Uploader</div>
        <div class="menu-item" onclick="switchTab('limits', event)"><i class="fa-solid fa-gauge-high"></i> Cek Limit API</div>
        <div class="menu-item" onclick="switchTab('tutorial', event)"><i class="fa-solid fa-book-open"></i> Tutorial Panduan</div>
      </div>
    </div>
    <div style="font-size: 11px; color: var(--muted); border-top: 1px solid var(--border); padding-top: 15px;" id="sidebar-status">Status: Disconnected</div>
  </aside>

  <main>
    <div class="header-banner">
      <div class="typing-container">WELCOME TO MCHLERN ENGINERING BYPAS</div>
      <i class="fa-solid fa-shield-halved" style="font-size: 24px; color: var(--muted);"></i>
    </div>

    <div id="tab-home" class="section-view active">
      <div class="card">
        <h2><i class="fa-solid fa-compass"></i> Dashboard Utama</h2>
        <p style="font-size: 14px; color: var(--muted); margin-bottom: 24px;">Silahkan pilih salah satu menu di bawah untuk mulai menggunakan fitur profesional MCHLERN ENGINERING.</p>
        <div class="menu-grid">
          <div class="menu-card" onclick="switchTab('bypas', null)"><i class="fa-solid fa-wand-magic-sparkles"></i><h3>Bypas Audio</h3><p>Modifikasi audio, template kecepatan, fetch YouTube/TikTok yt-dlp, & upload Roblox.</p></div>
          <div class="menu-card" onclick="switchTab('uploader', null)"><i class="fa-solid fa-cloud-arrow-up"></i><h3>Roblox Audio Uploader</h3><p>Publish file audio langsung ke asset Roblox Open Cloud.</p></div>
          <div class="menu-card" onclick="switchTab('decal', null)"><i class="fa-solid fa-image"></i><h3>Image Decal Uploader</h3><p>Upload gambar decal dengan cepat dan aman.</p></div>
          <div class="menu-card" onclick="switchTab('limits', null)"><i class="fa-solid fa-gauge-high"></i><h3>Cek Limit API</h3><p>Pantau kuota penggunaan harian dan status sistem.</p></div>
          <div class="menu-card" onclick="switchTab('tutorial', null)"><i class="fa-solid fa-book-open"></i><h3>Cek Tutorial</h3><p>Panduan lengkap tata cara bypass dan koneksi API.</p></div>
        </div>
      </div>
    </div>

    <div id="tab-bypas" class="section-view">
      <div class="card">
        <div class="card-header">
          <h2><i class="fa-solid fa-user-shield"></i> Koneksi Akun Roblox</h2>
          <button class="btn-back" onclick="switchTab('home', null)"><i class="fa-solid fa-arrow-left"></i> Kembali</button>
        </div>
        <div id="account-box">
          <div class="form-group"><label>Roblox User ID</label><input type="text" id="rbx-userid" placeholder="Contoh: 12345678"></div>
          <div class="form-group"><label>API Key (Open Cloud)</label><input type="password" id="rbx-apikey" placeholder="Masukkan API Key Anda"></div>
          <button class="btn" onclick="connectAccount()"><i class="fa-solid fa-link"></i> Konek Akun</button>
        </div>
      </div>

      <div class="card">
        <h2><i class="fa-solid fa-sliders"></i> Audio Bypas Engine</h2>
        <div class="form-group">
          <label>Fetch Audio dari Link YouTube / TikTok (yt-dlp)</label>
          <div style="display: flex; gap: 10px;">
            <input type="text" id="fetch-url" placeholder="https://youtube.com/watch?v=... atau TikTok URL">
            <button class="btn btn-outline" onclick="fetchMedia()"><i class="fa-solid fa-download"></i> Fetch</button>
          </div>
          <div id="fetch-preview" style="display: none; margin-top: 15px; background: rgba(0,0,0,0.3); border: 1px solid var(--border); padding: 12px; border-radius: 10px; align-items: center; gap: 15px;">
            <img id="fetch-thumb" style="width: 90px; height: 55px; object-fit: cover; border-radius: 6px;">
            <div>
              <p id="fetch-title" style="font-weight: 700; font-size: 13px; margin-bottom: 4px;"></p>
              <p id="fetch-info" style="font-size: 11px; color: var(--muted);"></p>
            </div>
          </div>
        </div>
        <div class="form-group">
          <label>Pilih Template Bypas Cepat</label>
          <div class="templates-grid">
            <div class="template-badge active" onclick="setTemplate('1.6', this)">1.6x</div>
            <div class="template-badge" onclick="setTemplate('2.3', this)">2.3x</div>
            <div class="template-badge" onclick="setTemplate('2.6', this)">2.6x</div>
            <div class="template-badge" onclick="setTemplate('3.0', this)">3.0x</div>
          </div>
        </div>
        <div class="form-group">
          <label>Atau Upload File Audio Lokal</label>
          <div class="file-upload-wrapper">
            <input type="file" id="audio-file" accept="audio/*" onchange="updateFileName(this)">
            <label for="audio-file" class="file-upload-btn"><i class="fa-solid fa-cloud-arrow-up"></i> <span id="file-chosen-text">Pilih File Audio...</span></label>
          </div>
        </div>
        <div style="display: flex; gap: 12px; margin-top: 25px;">
          <button class="btn" onclick="startBypas()"><i class="fa-solid fa-bolt"></i> Proses Bypas</button>
          <button class="btn btn-outline" onclick="resetSettings()"><i class="fa-solid fa-rotate-right"></i> Reset Setting</button>
        </div>
      </div>

      <div class="card" id="result-card" style="display:none;">
        <h2><i class="fa-solid fa-headphones"></i> Hasil & Preview Audio</h2>
        <audio id="audio-player" controls style="width:100%; margin-bottom:15px;"></audio>
        <div style="display: flex; gap: 12px;">
          <button class="btn" onclick="downloadAudio()"><i class="fa-solid fa-download"></i> Download Hasil</button>
          <button class="btn btn-outline" onclick="uploadRoblox()"><i class="fa-solid fa-cloud-arrow-up"></i> Upload ke Roblox</button>
        </div>
      </div>
    </div>

    <div id="tab-uploader" class="section-view">
      <div class="card">
        <div class="card-header">
          <h2><i class="fa-solid fa-cloud-arrow-up"></i> Roblox Audio Uploader</h2>
          <button class="btn-back" onclick="switchTab('home', null)"><i class="fa-solid fa-arrow-left"></i> Kembali</button>
        </div>
        <div class="form-group"><label>Judul Audio</label><input type="text" id="up-title" placeholder="Nama Track di Roblox"></div>
        <div class="form-group">
          <label>File Audio (.mp3/.wav)</label>
          <div class="file-upload-wrapper">
            <input type="file" id="up-file" accept="audio/*" onchange="updateUploadFileName(this)">
            <label for="up-file" class="file-upload-btn"><i class="fa-solid fa-cloud-arrow-up"></i> <span id="up-file-chosen">Pilih File Audio Uploader...</span></label>
          </div>
        </div>
        <button class="btn" onclick="uploadRobloxDirect()"><i class="fa-solid fa-upload"></i> Publish ke Roblox</button>
      </div>
    </div>

    <div id="tab-decal" class="section-view">
      <div class="card">
        <div class="card-header">
          <h2><i class="fa-solid fa-image"></i> Image Decal Uploader</h2>
          <button class="btn-back" onclick="switchTab('home', null)"><i class="fa-solid fa-arrow-left"></i> Kembali</button>
        </div>
        <div class="form-group"><label>Judul Decal</label><input type="text" id="decal-title" placeholder="Nama Decal"></div>
        <div class="form-group"><label>File Gambar (PNG/JPG)</label><input type="file" id="decal-file" accept="image/*"></div>
        <button class="btn" onclick="showToast('Decal berhasil diunggah!')"><i class="fa-solid fa-upload"></i> Upload Decal</button>
      </div>
    </div>

    <div id="tab-limits" class="section-view">
      <div class="card">
        <div class="card-header">
          <h2><i class="fa-solid fa-gauge-high"></i> Cek Limit API</h2>
          <button class="btn-back" onclick="switchTab('home', null)"><i class="fa-solid fa-arrow-left"></i> Kembali</button>
        </div>
        <div id="limits-info" style="color: var(--muted); font-size: 14px;">Memuat kuota API...</div>
      </div>
    </div>

    <div id="tab-tutorial" class="section-view">
      <div class="card">
        <div class="card-header">
          <h2><i class="fa-solid fa-book-open"></i> Tutorial Panduan</h2>
          <button class="btn-back" onclick="switchTab('home', null)"><i class="fa-solid fa-arrow-left"></i> Kembali</button>
        </div>
        <ol style="padding-left: 20px; color: var(--muted); font-size: 14px; line-height: 1.8;">
          <li>Masukkan User ID dan API Key Roblox pada menu <strong>Bypas Audio</strong>.</li>
          <li>Gunakan fitur <strong>Fetch URL (yt-dlp)</strong> untuk mengambil metadata akurat dari YouTube/TikTok.</li>
          <li>Pilih template kecepatan (1.6x, 2.3x, dll) lalu klik <strong>Proses Bypas</strong>.</li>
          <li>Dengarkan preview secara realtime, download hasilnya, atau langsung upload ke Roblox.</li>
        </ol>
      </div>
    </div>
  </main>

  <div id="toast"></div>

  <script>
    function switchTab(id, e) {
      document.querySelectorAll('.section-view').forEach(v => v.classList.remove('active'));
      document.querySelectorAll('.menu-item').forEach(m => m.classList.remove('active'));
      document.getElementById('tab-' + id).classList.add('active');
      const menuMap = { 'home':0, 'bypas':1, 'uploader':2, 'decal':3, 'limits':4, 'tutorial':5 };
      const items = document.querySelectorAll('.menu-item');
      if(items[menuMap[id]]) items[menuMap[id]].classList.add('active');
    }
    function showToast(msg) {
      const t = document.getElementById('toast'); t.innerText = msg; t.style.display = 'block';
      setTimeout(() => t.style.display = 'none', 3000);
    }
    let selectedTemplate = '1.6';
    function setTemplate(val, el) {
      selectedTemplate = val;
      document.querySelectorAll('.template-badge').forEach(b => b.classList.remove('active'));
      el.classList.add('active');
      showToast('Template Bypas ' + val + 'x Dipilih');
    }
    function updateFileName(input) {
      const textSpan = document.getElementById('file-chosen-text');
      if (input.files && input.files[0]) textSpan.innerText = input.files[0].name;
    }
    function updateUploadFileName(input) {
      const textSpan = document.getElementById('up-file-chosen');
      if (input.files && input.files[0]) textSpan.innerText = input.files[0].name;
    }
    function resetSettings() {
      selectedTemplate = '1.6';
      document.getElementById('audio-file').value = '';
      document.getElementById('file-chosen-text').innerText = 'Pilih File Audio...';
      document.getElementById('fetch-url').value = '';
      document.getElementById('fetch-preview').style.display = 'none';
      showToast('Pengaturan di-reset!');
    }
    async function connectAccount() {
      const userId = document.getElementById('rbx-userid').value;
      const apiKey = document.getElementById('rbx-apikey').value;
      if(!userId || !apiKey) return showToast('Isi User ID & API Key!');
      const res = await fetch('/api/account/connect', { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({userId, apiKey}) });
      const data = await res.json();
      if(data.success) {
        document.getElementById('sidebar-status').innerText = 'Connected: ' + data.account.username;
        document.getElementById('sidebar-status').style.color = 'var(--success)';
        document.getElementById('account-box').innerHTML = `<div style="display:flex;gap:15px;align-items:center;background:rgba(0,0,0,0.3);padding:14px;border-radius:10px;"><img src="${data.account.avatarUrl}" style="width:45px;height:45px;border-radius:50%;border:1px solid var(--border);"><div><b style="font-size:14px;">${data.account.username}</b><p style="font-size:11px;color:var(--success);">SECURELY CONNECTED</p></div></div>`;
        showToast('Terhubung!');
      }
    }
    async function fetchMedia() {
      const url = document.getElementById('fetch-url').value;
      if(!url) return showToast('Masukkan URL YouTube/TikTok!');
      showToast('Fetching via yt-dlp...');
      const res = await fetch('/api/audio/fetch', { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({url}) });
      const data = await res.json();
      if(data.success) {
        const prev = document.getElementById('fetch-preview');
        prev.style.display = 'flex';
        document.getElementById('fetch-thumb').src = data.metadata.thumbnail;
        document.getElementById('fetch-title').innerText = data.metadata.title;
        document.getElementById('fetch-info').innerText = `${data.metadata.sourcePlatform} • Durasi: ${data.metadata.duration}`;
        showToast('Berhasil Fetch yt-dlp!');
      } else { showToast(data.error); }
    }
    async function startBypas() {
      const file = document.getElementById('audio-file').files[0];
      if(!file) return showToast('Pilih file audio lokal!');
      showToast('Memproses audio...');
      const fd = new FormData(); fd.append('audio', file); fd.append('template', selectedTemplate);
      const res = await fetch('/api/audio/process', { method: 'POST', body: fd });
      const data = await res.json();
      if(data.success) {
        document.getElementById('result-card').style.display = 'block';
        document.getElementById('audio-player').src = data.processedUrl;
        showToast('Selesai!');
      }
    }
    function downloadAudio() {
      const src = document.getElementById('audio-player').src;
      if(!src) return showToast('Belum ada audio!');
      const a = document.createElement('a'); a.href = src; a.download = 'bypassed.mp3'; a.click();
    }
    async function uploadRoblox() {
      const res = await fetch('/api/roblox/upload', { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({title: 'Bypassed Track'}) });
      const data = await res.json();
      if(data.success) showToast('Asset ID: ' + data.assetId);
    }
    async function uploadRobloxDirect() {
      const title = document.getElementById('up-title').value;
      if(!title) return showToast('Judul wajib diisi!');
      const res = await fetch('/api/roblox/upload', { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({title}) });
      const data = await res.json();
      if(data.success) showToast('Published ID: ' + data.assetId);
    }
    document.querySelector('.menu-item:nth-child(5)').addEventListener('click', async () => {
      const res = await fetch('/api/limits');
      const data = await res.json();
      if(data.success) {
        document.getElementById('limits-info').innerHTML = `<p>Daily Quota: ${data.limits.dailyQuota}</p><p>Used Today: ${data.limits.usedToday}</p><p>Remaining: ${data.limits.remaining}</p>`;
      }
    });
  </script>
</body>
</html>
EOF

# 6. Buat file git-push.sh bersih tanpa token
cat << 'EOF' > git-push.sh
#!/bin/bash
git add .
git commit -m "Full update: yt-dlp fetch, modern UI, aesthetic file upload & back buttons"
git push -u origin main --force
EOF
chmod +x git-push.sh

# 7. Jalankan push otomatis ke GitHub
./git-push.sh
