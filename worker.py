import argparse
import os
import tempfile
import time
from pathlib import Path
import requests
import yt_dlp
import imageio_ffmpeg

def parse_args():
    parser = argparse.ArgumentParser(description="MCHLERN desktop fetch worker")
    parser.add_argument("--server", default=os.getenv("MCHLERN_SERVER", "https://mchlernaudio-production.up.railway.app"))
    parser.add_argument("--token", default=os.getenv("FETCH_WORKER_TOKEN", "rahasia_mchlern_123"))
    parser.add_argument("--cookies", default=os.getenv("YOUTUBE_COOKIES", "youtube_cookies.txt"))
    parser.add_argument("--interval", type=int, default=3)
    return parser.parse_args()

def main():
    args = parse_args()
    server = args.server.strip().rstrip("/")
    token = args.token.strip()
    session = requests.Session()
    print(f"=== WORKER MCHLERN AKTIF ===")
    print(f"Target Server: {server}")

    while True:
        try:
            response = session.post(
                f"{server}/api/fetch-worker/claim",
                headers={"X-Worker-Token": token},
                timeout=30,
            )
            if response.status_code == 401:
                print("Warning: Token 401 diterima, mencoba bypass...")
                time.sleep(3)
                continue
                
            response.raise_for_status()
            data = response.json()
            job = data.get("job")
            
            if not job:
                time.sleep(args.interval)
                continue

            print(f"\n[+] Memproses Job ID: {job['id']} | URL: {job['url']}")
            with tempfile.TemporaryDirectory(prefix="mchlern-worker-") as folder:
                temp_dir = Path(folder)
                output_template = str(temp_dir / "audio.%(ext)s")
                
                options = {
                    "quiet": True,
                    "no_warnings": True,
                    "format": "bestaudio/best",
                    "outtmpl": output_template,
                    "ffmpeg_location": imageio_ffmpeg.get_ffmpeg_exe(),
                    "postprocessors": [{"key": "FFmpegExtractAudio", "preferredcodec": "mp3"}],
                    "extractor_args": {"youtube": {"player_client": ["android", "web"]}},
                    "noplaylist": True,
                }
                
                cookie_file = Path(args.cookies).expanduser()
                if cookie_file.is_file():
                    options["cookiefile"] = str(cookie_file)
                    print(f"[*] Menggunakan file cookies: {cookie_file.name}")

                try:
                    with yt_dlp.YoutubeDL(options) as downloader:
                        info = downloader.extract_info(job["url"], download=True)
                        title = info.get("title") or "YouTube Audio"
                        thumbnail = info.get("thumbnail") or ""

                    audio_path = temp_dir / "audio.mp3"
                    if not audio_path.is_file():
                        # Cari file mp3 manual jika ekstensi berbeda
                        files = list(temp_dir.glob("*.mp3"))
                        if files: audio_path = files[0]
                        else: raise FileNotFoundError("Gagal mengekstrak file audio mp3.")

                    print(f"[+] Download selesai: {title}")
                    print(f"[*] Mengirim hasil kembali ke server...")

                    with audio_path.open("rb") as stream:
                        res_comp = session.post(
                            f"{server}/api/fetch-worker/complete",
                            headers={"X-Worker-Token": token},
                            data={"job_id": job["id"], "job_token": job["token"], "title": title[:200], "thumbnail": thumbnail[:2048]},
                            files={"file": ("audio.mp3", stream, "audio/mpeg")},
                            timeout=120,
                        )
                    res_comp.raise_for_status()
                    print("[✓] Job berhasil dikirim dan diselesaikan!\n")

                except Exception as err:
                    print(f"[x] Error pada job ini: {err}")
                    session.post(
                        f"{server}/api/fetch-worker/complete",
                        headers={"X-Worker-Token": token},
                        data={"job_id": job["id"], "job_token": job["token"], "error": str(err)[:500]},
                        timeout=30,
                    )

        except requests.RequestException as net_err:
            print(f"[!] Koneksi terputus / server starting: {net_err}")
            time.sleep(5)
        except KeyboardInterrupt:
            print("\nWorker dihentikan oleh pengguna.")
            break

if __name__ == "__main__":
    main()
