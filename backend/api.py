from fastapi import APIRouter, Depends, HTTPException, Request, WebSocket
from pydantic import BaseModel
from typing import List
from .models import get_db, Download, Playlist, DownloadStatus
from sqlalchemy.orm import Session
from .scrapers import extract_apple_music_songs, parse_playlist_url
from .ws_manager import manager as ws_manager
from .settings import Settings
from .queue import download_queue
from .tasks import process_download
from rq import Retry
from .utils import sanitize_filename
from pathlib import Path

router = APIRouter()
_settings = Settings()

class PlaylistRequest(BaseModel):
    url: str

class DownloadRequest(BaseModel):
    download_id: int


@router.post("/extract-playlist")
async def extract_playlist(request: PlaylistRequest, db: Session = Depends(get_db)):
    try:
        songs = await extract_apple_music_songs(request.url)
        if not songs:
            raise HTTPException(status_code=400, detail="Could not extract songs from URL")

        playlist = Playlist(
            url=request.url,
            name=f"Playlist ({len(songs)} songs)",
            total_songs=len(songs)
        )
        db.add(playlist)
        db.commit()
        db.refresh(playlist)

        return {"playlist_id": playlist.id, "songs": songs[:100], "total": len(songs)}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


class QueueDownloadsRequest(BaseModel):
    playlist_id: int
    songs: List[str]


@router.post("/queue-downloads")
async def queue_downloads(request: QueueDownloadsRequest, db: Session = Depends(get_db)):
    try:
        playlist = db.query(Playlist).filter(Playlist.id == request.playlist_id).first()
        if not playlist:
            raise HTTPException(status_code=404, detail="Playlist not found")

        downloads = []
        for song_name in request.songs:
            existing = db.query(Download).filter(
                Download.song_name == song_name,
                Download.status == DownloadStatus.COMPLETED
            ).first()

            if existing:
                continue

            download = Download(
                song_name=song_name,
                status=DownloadStatus.PENDING,
                playlist_id=request.playlist_id
            )
            db.add(download)
            db.commit()
            db.refresh(download)
            downloads.append({"id": download.id, "song": song_name})

        return {"queued": len(downloads), "downloads": downloads}

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/start-download/{download_id}")
async def start_download(download_id: int, db: Session = Depends(get_db)):
    try:
        download = db.query(Download).filter(Download.id == download_id).first()
        if not download:
            raise HTTPException(status_code=404, detail="Download not found")

        if download.status in [DownloadStatus.COMPLETED, DownloadStatus.PROCESSING, DownloadStatus.QUEUED]:
            raise HTTPException(status_code=400, detail="Download already in progress or completed")

        download.status = DownloadStatus.QUEUED
        db.commit()

        job_id = f"download:{download.id}"
        if download_queue.fetch_job(job_id) is None:
            download_queue.enqueue(
                process_download,
                download.id,
                job_id=job_id,
                retry=Retry(max=_settings.max_retries, interval=list(_settings.retry_intervals)),
            )

        return {"status": "queued", "download_id": download_id}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/cancel-download/{download_id}")
async def cancel_download(download_id: int, db: Session = Depends(get_db)):
    download = db.query(Download).filter(Download.id == download_id).first()
    if not download:
        raise HTTPException(status_code=404, detail="Download not found")

    download.status = DownloadStatus.CANCELLED
    db.commit()
    return {"status": "cancelled", "download_id": download_id}


@router.post("/retry-download/{download_id}")
async def retry_download(download_id: int, db: Session = Depends(get_db)):
    download = db.query(Download).filter(Download.id == download_id).first()
    if not download:
        raise HTTPException(status_code=404, detail="Download not found")

    download.status = DownloadStatus.QUEUED
    download.error_message = ""
    db.commit()

    job_id = f"download:{download.id}"
    if download_queue.fetch_job(job_id) is None:
        download_queue.enqueue(
            process_download,
            download.id,
            job_id=job_id,
            retry=Retry(max=_settings.max_retries, interval=list(_settings.retry_intervals)),
        )

    return {"status": "queued", "download_id": download_id}


@router.get("/downloads")
async def get_downloads(db: Session = Depends(get_db)):
    downloads = db.query(Download).order_by(Download.created_at.desc()).all()
    return [
        {
            "id": d.id,
            "song": d.song_name,
            "artist": d.artist,
            "status": d.status.value,
            "provider": d.provider,
            "progress": d.progress,
            "error": d.error_message,
            "final_path": d.final_path,
            "temp_path": d.temp_path,
            "retry_count": d.retry_count,
            "started_at": d.started_at,
            "completed_at": d.completed_at,
            "created_at": d.created_at,
            "updated_at": d.updated_at,
        }
        for d in downloads
    ]


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await ws_manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except Exception:
        ws_manager.disconnect(websocket)


