#!/bin/bash

# 1. Buat file Aptfile untuk Railway agar otomatis menginstal ffmpeg di cloud container
echo "ffmpeg" > Aptfile

# 2. Instal ffmpeg-static agar node.js memiliki akses binari lokal yang aman
npm install ffmpeg-static

# 3. Perbarui audioProcessor.js agar menggunakan ffmpeg-static dengan jalur yang benar
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
EOT

# 4. Perbarui client/index.html sesuai permintaan Anda:
# - Menghapus tombol "Proses Bypas" terpisah dan langsung mengganti alurnya menjadi tombol "UPLOAD TO ROBLOX" setelah fetch & preview selesai.
# - Menambahkan panduan teks kecepatan ingame Roblox (misal: "Ingame Pitch Normal: Gunakan 1.6x atau 2.3x agar suara tidak melengking").
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
    .form-group { margin-bottom: 20px; }
    label { display: block; font-size: 12px; font-weight: 700; color: var(--muted); text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px; }
    input, select { width: 100%; padding: 14px 18px; background: rgba(0,0,0,0.4); border: 1px solid var(--border); border-radius: 10px; color: var(--text); font-size: 14px; outline: none; transition: 0.3s; }
    input:focus { border-color: var(--accent); box-shadow: 0 0 10px rgba(255,255,255,0.15); }
    .btn { background: var(--accent); color: var(--bg); font-weight: 700; padding: 14px 24px; border-radius: 10px; border: none; cursor: pointer; display: inline-flex; align-items: center; justify-content: center; gap: 10px; font-size: 14px; transition: 0.3s; box-shadow: 0 4px 20px rgba(255,255,255,0.2); width: 100%; }
    .btn:hover { background: var(--accent-hover); transform: translateY(-1px); }
    .btn-outline { background: transparent; border: 1px solid var(--border); color: var(--text); box-shadow: none; }
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

    #process-progress-container { display: none; margin-top: 15px; width: 100%; background: rgba(0,0,0,0.5); border-radius: 8px; overflow: hidden; border: 1px solid var(--border); padding: 3px; }
    #process-progress-bar { width: 0%; height: 8px; background: var(--accent); border-radius: 6px; transition: width 0.4s ease; }
    #process-progress-status { font-size: 12px; color: var(--muted); margin-top: 6px; font-weight: 600; }

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

    <div id="tab-home" class="section-view active">
      <div class="card">
        <h2><i class="fa-solid fa-compass"></i> Dashboard Utama</h2>
        <p style="font-size: 14px; color: var(--muted); margin-bottom: 24px;">Silahkan pilih salah satu menu di bawah untuk mulai menggunakan fitur profesional MCHLERN ENGINERING.</p>
        <div class="menu-grid" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 20px;">
          <div class="menu-card" onclick="switchTab('bypas', null)" style="background: rgba(255,255,255,0.02); border: 1px solid var(--border); border-radius: 14px; padding: 24px; cursor: pointer;"><i class="fa-solid fa-wand-magic-sparkles" style="font-size: 28px; color: var(--accent); margin-bottom: 12px;"></i><h3>Bypas Audio</h3><p style="font-size: 12px; color: var(--muted); margin-top: 6px;">Fetch YouTube/TikTok, preview, dan langsung upload ke Roblox.</p></div>
        </div>
      </div>
    </div>

    <div id="tab-bypas" class="section-view">
      <div class="card">
        <div class="card-header">
          <h2><i class="fa-solid fa-user-shield"></i> Roblox Account</h2>
          <div id="status-badge" class="status-pill">
            <div class="dot"></div> <span id="status-text">DISCONNECTED</span>
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
            <button class="btn btn-outline" style="width: auto;" onclick="fetchMedia()"><i class="fa-solid fa-download"></i> Fetch</button>
          </div>
          
          <div id="fetch-preview" style="display: none; margin-top: 15px; background: rgba(0,0,0,0.3); border: 1px solid var(--border); padding: 12px; border-radius: 10px; align-items: center; gap: 15px;">
            <img id="fetch-thumb" style="width: 90px; height: 55px; object-fit: cover; border-radius: 6px;">
            <div style="flex:1;">
              <p id="fetch-title" style="font-weight: 700; font-size: 13px; margin-bottom: 4px;"></p>
              <p id="fetch-info" style="font-size: 11px; color: var(--muted);"></p>
            </div>
          </div>
        </div>

        <!-- Preview Player agar user bisa dengerin hasil audionya sebelum di-upload -->
        <div class="form-group" id="preview-player-container" style="display:none;">
          <label>Preview Suara Audio (Sesuai Hasil Speed Ingame)</label>
          <audio id="audio-preview-player" controls style="width:100%; margin-bottom:10px;"></audio>
        </div>

        <div class="form-group">
          <label>Pilih Template Bypas Cepat</label>
          <div class="templates-grid">
            <div class="template-badge active" onclick="setTemplate('1.6', this)">1.6x</div>
            <div class="template-badge" onclick="setTemplate('2.3', this)">2.3x</div>
            <div class="template-badge" onclick="setTemplate('2.6', this)">2.6x</div>
            <div class="template-badge" onclick="setTemplate('3.0', this)">3.0x</div>
          </div>
          <div class="speed-info">
            <i class="fa-solid fa-circle-info"></i> <strong>Playback Speed Ingame:</strong> Pilih kecepatan di atas untuk menyesuaikan pitch audio agar terdengar normal/tidak melengking saat diputar melalui Sound/Audio di dalam game Roblox.
          </div>
        </div>

        <!-- Progress Bar & Status -->
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
  </main>

  <div id="toast"></div>

  <script>
    let fetchedAudioUrl = '';

    function switchTab(id, e) {
      document.querySelectorAll('.section-view').forEach(v => v.classList.remove('active'));
      document.querySelectorAll('.menu-item').forEach(m => m.classList.remove('active'));
      document.getElementById('tab-' + id).classList.add('active');
    }

    function showToast(msg) {
      const t = document.getElementById('toast'); t.innerText = msg; t.style.display = 'block';
      setTimeout(() => t.style.display = 'none', 3500);
    }

    window.addEventListener('DOMContentLoaded', async () => {
      try {
        const res = await fetch('/api/account/status');
        const data = await res.json();
        if(data.success && data.account) {
          renderProfile(data.account);
        }
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

    let selectedTemplate = '1.6';
    async function setTemplate(val, el) {
      selectedTemplate = val;
      document.querySelectorAll('.template-badge').forEach(b => b.classList.remove('active'));
      el.classList.add('active');
      showToast('Template Speed ' + val + 'x Dipilih');
      
      // Jika sudah ada fetchedAudioUrl, otomatis update preview dengan speed baru
      if (fetchedAudioUrl) {
        await updateAudioPreview();
      }
    }

    function resetSettings() {
      selectedTemplate = '1.6';
      fetchedAudioUrl = '';
      document.getElementById('fetch-url').value = '';
      document.getElementById('fetch-preview').style.display = 'none';
      document.getElementById('preview-player-container').style.display = 'none';
      document.getElementById('process-progress-container').style.display = 'none';
      document.getElementById('process-progress-status').innerText = '';
      showToast('Pengaturan di-reset!');
    }

    async function fetchMedia() {
      const url = document.getElementById('fetch-url').value;
      if(!url) return showToast('Masukkan URL YouTube atau TikTok terlebih dahulu!');
      
      showToast('Mengirim antrean fetch worker...');
      try {
        const res = await fetch('/api/audio/fetch', { 
          method: 'POST', 
          headers: {'Content-Type': 'application/json'}, 
          body: JSON.stringify({url}) 
        });
        const data = await res.json();
        
        if(data.success) {
          fetchedAudioUrl = data.metadata.downloadUrl;
          const prev = document.getElementById('fetch-preview');
          prev.style.display = 'flex';
          document.getElementById('fetch-thumb').src = data.metadata.thumbnail;
          document.getElementById('fetch-title').innerText = data.metadata.title;
          document.getElementById('fetch-info').innerText = `${data.metadata.sourcePlatform} • Siap Preview & Upload`;
          
          showToast('Fetch Berhasil! Memproses preview...');
          await updateAudioPreview();
        } else {
          showToast('Gagal fetch: ' + (data.error || 'Cek worker Termux!'));
        }
      } catch (err) {
        showToast('Terjadi kesalahan jaringan.');
      }
    }

    // Fungsi untuk memperbarui preview audio otomatis sesuai speed template
    async function updateAudioPreview() {
      const fd = new FormData();
      fd.append('template', selectedTemplate);
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

    // Tombol utama: otomatis bypass/proses speed lalu langsung upload ke Roblox
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
      status.innerText = 'Processing Audio... 30%';
      btn.disabled = true;

      const fd = new FormData(); 
      fd.append('template', selectedTemplate);
      fd.append('fetchedUrl', fetchedAudioUrl);
      
      try {
        // Step 1: Proses Bypass Audio
        const resProc = await fetch('/api/audio/process', { method: 'POST', body: fd });
        const dataProc = await resProc.json();

        if(!dataProc.success) {
          throw new Error(dataProc.error || 'Gagal memproses audio');
        }

        bar.style.width = '70%';
        status.innerText = 'Uploading to Roblox Cloud... 70%';

        // Step 2: Upload otomatis ke Roblox
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
git commit -m "Integrate Aptfile, fix FFmpeg path, and update UI workflow to direct Upload to Roblox with Speed info"
git push -u origin main --force
echo "=== PEMBARUAN SELESAI DIPUSH KE GITHUB ==="
