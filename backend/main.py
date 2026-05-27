from fastapi import FastAPI, WebSocket, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from pydantic import BaseModel
import asyncio
from datetime import datetime
from models import init_db, get_db, Download, Playlist, DownloadStatus
from scrapers import extract_apple_music_songs, parse_playlist_url
from downloader import manager_instance
from ws_manager import manager
from config import DOWNLOADS_DIR
import os

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class PlaylistRequest(BaseModel):
    url: str

class DownloadRequest(BaseModel):
    download_id: int

init_db()

@app.on_event("startup")
async def startup():
    DOWNLOADS_DIR.mkdir(exist_ok=True)

@app.post("/api/extract-playlist")
async def extract_playlist(request: PlaylistRequest, db: Session = Depends(get_db)):
    """Extract songs from Apple Music playlist"""
    try:
        songs = await extract_apple_music_songs(request.url)

        if not songs:
            raise HTTPException(status_code=400, detail="Could not extract songs from URL")

        # Store playlist
        parsed = parse_playlist_url(request.url)
        playlist = Playlist(
            url=request.url,
            name=f"Playlist ({len(songs)} songs)",
            total_songs=len(songs)
        )
        db.add(playlist)
        db.commit()

        return {
            "playlist_id": playlist.id,
            "songs": songs[:100],
            "total": len(songs)
        }

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

from typing import List

@app.post("/api/queue-downloads")
async def queue_downloads(
    playlist_id: int,
    songs: List[str],
    db: Session = Depends(get_db)
):
    """Queue songs for download"""
    try:
        playlist = db.query(Playlist).filter(Playlist.id == playlist_id).first()
        if not playlist:
            raise HTTPException(status_code=404, detail="Playlist not found")

        downloads = []
        for song_name in songs:
            # Check if already downloaded
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
            downloads.append({"id": download.id, "song": song_name})

        return {"queued": len(downloads), "downloads": downloads}

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/start-download/{download_id}")
async def start_download(download_id: int, db: Session = Depends(get_db)):
    """Start downloading a song"""
    try:
        download = db.query(Download).filter(Download.id == download_id).first()
        if not download:
            raise HTTPException(status_code=404, detail="Download not found")

        download.status = DownloadStatus.DOWNLOADING
        db.commit()

        await manager.send_stats(
            total=1,
            completed=0,
            failed=0,
            current_song=download.song_name
        )

        # Search for song
        result = await manager_instance.search_providers(download.song_name)
        if not result or not result.get('download_url'):
            download.status = DownloadStatus.FAILED
            download.error_message = "No download source found"
            db.commit()
            raise HTTPException(status_code=400, detail="Song not found on any provider")

        download.provider = result.get('provider', 'unknown')
        db.commit()

        # Start download
        file_path = DOWNLOADS_DIR / f"{download.song_name}.mp3"
        file_path = file_path.as_posix().replace('\\', '/')

        task = asyncio.create_task(
            manager_instance.download_file(download_id, result['download_url'], file_path)
        )

        return {"status": "downloading", "download_id": download_id}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/pause/{download_id}")
async def pause_download(download_id: int):
    """Pause a download"""
    await manager_instance.pause_download(download_id)
    return {"status": "paused"}

@app.post("/api/resume/{download_id}")
async def resume_download(download_id: int):
    """Resume a paused download"""
    await manager_instance.resume_download(download_id)
    return {"status": "resumed"}

@app.get("/api/downloads")
async def get_downloads(db: Session = Depends(get_db)):
    """Get all downloads"""
    downloads = db.query(Download).order_by(Download.created_at.desc()).all()
    return [
        {
            "id": d.id,
            "song": d.song_name,
            "artist": d.artist,
            "status": d.status.value,
            "provider": d.provider,
            "progress": int((d.downloaded_size / d.file_size * 100) if d.file_size > 0 else 0),
            "speed": d.speed_mbps,
            "eta": d.eta_seconds,
            "error": d.error_message
        }
        for d in downloads
    ]

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket connection for real-time updates"""
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
    except Exception:
        manager.disconnect(websocket)

@app.get("/api/health")
async def health():
    """Health check"""
    return {"status": "ok"}


