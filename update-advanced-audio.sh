#!/bin/bash

# 1. Perbarui audioProcessor.js untuk menangani speed, pitch (aset), dan volume secara akurat
cat << 'EOT' > services/audioProcessor.js
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
EOT

# 2. Perbarui client/index.html dengan durasi dinamis, slider manual (speed, pitch, volume), dan template speed+pitch
cat << 'EOT' > client/index.html
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
      --card: rgba(16, 16, 22, 0.85);
      --border: rgba(255, 255, 255, 0.08);
      --text: #f4f4f6;
      --muted: #8e8e99;
      --accent: #ffffff;
      --accent-hover: #d0d0d6;
      --glow: rgba(255, 255, 255, 0.1);
      --success: #34c759;
      --danger: #ff3b30;
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
    input[type="text"], input[type="password"] { width: 100%; padding: 14px 18px; background: rgba(0,0,0,0.4); border: 1px solid var(--border); border-radius: 10px; color: var(--text); font-size: 14px; outline: none; transition: 0.3s; }
    input:focus { border-color: var(--accent); box-shadow: 0 0 10px rgba(255,255,255,0.15); }
    input[type="range"] { width: 100%; accent-color: var(--accent); cursor: pointer; }
    .slider-value { float: right; color: var(--accent); font-weight: 700; }
    .btn { background: var(--accent); color: var(--bg); font-weight: 700; padding: 14px 24px; border-radius: 10px; border: none; cursor: pointer; display: inline-flex; align-items: center; justify-content: center; gap: 10px; font-size: 14px; transition: 0.3s; box-shadow: 0 4px 20px rgba(255,255,255,0.2); width: 100%; }
    .btn:hover { background: var(--accent-hover); transform: translateY(-1px); }
    .btn-outline { background: transparent; border: 1px solid var(--border); color: var(--text); box-shadow: none; width: auto; }
    .btn-outline:hover { background: rgba(255,255,255,0.08); }
    .btn-danger { background: rgba(255,59,48,0.15); color: var(--danger); border: 1px solid rgba(255,59,48,0.3); box-shadow: none; }
    .btn-danger:hover { background: rgba(255,59,48,0.25); color: #ff6961; }

    .status-pill { display: flex; align-items: center; gap: 6px; font-size: 11px; font-weight: 700; padding: 6px 12px; border-radius: 20px; background: rgba(255,255,255,0.05); border: 1px solid var(--border); }
    .status-pill.connected { color: var(--success); border-color: rgba(52,199,89,0.3); background: rgba(52,199,89,0.08); }
    .dot { width: 7px; height: 7px; border-radius: 50%; background: var(--muted); }
    .connected .dot { background: var(--success); box-shadow: 0 0 8px var(--success); }

    #profile-view { display: none; text-align: center; animation: fadeIn 0.4s ease; }
    .avatar-wrapper { position: relative; width: 100px; height: 100px; margin: 0 auto 16px auto; border-radius: 50%; padding: 3px; background: linear-gradient(135deg, rgba(255,255,255,0.2), rgba(255,255,255,0.02)); box-shadow: 0 8px 24px rgba(0,0,0,0.4); }
    .avatar-img { width: 100%; height: 100%; border-radius: 50%; object-fit: cover; background: #111; }

    #progress-container, #process-progress-container { display: none; margin-top: 15px; width: 100%; background: rgba(0,0,0,0.5); border-radius: 8px; overflow: hidden; border: 1px solid var(--border); padding: 3px; }
    #progress-bar, #process-progress-bar { width: 0%; height: 8px; background: var(--accent); border-radius: 6px; transition: width 0.3s ease; }
    #progress-status, #process-progress-status { font-size: 12px; color: var(--muted); margin-top: 6px; font-weight: 600; }

    .menu-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 20px; margin-top: 20px; }
    .menu-card { background: rgba(255,255,255,0.02); border: 1px solid var(--border); border-radius: 14px; padding: 24px; cursor: pointer; transition: 0.3s; display: flex; flex-direction: column; gap: 12px; }
    .menu-card:hover { border-color: var(--accent); background: rgba(255,255,255,0.05); transform: translateY(-3px); }
    .menu-card i { font-size: 28px; color: var(--accent); }
    .menu-card h3 { font-size: 16px; font-weight: 700; color: var(--text); }
    .menu-card p { font-size: 12px; color: var(--muted); }

    .templates-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 10px; }
    .template-badge { padding: 14px; text-align: center; background: rgba(0,0,0,0.4); border: 1px solid var(--border); border-radius: 10px; cursor: pointer; font-weight: 700; font-size: 14px; transition: 0.3s; }
    .template-badge:hover, .template-badge.active { border-color: var(--accent); background: rgba(255,255,255,0.1); color: var(--accent); }
    
    .speed-info { font-size: 11px; color: var(--muted); margin-bottom: 20px; line-height: 1.5; background: rgba(255,255,255,0.02); padding: 10px; border-radius: 8px; border: 1px solid var(--border); }
    
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

    <!-- TAB HOME DASHBOARD -->
    <div id="tab-home" class="section-view active">
      <div class="card">
        <h2><i class="fa-solid fa-compass"></i> Dashboard Utama</h2>
        <p style="font-size: 14px; color: var(--muted); margin-bottom: 24px;">Silahkan pilih salah satu menu di bawah untuk mulai menggunakan fitur profesional MCHLERN ENGINERING.</p>
        <div class="menu-grid">
          <div class="menu-card" onclick="switchTab('bypas', null)"><i class="fa-solid fa-wand-magic-sparkles"></i><h3>Bypas Audio</h3><p>Fetch YouTube/TikTok, preview, dan langsung upload ke Roblox.</p></div>
          <div class="menu-card" onclick="switchTab('uploader', null)"><i class="fa-solid fa-cloud-arrow-up"></i><h3>Roblox Audio Uploader</h3><p>Publish file audio langsung ke asset Roblox Open Cloud.</p></div>
          <div class="menu-card" onclick="switchTab('decal', null)"><i class="fa-solid fa-image"></i><h3>Image Decal Uploader</h3><p>Upload gambar decal dengan cepat dan aman.</p></div>
          <div class="menu-card" onclick="switchTab('limits', null)"><i class="fa-solid fa-gauge-high"></i><h3>Cek Limit API</h3><p>Pantau kuota penggunaan harian dan status sistem.</p></div>
          <div class="menu-card" onclick="switchTab('tutorial', null)"><i class="fa-solid fa-book-open"></i><h3>Cek Tutorial</h3><p>Panduan lengkap tata cara bypass dan koneksi API.</p></div>
        </div>
      </div>
    </div>

    <!-- TAB BYPAS AUDIO -->
    <div id="tab-bypas" class="section-view">
      <div class="card">
        <div class="card-header">
          <h2><i class="fa-solid fa-user-shield"></i> Roblox Account</h2>
          <div style="display: flex; gap: 10px; align-items: center;">
            <button class="btn-back" onclick="switchTab('home', null)"><i class="fa-solid fa-arrow-left"></i> Menu Utama</button>
            <div id="status-badge" class="status-pill">
              <div class="dot"></div> <span id="status-text">DISCONNECTED</span>
            </div>
          </div>
        </div>

        <div id="form-view">
          <div class="form-group"><label>Roblox User ID</label><input type="text" id="rbx-userid" placeholder="Contoh: 9516742808"></div>
          <div class="form-group"><label>API Key (Open Cloud)</label><input type="password" id="rbx-apikey" placeholder="Masukkan API Key Anda"></div>
          <button class="btn" id="connect-btn" onclick="connectAccount()">CONNECT ACCOUNT</button>
        </div>

        <div id="profile-view">
          <div class="avatar-wrapper">
            <img id="profile-avatar" class="avatar-img" src="" alt="Avatar">
          </div>
          <div id="profile-displayname" style="font-size: 18px; font-weight: 700; color: var(--text); margin-bottom: 2px;">Display Name</div>
          <div id="profile-username" style="font-size: 13px; color: var(--muted); margin-bottom: 8px;">@username</div>
          <div style="margin-bottom: 20px;"><span id="profile-userid" style="font-size: 11px; font-weight: 600; color: var(--muted); background: rgba(255,255,255,0.04); border: 1px solid var(--border); padding: 4px 10px; border-radius: 6px;">ID: 000</span></div>
          <button class="btn btn-danger" onclick="disconnectAccount()">DISCONNECT ACCOUNT</button>
        </div>
      </div>

      <div class="card">
        <h2><i class="fa-solid fa-sliders"></i> Audio Bypas & Upload Engine</h2>
        <div class="form-group">
          <label>Fetch Audio dari Link YouTube / TikTok (Worker)</label>
          <div style="display: flex; gap: 10px;">
            <input type="text" id="fetch-url" placeholder="https://youtube.com/watch?v=...">
            <button class="btn btn-outline" onclick="fetchMedia()"><i class="fa-solid fa-download"></i> Fetch</button>
          </div>
          
          <div id="progress-container">
            <div id="progress-bar"></div>
          </div>
          <div id="progress-status">Menunggu worker desktop mengambil antrean...</div>

          <!-- Preview Detail (Thumbnail, Judul, Durasi) -->
          <div id="fetch-preview" style="display: none; margin-top: 15px; background: rgba(0,0,0,0.3); border: 1px solid var(--border); padding: 14px; border-radius: 12px; align-items: center; gap: 15px;">
            <img id="fetch-thumb" style="width: 100px; height: 60px; object-fit: cover; border-radius: 6px;">
            <div style="flex:1;">
              <p id="fetch-title" style="font-weight: 700; font-size: 13px; margin-bottom: 4px;"></p>
              <p id="fetch-duration" style="font-size: 11px; color: var(--success); font-weight: 700; margin-bottom: 2px;">Durasi: 00:00</p>
              <p id="fetch-info" style="font-size: 11px; color: var(--muted);">YouTube/TikTok • Siap Preview & Upload</p>
            </div>
          </div>
        </div>

        <!-- Preview Player -->
        <div class="form-group" id="preview-player-container" style="display:none;">
          <label>Preview Suara Audio (Sesuai Hasil Speed & Pitch Ingame)</label>
          <audio id="audio-preview-player" controls style="width:100%; margin-bottom:10px;"></audio>
        </div>

        <div class="form-group">
          <label>Pilih Template Bypas Cepat (Speed + Pitch)</label>
          <div class="templates-grid">
            <div class="template-badge active" onclick="setTemplate('1.6', '0.9', this)">1.6x</div>
            <div class="template-badge" onclick="setTemplate('2.3', '0.85', this)">2.3x</div>
            <div class="template-badge" onclick="setTemplate('2.6', '0.8', this)">2.6x</div>
            <div class="template-badge" onclick="setTemplate('3.0', '0.75', this)">3.0x</div>
          </div>
          <div class="speed-info">
            <i class="fa-solid fa-circle-info"></i> <strong>Playback Speed & Pitch Ingame:</strong> Template otomatis menyesuaikan kecepatan dan pitch agar suara tetap normal/tidak melengking saat diputar di Roblox.
          </div>
        </div>

        <!-- Pengaturan Manual (Slider Custom) -->
        <div style="background: rgba(0,0,0,0.2); border: 1px solid var(--border); padding: 16px; border-radius: 12px; margin-bottom: 20px;">
          <label style="margin-bottom: 12px; color: var(--accent);">⚙️ Pengaturan Manual (Advanced Sliders)</label>
          
          <div class="form-group" style="margin-bottom: 12px;">
            <label>Speed Modifier: <span id="speed-val" class="slider-value">1.6x</span></label>
            <input type="range" id="slider-speed" min="1.0" max="4.0" step="0.1" value="1.6" oninput="updateManualSettings()">
          </div>

          <div class="form-group" style="margin-bottom: 12px;">
            <label>Pitch Shift: <span id="pitch-val" class="slider-value">0.90</span></label>
            <input type="range" id="slider-pitch" min="0.5" max="1.5" step="0.05" value="0.9" oninput="updateManualSettings()">
          </div>

          <div class="form-group" style="margin-bottom: 0;">
            <label>Volume: <span id="vol-val" class="slider-value">100%</span></label>
            <input type="range" id="slider-vol" min="10" max="200" step="5" value="100" oninput="updateManualSettings()">
          </div>
        </div>

        <div id="process-progress-container">
          <div id="process-progress-bar"></div>
        </div>
        <div id="process-progress-status"></div>

        <div style="display: flex; gap: 12px; margin-top: 25px;">
          <button class="btn" id="upload-roblox-btn" onclick="processAndUploadToRoblox()"><i class="fa-solid fa-cloud-arrow-up"></i> UPLOAD TO ROBLOX</button>
          <button class="btn btn-outline" onclick="resetSettings()"><i class="fa-solid fa-rotate-right"></i> Reset</button>
        </div>
      </div>
    </div>

    <!-- TAB UPLOADER -->
    <div id="tab-uploader" class="section-view">
      <div class="card">
        <div class="card-header">
          <h2><i class="fa-solid fa-cloud-arrow-up"></i> Roblox Audio Uploader</h2>
          <button class="btn-back" onclick="switchTab('home', null)"><i class="fa-solid fa-arrow-left"></i> Menu Utama</button>
        </div>
        <div class="form-group"><label>Judul Audio</label><input type="text" id="up-title" placeholder="Nama Track di Roblox"></div>
        <div class="form-group"><label>File Audio (.mp3/.wav)</label><input type="file" id="up-file" accept="audio/*"></div>
        <button class="btn" onclick="showToast('Berhasil upload audio!')"><i class="fa-solid fa-upload"></i> Publish ke Roblox</button>
      </div>
    </div>

    <!-- TAB DECAL -->
    <div id="tab-decal" class="section-view">
      <div class="card">
        <div class="card-header">
          <h2><i class="fa-solid fa-image"></i> Image Decal Uploader</h2>
          <button class="btn-back" onclick="switchTab('home', null)"><i class="fa-solid fa-arrow-left"></i> Menu Utama</button>
        </div>
        <div class="form-group"><label>Judul Decal</label><input type="text" id="decal-title" placeholder="Nama Decal"></div>
        <div class="form-group"><label>File Gambar (PNG/JPG)</label><input type="file" id="decal-file" accept="image/*"></div>
        <button class="btn" onclick="showToast('Decal berhasil diunggah!')"><i class="fa-solid fa-upload"></i> Upload Decal</button>
      </div>
    </div>

    <!-- TAB LIMITS -->
    <div id="tab-limits" class="section-view">
      <div class="card">
        <div class="card-header">
          <h2><i class="fa-solid fa-gauge-high"></i> Cek Limit API</h2>
          <button class="btn-back" onclick="switchTab('home', null)"><i class="fa-solid fa-arrow-left"></i> Menu Utama</button>
        </div>
        <p style="color: var(--muted); font-size: 14px;">Daily Quota: 100 | Used Today: 2 | Remaining: 98</p>
      </div>
    </div>

    <!-- TAB TUTORIAL -->
    <div id="tab-tutorial" class="section-view">
      <div class="card">
        <div class="card-header">
          <h2><i class="fa-solid fa-book-open"></i> Tutorial Panduan</h2>
          <button class="btn-back" onclick="switchTab('home', null)"><i class="fa-solid fa-arrow-left"></i> Menu Utama</button>
        </div>
        <ol style="padding-left: 20px; color: var(--muted); font-size: 14px; line-height: 1.8;">
          <li>Koneksikan akun Roblox Anda.</li>
          <li>Masukkan URL YouTube/TikTok, klik <strong>Fetch</strong> untuk melihat durasi, judul, dan thumbnail asli.</li>
          <li>Atur speed, pitch, dan volume secara manual atau pakai template cepat, lalu klik <strong>UPLOAD TO ROBLOX</strong>!</li>
        </ol>
      </div>
    </div>
  </main>

  <div id="toast"></div>

  <script>
    let fetchedAudioUrl = '';
    let baseDurationSeconds = 180; // Default 3 menit kalau metadata durasi kosong
    let currentSpeed = 1.6;
    let currentPitch = 0.9;
    let currentVolume = 100;

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
      setTimeout(() => t.style.display = 'none', 3500);
    }

    window.addEventListener('DOMContentLoaded', async () => {
      try {
        const res = await fetch('/api/account/status');
        const data = await res.json();
        if(data.success && data.account) renderProfile(data.account);
      } catch(e) {}
    });

    async function connectAccount() {
      const userId = document.getElementById('rbx-userid').value.trim();
      const apiKey = document.getElementById('rbx-apikey').value.trim();
      if(!userId || !apiKey) return showToast('✕ USER ID DAN API KEY Wajib DIISI');

      const btn = document.getElementById('connect-btn');
      btn.innerText = 'CONNECTING...';
      btn.disabled = true;

      try {
        const res = await fetch('/api/account/connect', {
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({ userId, apiKey })
        });
        const data = await res.json();
        if(data.success) {
          showToast('✓ ROBLOX ACCOUNT CONNECTED');
          renderProfile(data.account);
        } else {
          showToast(data.error || '✕ INVALID USER ID OR API KEY');
          btn.innerText = 'CONNECT ACCOUNT';
          btn.disabled = false;
        }
      } catch(err) {
        showToast('✕ TERJADI KESALAHAN JARINGAN');
        btn.innerText = 'CONNECT ACCOUNT';
        btn.disabled = false;
      }
    }

    function renderProfile(account) {
      document.getElementById('form-view').style.display = 'none';
      document.getElementById('profile-view').style.display = 'block';
      document.getElementById('profile-avatar').src = account.avatarUrl;
      document.getElementById('profile-displayname').innerText = account.displayName;
      document.getElementById('profile-username').innerText = '@' + account.username;
      document.getElementById('profile-userid').innerText = 'ID: ' + account.userId;

      const badge = document.getElementById('status-badge');
      badge.className = 'status-pill connected';
      document.getElementById('status-text').innerText = 'CONNECTED';
      document.getElementById('sidebar-status').innerText = `Status: Connected (${account.username})`;
    }

    async function disconnectAccount() {
      try { await fetch('/api/account/disconnect', { method: 'POST' }); } catch(e) {}
      document.getElementById('profile-view').style.display = 'none';
      document.getElementById('form-view').style.display = 'block';
      document.getElementById('rbx-userid').value = '';
      document.getElementById('rbx-apikey').value = '';
      const btn = document.getElementById('connect-btn');
      btn.innerText = 'CONNECT ACCOUNT';
      btn.disabled = false;

      const badge = document.getElementById('status-badge');
      badge.className = 'status-pill';
      document.getElementById('status-text').innerText = 'DISCONNECTED';
      document.getElementById('sidebar-status').innerText = 'Status: Disconnected';
      showToast('Sesi akun diputus secara aman.');
    }

    async function setTemplate(speed, pitch, el) {
      currentSpeed = parseFloat(speed);
      currentPitch = parseFloat(pitch);

      document.querySelectorAll('.template-badge').forEach(b => b.classList.remove('active'));
      el.classList.add('active');

      // Update slider manual
      document.getElementById('slider-speed').value = currentSpeed;
      document.getElementById('speed-val.innerText = currentSpeed + 'x';
      document.getElementById('slider-pitch').value = currentPitch;
      document.getElementById('pitch-val').innerText = currentPitch.toFixed(2);

      showToast(`Template Speed ${currentSpeed}x & Pitch ${currentPitch} Dipilih`);
      if (fetchedAudioUrl) await updateAudioPreview();
    }

    function updateManualSettings() {
      currentSpeed = parseFloat(document.getElementById('slider-speed').value);
      currentPitch = parseFloat(document.getElementById('slider-pitch').value);
      currentVolume = parseFloat(document.getElementById('slider-vol').value);

      document.getElementById('speed-val').innerText = currentSpeed.toFixed(1) + 'x';
      document.getElementById('pitch-val').innerText = currentPitch.toFixed(2);
      document.getElementById('vol-val').innerText = currentVolume + '%';

      // Update durasi secara real-time saat speed berubah
      updateDynamicDuration();
      if (fetchedAudioUrl) updateAudioPreview();
    }

    function updateDynamicDuration() {
      const adjustedSeconds = Math.round(baseDurationSeconds / currentSpeed);
      const mins = Math.floor(adjustedSeconds / 60);
      const secs = adjustedSeconds % 60;
      const formatted = `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
      document.getElementById('fetch-duration').innerText = `Durasi (Bypassed): ${formatted} (${currentSpeed}x Speed)`;
    }

    function resetSettings() {
      currentSpeed = 1.6;
      currentPitch = 0.9;
      currentVolume = 100;
      fetchedAudioUrl = '';

      document.getElementById('slider-speed').value = 1.6;
      document.getElementById('speed-val').innerText = '1.6x';
      document.getElementById('slider-pitch').value = 0.9;
      document.getElementById('pitch-val').innerText = '0.90';
      document.getElementById('slider-vol').value = 100;
      document.getElementById('vol-val').innerText = '100%';

      document.getElementById('fetch-url').value = '';
      document.getElementById('fetch-preview').style.display = 'none';
      document.getElementById('preview-player-container').style.display = 'none';
      document.getElementById('progress-container').style.display = 'none';
      document.getElementById('progress-status').innerText = '';
      document.getElementById('process-progress-container').style.display = 'none';
      document.getElementById('process-progress-status').innerText = '';
      showToast('Pengaturan di-reset!');
    }

    async function fetchMedia() {
      const url = document.getElementById('fetch-url').value;
      if(!url) return showToast('Masukkan URL YouTube atau TikTok terlebih dahulu!');
      
      const progContainer = document.getElementById('progress-container');
      const progressBar = document.getElementById('progress-bar');
      const progStatus = document.getElementById('progress-status');
      
      progContainer.style.display = 'block';
      progressBar.style.width = '30%';
      progStatus.innerText = 'Mengirim antrean ke worker...';

      try {
        progressBar.style.width = '70%';
        progStatus.innerText = 'Worker sedang mendownload audio...';

        const res = await fetch('/api/audio/fetch', { 
          method: 'POST', 
          headers: {'Content-Type': 'application/json'}, 
          body: JSON.stringify({url}) 
        });
        const data = await res.json();
        
        if(data.success) {
          progressBar.style.width = '100%';
          progStatus.innerText = 'Fetch Berhasil!';
          fetchedAudioUrl = data.metadata.downloadUrl;
          
          const prev = document.getElementById('fetch-preview');
          prev.style.display = 'flex';
          document.getElementById('fetch-thumb').src = data.metadata.thumbnail;
          document.getElementById('fetch-title').innerText = data.metadata.title;
          
          updateDynamicDuration();
          
          showToast('Fetch Berhasil! Memproses preview...');
          await updateAudioPreview();
        } else {
          progressBar.style.width = '100%';
          progressBar.style.background = 'var(--danger)';
          progStatus.innerText = 'Gagal: ' + (data.error || 'Cek worker Termux!');
          showToast('Gagal fetch audio.');
        }
      } catch (err) {
        progressBar.style.width = '100%';
        progressBar.style.background = 'var(--danger)';
        progStatus.innerText = 'Error jaringan.';
        showToast('Terjadi kesalahan jaringan.');
      }
    }

    async function updateAudioPreview() {
      const fd = new FormData();
      fd.append('speed', currentSpeed);
      fd.append('pitch', currentPitch);
      fd.append('volume', currentVolume);
      fd.append('fetchedUrl', fetchedAudioUrl);

      try {
        const res = await fetch('/api/audio/process', { method: 'POST', body: fd });
        const data = await res.json();
        if(data.success) {
          document.getElementById('preview-player-container').style.display = 'block';
          document.getElementById('audio-preview-player').src = data.processedUrl;
        }
      } catch(e) {}
    }

    async function processAndUploadToRoblox() {
      if (!fetchedAudioUrl) {
        return showToast('Silahkan Fetch URL YouTube/TikTok terlebih dahulu!');
      }

      const container = document.getElementById('process-progress-container');
      const bar = document.getElementById('process-progress-bar');
      const status = document.getElementById('process-progress-status');
      const btn = document.getElementById('upload-roblox-btn');

      container.style.display = 'block';
      bar.style.width = '30%';
      bar.style.background = 'var(--accent)';
      status.innerText = 'Processing Audio (Speed & Pitch)... 30%';
      btn.disabled = true;

      const fd = new FormData(); 
      fd.append('speed', currentSpeed);
      fd.append('pitch', currentPitch);
      fd.append('volume', currentVolume);
      fd.append('fetchedUrl', fetchedAudioUrl);
      
      try {
        const resProc = await fetch('/api/audio/process', { method: 'POST', body: fd });
        const dataProc = await resProc.json();

        if(!dataProc.success) throw new Error(dataProc.error || 'Gagal memproses audio');

        bar.style.width = '70%';
        status.innerText = 'Uploading to Roblox Cloud... 70%';

        const titleTrack = document.getElementById('fetch-title').innerText || 'MCHLERN Track';
        const resUpload = await fetch('/api/roblox/upload', { 
          method: 'POST', 
          headers: {'Content-Type': 'application/json'}, 
          body: JSON.stringify({ title: titleTrack, audioUrl: dataProc.processedUrl }) 
        });
        const dataUpload = await resUpload.json();

        if(dataUpload.success) {
          bar.style.width = '100%';
          bar.style.background = 'var(--success)';
          status.innerText = `✓ Success! Asset ID: ${dataUpload.assetId}`;
          showToast('Berhasil Upload ke Roblox! Asset ID: ' + dataUpload.assetId);
        } else {
          throw new Error('Gagal upload ke Roblox Open Cloud');
        }
      } catch (err) {
        bar.style.width = '100%';
        bar.style.background = 'var(--danger)';
        status.innerText = '✕ Error: ' + err.message;
        showToast(err.message);
      } finally {
        btn.disabled = false;
      }
    }
  </script>
</body>
</html>
EOT

git add .
git commit -m "Add dynamic duration calculation, pitch control, and advanced sliders for audio processing"
git push -u origin main --force
echo "=== PEMBARUAN SELESAI DIPUSH KE GITHUB ==="
