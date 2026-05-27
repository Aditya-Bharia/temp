# ============================================================================
# 3. main.py - FIXED WITH SECURITY AND VALIDATION
# ============================================================================

from fastapi import FastAPI, WebSocket, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field, validator
from contextlib import asynccontextmanager
import asyncio
from datetime import datetime
from urllib.parse import urlparse
import logging

from models import init_db, get_db, Download, Playlist, DownloadStatus
from scrapers import extract_apple_music_songs, parse_playlist_url
from downloader import manager_instance
from ws_manager import manager
from config import DOWNLOADS_DIR, ALLOWED_ORIGINS, get_environment, MAX_URL_LENGTH, MAX_SONG_NAME_LENGTH
from typing import List

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ============================================================================
# INPUT VALIDATION MODELS
# ============================================================================

class PlaylistRequest(BaseModel):
    """Validated playlist extraction request"""
    url: str = Field(..., max_length=MAX_URL_LENGTH, min_length=10)

    @validator('url')
    def validate_url(cls, v):
        """Validate URL format and scheme"""
        if not v.startswith(('http://', 'https://')):
            raise ValueError("URL must start with http:// or https://")

        try:
            parsed = urlparse(v)
            if not parsed.netloc:
                raise ValueError("Invalid URL format")

            # Whitelist allowed domains
            allowed_domains = ['music.apple.com', 'open.spotify.com', 'youtube.com', 'youtu.be']
            if not any(parsed.netloc.endswith(domain) for domain in allowed_domains):
                raise ValueError("URL must be from a supported provider")

            return v
        except Exception as e:
            raise ValueError(f"Invalid URL: {str(e)}")

class DownloadRequest(BaseModel):
    """Validated download request"""
    download_id: int = Field(..., gt=0)

class QueueDownloadsRequest(BaseModel):
    """Validated queue downloads request"""
    playlist_id: int = Field(..., gt=0)
    songs: List[str] = Field(..., min_items=1, max_items=100)

    @validator('songs')
    def validate_songs(cls, v):
        """Validate song list"""
        validated = []
        for song in v:
            if not song or len(song) > MAX_SONG_NAME_LENGTH:
                continue
            # Remove null bytes and control characters
            clean = song.replace('\x00', '')
            clean = ''.join(c for c in clean if ord(c) >= 32 or c in '\n\t')
            if clean.strip():
                validated.append(clean.strip())

        if not validated:
            raise ValueError("No valid songs provided")

        return validated

# ============================================================================
# SECURITY MIDDLEWARE
# ============================================================================

def setup_security_headers(app: FastAPI):
    """Add security headers to all responses"""
    @app.middleware("http")
    async def add_security_headers(request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["Content-Security-Policy"] = "default-src 'self'"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        return response

# ============================================================================
# APP INITIALIZATION
# ============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage app startup and shutdown"""
    # Startup
    logger.info("Starting application")
    DOWNLOADS_DIR.mkdir(exist_ok=True)
    init_db()
    yield

    # Shutdown
    logger.info("Shutting down application")
    await manager_instance.shutdown()

app = FastAPI(title="Music Downloader API", version="1.0.0", lifespan=lifespan)

# Setup CORS - SECURE
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
    max_age=3600,
)

# Add security headers
setup_security_headers(app)

# ============================================================================
# RATE LIMITING SETUP
# ============================================================================

from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request, exc):
    from fastapi.responses import JSONResponse
    return JSONResponse(
        status_code=429,
        content={"detail": "Rate limit exceeded"}
    )

# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.post("/api/extract-playlist")
@limiter.limit("5/minute")
async def extract_playlist(request: PlaylistRequest, db: Session = Depends(get_db)):
    """Extract songs from playlist"""
    try:
        logger.info(f"Extracting playlist: {request.url}")
        songs = await extract_apple_music_songs(request.url)

        if not songs:
            raise HTTPException(status_code=400, detail="Could not extract songs from URL")

        # Validate and sanitize songs
        validated_songs = []
        for song in songs[:100]:  # Limit to 100
            if not song or len(song) > MAX_SONG_NAME_LENGTH:
                continue
            clean = song.replace('\x00', '')
            clean = ''.join(c for c in clean if ord(c) >= 32)
            if clean.strip():
                validated_songs.append(clean.strip())

        if not validated_songs:
            raise HTTPException(status_code=400, detail="No valid songs extracted")

        # Store playlist
        parsed = parse_playlist_url(request.url)
        playlist = Playlist(
            url=request.url,
            name=f"Playlist ({len(validated_songs)} songs)",
            total_songs=len(validated_songs)
        )
        db.add(playlist)
        db.commit()

        logger.info(f"Extracted {len(validated_songs)} songs from playlist {playlist.id}")

        return {
            "playlist_id": playlist.id,
            "songs": validated_songs,
            "total": len(validated_songs)
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Playlist extraction error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to extract playlist")

@app.post("/api/queue-downloads")
@limiter.limit("10/minute")
async def queue_downloads(
    request: QueueDownloadsRequest,
    db: Session = Depends(get_db)
):
    """Queue songs for download"""
    try:
        playlist = db.query(Playlist).filter(Playlist.id == request.playlist_id).first()
        if not playlist:
            raise HTTPException(status_code=404, detail="Playlist not found")

        downloads = []
        for song_name in request.songs:
            # Check if already downloaded
            existing = db.query(Download).filter(
                Download.song_name == song_name,
                Download.status == DownloadStatus.COMPLETED
            ).first()

            if existing:
                logger.debug(f"Song already downloaded: {song_name}")
                continue

            download = Download(
                song_name=song_name,
                status=DownloadStatus.PENDING,
                playlist_id=request.playlist_id
            )
            db.add(download)
            db.commit()
            downloads.append({"id": download.id, "song": song_name})

        logger.info(f"Queued {len(downloads)} downloads for playlist {request.playlist_id}")

        return {"queued": len(downloads), "downloads": downloads}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Queue downloads error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to queue downloads")

@app.post("/api/start-download/{download_id}")
@limiter.limit("20/minute")
async def start_download(download_id: int, db: Session = Depends(get_db)):
    """Start downloading a song"""
    try:
        download = db.query(Download).filter(Download.id == download_id).first()
        if not download:
            raise HTTPException(status_code=404, detail="Download not found")

        if download.status not in [DownloadStatus.PENDING, DownloadStatus.PAUSED]:
            raise HTTPException(status_code=400, detail="Download already in progress or completed")

        download.status = DownloadStatus.DOWNLOADING
        download.paused = False
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
            logger.warning(f"No download source found for {download.song_name}")
            raise HTTPException(status_code=400, detail="Song not found on any provider")

        download.provider = result.get('provider', 'unknown')
        download.download_url = result['download_url']
        db.commit()

        logger.info(f"Starting download: {download.song_name} from {download.provider}")

        # Start download task
        task = asyncio.create_task(
            manager_instance.download_file(download_id, result['download_url'])
        )

        return {"status": "downloading", "download_id": download_id}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Start download error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to start download")

@app.post("/api/pause/{download_id}")
@limiter.limit("30/minute")
async def pause_download(download_id: int, db: Session = Depends(get_db)):
    """Pause a download"""
    try:
        await manager_instance.pause_download(download_id)
        logger.info(f"Paused download {download_id}")
        return {"status": "paused"}
    except Exception as e:
        logger.error(f"Pause error: {e}")
        raise HTTPException(status_code=500, detail="Failed to pause download")

@app.post("/api/resume/{download_id}")
@limiter.limit("30/minute")
async def resume_download(download_id: int, db: Session = Depends(get_db)):
    """Resume a paused download"""
    try:
        await manager_instance.resume_download(download_id)
        logger.info(f"Resumed download {download_id}")
        return {"status": "resumed"}
    except Exception as e:
        logger.error(f"Resume error: {e}")
        raise HTTPException(status_code=500, detail="Failed to resume download")

@app.get("/api/downloads")
async def get_downloads(db: Session = Depends(get_db)):
    """Get all downloads"""
    try:
        downloads = db.query(Download).order_by(Download.created_at.desc()).limit(1000).all()
        return [
            {
                "id": d.id,
                "song": d.song_name,
                "artist": d.artist,
                "status": d.status.value,
                "provider": d.provider,
                "progress": int((d.downloaded_size / d.file_size * 100) if d.file_size > 0 else 0),
                "speed": round(d.speed_mbps, 2),
                "eta": int(d.eta_seconds),
                "error": d.error_message
            }
            for d in downloads
        ]
    except Exception as e:
        logger.error(f"Get downloads error: {e}")
        raise HTTPException(status_code=500, detail="Failed to get downloads")

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket connection for real-time updates"""
    await manager.connect(websocket)
    try:
        while True:
            # Keep connection alive
            await websocket.receive_text()
    except Exception as e:
        logger.debug(f"WebSocket error: {e}")
    finally:
        manager.disconnect(websocket)
        logger.debug("WebSocket disconnected")

@app.get("/api/health")
async def health():
    """Health check endpoint"""
    return {"status": "ok", "environment": get_environment()}

@app.get("/")
async def root():
    """API root"""
    return {"message": "Music Downloader API", "version": "1.0.0"}