@router.get("/settings")
async def get_settings():
    return {
        "audio_quality": "high",
        "providers": ["youtube", "soundcloud", "jamendo", "audius"],
        "auto_retry": True,
        "max_retries": _settings.max_retries,
        "concurrent_downloads": 1,
        "output_format": "mp3",
        "bit_rate": "320k"
    }


@router.post("/settings")
async def update_settings(settings: dict):
    return {"status": "saved", "settings": settings}


class BatchOperationRequest(BaseModel):
    operation: str  # 'retry' or 'cancel'
    download_ids: List[int]


@router.post("/batch-operation")
async def batch_operation(request: BatchOperationRequest, db: Session = Depends(get_db)):
    try:
        results = []
        for download_id in request.download_ids:
            download = db.query(Download).filter(Download.id == download_id).first()
            if not download:
                continue

            if request.operation == 'retry':
                download.status = DownloadStatus.QUEUED
                download.error_message = ""
                job_id = f"download:{download.id}"
                if download_queue.fetch_job(job_id) is None:
                    download_queue.enqueue(
                        process_download,
                        download.id,
                        job_id=job_id,
                        retry=Retry(max=_settings.max_retries, interval=list(_settings.retry_intervals)),
                    )
                results.append({"id": download_id, "status": "queued"})
            elif request.operation == 'cancel':
                download.status = DownloadStatus.CANCELLED
                results.append({"id": download_id, "status": "cancelled"})

            db.commit()

        return {"operation": request.operation, "results": results}

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/recovery/failed")
async def get_failed_downloads(db: Session = Depends(get_db)):
    failed = db.query(Download).filter(Download.status == DownloadStatus.FAILED).all()
    return [
        {
            "id": d.id,
            "song": d.song_name,
            "error": d.error_message,
            "retry_count": d.retry_count,
            "created_at": d.created_at.isoformat() if d.created_at else None
        }
        for d in failed
    ]


@router.post("/recovery/retry-failed")
async def retry_failed_downloads(db: Session = Depends(get_db)):
    failed = db.query(Download).filter(Download.status == DownloadStatus.FAILED).all()
    retried = 0

    for download in failed:
        if download.retry_count < _settings.max_retries:
            download.status = DownloadStatus.QUEUED
            download.error_message = ""
            job_id = f"download:{download.id}"
            if download_queue.fetch_job(job_id) is None:
                download_queue.enqueue(
                    process_download,
                    download.id,
                    job_id=job_id,
                    retry=Retry(max=_settings.max_retries, interval=list(_settings.retry_intervals)),
                )
            db.commit()
            retried += 1

    return {"retried": retried}

    total = db.query(Download).count()
    queued = db.query(Download).filter(Download.status == DownloadStatus.QUEUED).count()
    processing = db.query(Download).filter(Download.status == DownloadStatus.PROCESSING).count()
    completed = db.query(Download).filter(Download.status == DownloadStatus.COMPLETED).count()
    failed = db.query(Download).filter(Download.status == DownloadStatus.FAILED).count()

    return {
        "total": total,
        "queued": queued,
        "processing": processing,
        "completed": completed,
        "failed": failed,
        "active": queued + processing
    }


@router.get("/stats")
async def get_stats(db: Session = Depends(get_db)):
    total = db.query(Download).count()
    completed = db.query(Download).filter(Download.status == DownloadStatus.COMPLETED).count()
    failed = db.query(Download).filter(Download.status == DownloadStatus.FAILED).count()
    processing = db.query(Download).filter(Download.status == DownloadStatus.PROCESSING).count()
    queued = db.query(Download).filter(Download.status == DownloadStatus.QUEUED).count()

    total_playlists = db.query(Playlist).count()

    # Calculate download times
    completed_downloads = db.query(Download).filter(
        Download.status == DownloadStatus.COMPLETED,
        Download.completed_at.isnot(None),
        Download.started_at.isnot(None)
    ).all()

    avg_download_time = None
    if completed_downloads:
        times = [
            (d.completed_at - d.started_at).total_seconds()
            for d in completed_downloads
        ]
        avg_download_time = sum(times) / len(times)

    return {
        "downloads": {
            "total": total,
            "completed": completed,
            "failed": failed,
            "processing": processing,
            "queued": queued,
            "success_rate": (completed / total * 100) if total > 0 else 0,
            "avg_download_time_seconds": avg_download_time
        },
        "playlists": {
            "total": total_playlists
        },
        "queue": {
            "active": processing + queued
        }
    }


@router.get("/providers")
async def get_providers():
    return {
        "available": ["youtube", "soundcloud", "jamendo", "audius"],
        "default": "youtube",
        "status": "all_operational"
    }

