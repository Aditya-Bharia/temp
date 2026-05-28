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


@router.post("/queue-downloads")
async def queue_downloads(playlist_id: int, songs: List[str], db: Session = Depends(get_db)):
    try:
        playlist = db.query(Playlist).filter(Playlist.id == playlist_id).first()
        if not playlist:
            raise HTTPException(status_code=404, detail="Playlist not found")

        downloads = []
        for song_name in songs:
            existing = db.query(Download).filter(
                Download.song_name == song_name,
                Download.status == DownloadStatus.COMPLETED
            ).first()

            if existing:
                continue

            download = Download(
                song_name=song_name,
                status=DownloadStatus.PENDING,
                playlist_id=playlist_id
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


@router.get("/health")
async def health():
    return {"status": "ok"}
