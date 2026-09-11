require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const https = require('https');

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
app.use('/uploads', express.static(uploadsDir, {
  setHeaders: (res, filePath) => {
    if (filePath.endsWith('.mp3')) {
      res.setHeader('Content-Type', 'audio/mpeg');
      res.setHeader('Accept-Ranges', 'bytes');
    }
  }
}));

const dbPath = path.join(storageDir, 'db.json');
function getDB() {
  if (!fs.existsSync(dbPath)) return { account: null, history: [] };
  try { return JSON.parse(fs.readFileSync(dbPath, 'utf8')); } catch(e) { return { account: null, history: [] }; }
}
function saveDB(data) { fs.writeFileSync(dbPath, JSON.stringify(data, null, 2)); }

function verifyRobloxAccount(userId, apiKey) {
  return new Promise((resolve, reject) => {
    https.get(`https://users.roblox.com/v1/users/${userId}`, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          if (json.id && json.name) {
            https.get(`https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=${userId}&size=150x150&format=Png&isCircular=false`, (imgRes) => {
              let imgData = '';
              imgRes.on('data', chunk => imgData += chunk);
              imgRes.on('end', () => {
                let avatarUrl = 'https://tr.rbxcdn.com/30day-AvatarHeadshot/150/150/AvatarHeadshot/Png';
                try {
                  const imgJson = JSON.parse(imgData);
                  if (imgJson.data && imgJson.data[0] && imgJson.data[0].imageUrl) {
                    avatarUrl = imgJson.data[0].imageUrl;
                  }
                } catch(e) {}
                resolve({ connected: true, userId: json.id, username: json.name, displayName: json.displayName || json.name, avatarUrl });
              });
            }).on('error', () => {
              resolve({ connected: true, userId: json.id, username: json.name, displayName: json.displayName || json.name, avatarUrl: 'https://tr.rbxcdn.com/30day-AvatarHeadshot/150/150/AvatarHeadshot/Png' });
            });
          } else { reject(new Error('Invalid User ID')); }
        } catch(e) { reject(new Error('Parse error')); }
      });
    }).on('error', () => reject(new Error('Network error')));
  });
}

app.post('/api/account/connect', async (req, res) => {
  const { userId, apiKey } = req.body;
  if (!userId || !apiKey) return res.status(400).json({ success: false, error: 'User ID & API Key wajib diisi!' });
  try {
    const profile = await verifyRobloxAccount(userId.trim(), apiKey.trim());
    let db = getDB();
    db.account = { ...profile, apiKey };
    saveDB(db);
    res.json({ success: true, account: { userId: profile.userId, username: profile.username, displayName: profile.displayName, avatarUrl: profile.avatarUrl } });
  } catch (err) {
    res.status(400).json({ success: false, error: '✕ INVALID USER ID OR API KEY' });
  }
});

app.get('/api/account/status', (req, res) => {
  const db = getDB();
  if (db.account && db.account.connected) {
    res.json({ success: true, account: { userId: db.account.userId, username: db.account.username, displayName: db.account.displayName, avatarUrl: db.account.avatarUrl } });
  } else {
    res.json({ success: false, account: null });
  }
});

app.post('/api/account/disconnect', (req, res) => {
  let db = getDB();
  db.account = null;
  saveDB(db);
  res.json({ success: true });
});

const multer = require('multer');
const upload = multer({ dest: 'uploads/', limits: { fileSize: 50 * 1024 * 1024 } });
const audioProcessor = require('./services/audioProcessor');

let pendingJobs = [];
const activeJobs = new Map();

function resolveInputFilePath(fetchedUrl) {
  if (!fetchedUrl) return null;
  let filename = fetchedUrl;
  if (fetchedUrl.startsWith('http://') || fetchedUrl.startsWith('https://')) {
    try {
      const parsed = new URL(fetchedUrl);
      filename = parsed.pathname;
    } catch(e) {}
  }
  filename = filename.replace('/uploads/', '').replace(/^\/+/, '');
  const resolved = path.join(uploadsDir, path.basename(filename));
  if (fs.existsSync(resolved)) return resolved;
  return null;
}

