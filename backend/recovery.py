from datetime import datetime, timedelta
from .models import SessionLocal, Download, DownloadStatus
from .queue import download_queue
from .tasks import process_download
from .settings import Settings
from .queue import redis_conn
from rq import Retry
from pathlib import Path

_settings = Settings()
DOWNLOADS_DIR = Path(_settings.downloads_dir)


def recover_unfinished_downloads() -> None:
    with SessionLocal() as db:
        stuck = db.query(Download).filter(
            Download.status.in_([
                DownloadStatus.PENDING,
                DownloadStatus.QUEUED,
                DownloadStatus.PROCESSING,
                DownloadStatus.FAILED,
            ])
        ).all()

        for download in stuck:
            if download.status == DownloadStatus.PROCESSING:
                download.status = DownloadStatus.QUEUED
            if download.status == DownloadStatus.FAILED and download.retry_count >= _settings.max_retries:
                continue
            if download.status == DownloadStatus.CANCELLED:
                continue
            download_queue_job_id = f"download:{download.id}"
            existing_job = download_queue.fetch_job(download_queue_job_id)
            if existing_job is None:
                download_queue.enqueue(
                    process_download,
                    download.id,
                    job_id=download_queue_job_id,
                    retry=Retry(max=_settings.max_retries, interval=list(_settings.retry_intervals)),
                )
            download.status = DownloadStatus.QUEUED
            db.add(download)
        db.commit()


def cleanup_orphan_temp_files() -> None:
    threshold = datetime.utcnow() - timedelta(hours=4)
    for path in DOWNLOADS_DIR.glob("*.part.mp3"):
        try:
            if datetime.utcfromtimestamp(path.stat().st_mtime) < threshold:
                path.unlink()
        except Exception:
            pass
    for path in DOWNLOADS_DIR.glob("*.tmp"):
        try:
            if datetime.utcfromtimestamp(path.stat().st_mtime) < threshold:
                path.unlink()
        except Exception:
            pass
