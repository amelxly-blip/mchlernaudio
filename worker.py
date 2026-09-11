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
    parser.add_argument("--server", default=os.getenv("MCHLERN_SERVER", ""))
    parser.add_argument("--token", default=os.getenv("FETCH_WORKER_TOKEN", ""))
    parser.add_argument("--cookies", default=os.getenv("YOUTUBE_COOKIES", ""))
    parser.add_argument("--interval", type=int, default=5)
    return parser.parse_args()


def require_config(args):
    server = args.server.strip().rstrip("/")
    if not server:
        raise SystemExit("Server wajib diisi, contoh: https://nama-project.up.railway.app")
    if not server.lower().startswith(("http://", "https://")):
        server = "https://" + server
    if not args.token.strip():
        raise SystemExit("Token wajib diisi.")
    return server, args.token.strip()


def download_job(job, cookies_path, temp_dir):
    output_template = str(temp_dir / "audio.%(ext)s")
    options = {
        "quiet": True,
        "no_warnings": True,
        "format": "bestaudio/best",
        "outtmpl": output_template,
        "ffmpeg_location": imageio_ffmpeg.get_ffmpeg_exe(),
        "postprocessors": [{
            "key": "FFmpegExtractAudio",
            "preferredcodec": "mp3",
        }],
        "extractor_args": {
            "youtube": {"player_client": ["android", "web"]},
        },
        "noplaylist": True,
    }
    if cookies_path:
        cookie_file = Path(cookies_path).expanduser()
        if not cookie_file.is_file():
            raise FileNotFoundError(f"Cookies tidak ditemukan: {cookie_file}")
        options["cookiefile"] = str(cookie_file)

    with yt_dlp.YoutubeDL(options) as downloader:
        info = downloader.extract_info(job["url"], download=True)
        if not info:
            raise RuntimeError("yt-dlp tidak mengembalikan data video.")
        title = info.get("title") or "YouTube Audio"
        thumbnail = info.get("thumbnail") or ""

    output = temp_dir / "audio.mp3"
    if not output.is_file():
        raise FileNotFoundError("File audio hasil download tidak ditemukan.")
    return output, title, thumbnail


def complete_job(session, server, token, job, audio, title, thumbnail):
    with audio.open("rb") as stream:
        response = session.post(
            f"{server}/api/fetch-worker/complete",
            headers={"X-Worker-Token": token},
            data={
                "job_id": job["id"],
                "job_token": job["token"],
                "title": title[:200],
                "thumbnail": thumbnail[:2048],
            },
            files={"file": ("audio.mp3", stream, "audio/mpeg")},
            timeout=120,
        )
    response.raise_for_status()


def fail_job(session, server, token, job, error):
    try:
        response = session.post(
            f"{server}/api/fetch-worker/complete",
            headers={"X-Worker-Token": token},
            data={
                "job_id": job["id"],
                "job_token": job["token"],
                "error": str(error)[:500],
            },
            timeout=30,
        )
        response.raise_for_status()
    except requests.RequestException as report_error:
        print(f"Gagal melaporkan job: {report_error}")


def main():
    args = parse_args()
    server, token = require_config(args)
    session = requests.Session()
    print(f"Worker desktop aktif: {server}")

    while True:
        try:
            response = session.post(
                f"{server}/api/fetch-worker/claim",
                headers={"X-Worker-Token": token},
                timeout=30,
            )
            response.raise_for_status()
            job = response.json().get("job")
            if not job:
                time.sleep(max(args.interval, 1))
                continue

            print(f"Memproses job {job['id']}...")
            with tempfile.TemporaryDirectory(prefix="mchlern-worker-") as folder:
                try:
                    audio, title, thumbnail = download_job(
                        job,
                        args.cookies.strip(),
                        Path(folder),
                    )
                    complete_job(session, server, token, job, audio, title, thumbnail)
                    print("Job selesai; file lokal dihapus.")
                except Exception as error:
                    print(f"Job gagal: {error}")
                    fail_job(session, server, token, job, error)
        except requests.RequestException as error:
            print(f"Worker retry: {error}")
            time.sleep(10)
        except KeyboardInterrupt:
            print("\nWorker dihentikan.")
            return


if __name__ == "__main__":
    main()