app.post('/api/audio/process', upload.single('audio'), async (req, res) => {
  try {
    let inputFilePath = '';
    const { fetchedUrl, speed, pitch, volume } = req.body;

    if (req.file) {
      inputFilePath = req.file.path;
    } else if (fetchedUrl) {
      inputFilePath = resolveInputFilePath(fetchedUrl);
    }

    if (!inputFilePath || !fs.existsSync(inputFilePath)) {
      return res.status(400).json({ success: false, error: 'Audio source tidak ditemukan di server. Silahkan fetch ulang!' });
    }

    const outputPath = path.join(uploadsDir, `processed-${Date.now()}.mp3`);
    await audioProcessor.processAudio(inputFilePath, outputPath, { speed, pitch, volume });
    
    if (!fs.existsSync(outputPath) || fs.statSync(outputPath).size === 0) {
      return res.status(500).json({ success: false, error: 'Output audio gagal dibuat atau kosong' });
    }

    res.json({ 
      success: true, 
      audioUrl: `/uploads/${path.basename(outputPath)}`,
      format: 'mp3',
      mimeType: 'audio/mpeg'
    });
  } catch (err) { 
    res.status(500).json({ success: false, error: err.message }); 
  }
});

// Endpoint Antrean Worker Redfinger
app.get('/api/fetch-worker/claim', (req, res) => {
  if (pendingJobs.length === 0) return res.json({ job: null });
  res.json({ job: pendingJobs.shift() });
});

app.post('/api/audio/fetch', async (req, res) => {
  const { url } = req.body;
  if (!url) return res.status(400).json({ success: false, error: 'URL required' });

  const jobId = Date.now().toString();
  const jobToken = Math.random().toString(36).substring(2);
  pendingJobs.push({ id: jobId, token: jobToken, url, status: 'pending' });

  const timeout = 300000;
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
      return res.status(504).json({ success: false, error: 'Worker timeout.' });
    }
  }, 500);
});

const uploadWorker = multer({ dest: 'uploads/', limits: { fileSize: 50 * 1024 * 1024 } });
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
          duration: 113,
          sourcePlatform: 'YouTube/TikTok',
          audioUrl: audioUrl,
          format: 'mp3',
          mimeType: 'audio/mpeg'
        }
      });
    }
    res.json({ success: true });
  } catch (err) { res.status(500).json({ success: false, error: err.message }); }
});

app.post('/api/roblox/upload', async (req, res) => {
  const { title, audioUrl } = req.body;
  const db = getDB();
  
  if (!db.account || !db.account.apiKey) {
    return res.status(401).json({ success: false, error: 'Akun Roblox belum terkoneksi atau API Key tidak ditemukan.' });
  }

  const resolvedAudioPath = resolveInputFilePath(audioUrl);
  if (!resolvedAudioPath || !fs.existsSync(resolvedAudioPath)) {
    return res.status(400).json({ success: false, error: 'File audio untuk diupload tidak ditemukan.' });
  }

  try {
    const fileBuffer = fs.readFileSync(resolvedAudioPath);
    const boundary = '----RobloxOpenCloudBoundary' + Math.random().toString(36).substring(2);
    
    const requestMetadata = JSON.stringify({
      assetType: 'Audio',
      displayName: title || 'MCHLERN Audio Track',
      description: 'Uploaded via MCHLERN Engineering Bypass Engine',
      creationContext: {
        creator: { userId: db.account.userId.toString() }
      }
    });

    let postData = Buffer.concat([
      Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name=\"request\";\r\nContent-Type: application/json\r\n\r\n${requestMetadata}\r\n`),
      Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.mp3\"\r\nContent-Type: audio/mpeg\r\n\r\n`),
      fileBuffer,
      Buffer.from(`\r\n--${boundary}--\r\n`)
    ]);

    const options = {
      hostname: 'apis.roblox.com',
      path: '/assets/v1/assets',
      method: 'POST',
      headers: {
        'x-api-key': db.account.apiKey,
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
        'Content-Length': postData.length
      }
    };

    const robloxReq = https.request(options, (robloxRes) => {
      let responseBody = '';
      robloxRes.on('data', chunk => responseBody += chunk);
      robloxRes.on('end', () => {
        try {
          const jsonResp = JSON.parse(responseBody);
          if (robloxRes.statusCode >= 200 && robloxRes.statusCode < 300) {
            const operationId = jsonResp.operationId || jsonResp.path || 'Completed';
            res.json({ success: true, assetId: operationId, message: 'Upload berhasil dikirim ke Roblox Open Cloud' });
          } else {
            res.status(400).json({ success: false, error: jsonResp.message || 'Gagal upload ke Roblox Open Cloud API' });
          }
        } catch(e) {
          res.status(500).json({ success: false, error: 'Gagal memparsing response dari Roblox' });
        }
      });
    });

    robloxReq.on('error', (err) => {
      res.status(500).json({ success: false, error: 'Koneksi ke Roblox API gagal: ' + err.message });
    });

    robloxReq.write(postData);
    robloxReq.end();

  } catch (err) {
    res.status(500).json({ success: false, error: 'Error internal saat mengupload: ' + err.message });
  }
});

app.listen(PORT, () => console.log(`Running on port ${PORT}`));
