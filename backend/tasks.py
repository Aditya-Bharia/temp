import json
import os
import signal
import subprocess
import time
from datetime import datetime
from pathlib import Path
from .settings import Settings
from .models import SessionLocal, Download, DownloadStatus
from .queue import redis_conn
from .utils import sanitize_filename
from . import models

_settings = Settings()
DOWNLOADS_DIR = Path(_settings.downloads_dir)
EVENT_CHANNEL = "download_events"


def publish_event(event: dict) -> None:
    try:
        redis_conn.publish(EVENT_CHANNEL, json.dumps(event))
    except Exception:
        pass


def _terminate_process(proc: subprocess.Popen) -> None:
    try:
        if os.name == "nt":
            proc.send_signal(signal.CTRL_BREAK_EVENT)
        else:
            os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass


def _get_job_output_path(base_name: str) -> Path:
    return DOWNLOADS_DIR / f"{base_name}.mp3"


def _find_downloaded_file(base_name: str) -> Path | None:
    candidate = _get_job_output_path(base_name)
    if candidate.exists():
        return candidate
    matches = list(DOWNLOADS_DIR.glob(f"{base_name}.*"))
    return matches[0] if matches else None


def _is_cancelled(download_id: int) -> bool:
    db = SessionLocal()
    try:
        download = db.query(Download).filter(Download.id == download_id).first()
        return download is not None and download.status == DownloadStatus.CANCELLED
    finally:
        db.close()


def _update_download(download: Download, db, **fields) -> None:
    for key, value in fields.items():
        if hasattr(download, key):
            setattr(download, key, value)
    download.updated_at = datetime.utcnow()
    db.add(download)
    db.commit()
    db.refresh(download)


def process_download(download_id: int) -> None:
    db = SessionLocal()
    try:
        download = db.query(Download).filter(Download.id == download_id).first()
        if download is None:
            return

        if download.status == DownloadStatus.COMPLETED:
            publish_event({"type": "download_status", "download_id": download_id, "status": download.status.value})
            return

        if download.status == DownloadStatus.CANCELLED:
            return

        download.status = DownloadStatus.PROCESSING
        download.retry_count += 1
        download.started_at = datetime.utcnow()
        download.progress = 0
        base_name = sanitize_filename(f"{download.id}_{download.song_name}")
        final_path = _get_job_output_path(base_name)
        download.final_path = str(final_path)
        download.temp_path = str(DOWNLOADS_DIR / f"{base_name}.part.mp3")
        _update_download(download, db)

        publish_event({
            "type": "download_status",
            "download_id": download_id,
            "status": download.status.value,
            "song": download.song_name,
            "provider": download.provider,
        })

        output_template = str(DOWNLOADS_DIR / f"{base_name}.%(ext)s")
        command = [
            "yt-dlp",
            "--quiet",
            "--no-warnings",
            "--extract-audio",
            "--audio-format",
            "mp3",
            "--no-playlist",
            "--socket-timeout",
            str(_settings.download_timeout),
            "--output",
            output_template,
            f"ytsearch1:{download.song_name}",
        ]

        if os.name == "nt":
            creationflags = subprocess.CREATE_NEW_PROCESS_GROUP
            proc = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                creationflags=creationflags,
                text=True,
            )
        else:
            proc = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                preexec_fn=os.setsid,
                text=True,
            )

        start_time = time.time()
        while proc.poll() is None:
            if _is_cancelled(download_id):
                _terminate_process(proc)
                raise RuntimeError("Download cancelled")
            if time.time() - start_time > _settings.download_timeout:
                _terminate_process(proc)
                raise RuntimeError("Download timed out")
            time.sleep(1)

        stdout, stderr = proc.communicate(timeout=5)
        if proc.returncode != 0:
            raise RuntimeError(stderr.strip() or "yt-dlp failed")

        downloaded_file = _find_downloaded_file(base_name)
        if downloaded_file is None:
            raise RuntimeError("Download succeeded but output file was not found")

        if str(downloaded_file.resolve()) != str(final_path.resolve()):
            downloaded_file.rename(final_path)

        download.status = DownloadStatus.COMPLETED
        download.progress = 100
        download.completed_at = datetime.utcnow()
        download.error_message = ""
        download.final_path = str(final_path)
        _update_download(download, db)

        publish_event({
            "type": "download_complete",
            "download_id": download_id,
            "file_path": download.final_path,
        })
    except Exception as exc:
        if download is not None:
            download.status = DownloadStatus.FAILED
            download.error_message = str(exc)
            _update_download(download, db)
        publish_event({
            "type": "download_failed",
            "download_id": download_id,
            "error": str(exc),
        })
    finally:
        db.close()
