# ============================================================================
# 4. downloader.py - FIXED WITH PROPER RESOURCE MANAGEMENT
# ============================================================================

import aiohttp
import aiofiles
import asyncio
from pathlib import Path
import time
import hashlib
import re
from datetime import datetime
from contextlib import asynccontextmanager
import logging
from typing import AsyncGenerator

from config import DOWNLOADS_DIR, CHUNK_SIZE, MAX_CONCURRENT_DOWNLOADS, DOWNLOAD_TIMEOUT
from models import Download, DownloadStatus, SessionLocal
from ws_manager import manager
from providers_youtube import youtube_provider
from providers_other import search_jamendo

logger = logging.getLogger(__name__)

def sanitize_filename(filename: str, max_length: int = 200) -> str:
    """
    Sanitize filename for safe filesystem usage.
    Uses hash-based approach for maximum safety.
    Prevents:
    - Path traversal attacks
    - Windows reserved names
    - Unicode confusion attacks
    - Special character issues
    """
    if not filename:
        filename = "download"

    # Remove null bytes and control characters
    filename = filename.replace('\x00', '')
    filename = ''.join(c for c in filename if ord(c) >= 32 or c in '\n\t')

    # Keep only safe characters: alphanumeric, spaces, hyphens, underscores
    safe_filename = re.sub(r'[^\w\s.-]', '', filename[:max_length])

    if not safe_filename:
        safe_filename = 'download'

    # Windows reserved names
    reserved = ['con', 'prn', 'aux', 'nul'] + [f'com{i}' for i in range(1, 10)] + [f'lpt{i}' for i in range(1, 10)]
    if safe_filename.lower() in reserved:
        safe_filename = f'{safe_filename}_file'

    # Add hash for uniqueness and extra safety
    name_hash = hashlib.sha256(filename.encode()).hexdigest()[:8]
    base = Path(safe_filename).stem or 'download'

    return f"{base}_{name_hash}"

@asynccontextmanager
async def get_db_context() -> AsyncGenerator:
    """Context manager for database sessions"""
    db = SessionLocal()
    try:
        yield db
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"Database error: {e}", exc_info=True)
        raise
    finally:
        db.close()

class DownloadManager:
    """Manages concurrent downloads with proper resource handling"""

    def __init__(self):
        self.active_downloads = {}
        self.semaphore = asyncio.Semaphore(MAX_CONCURRENT_DOWNLOADS)
        self.paused_downloads = set()

    async def search_providers(self, song_name: str) -> dict:
        """Search all providers for song in order of reliability"""
        best_result = None

        try:
            # Try YouTube first (most reliable)
            yt_result = await youtube_provider.search(song_name)
            if yt_result:
                yt_url = await youtube_provider.get_download_url(yt_result['url'])
                if yt_url and yt_url.get('url'):
                    yt_result['download_url'] = yt_url['url']
                    logger.info(f"Found on YouTube: {song_name}")
                    return yt_result

            # Try Jamendo (secondary)
            jamendo_result = await search_jamendo(song_name)
            if jamendo_result and jamendo_result.get('url'):
                logger.info(f"Found on Jamendo: {song_name}")
                return jamendo_result

            logger.warning(f"Song not found on any provider: {song_name}")
            return None

        except Exception as e:
            logger.error(f"Provider search error for '{song_name}': {e}")
            return None

    async def download_file(self, download_id: int, url: str):
        """Download file with proper resource management and progress tracking"""
        file_path = None

        try:
            async with self.semaphore:
                if download_id not in self.active_downloads:
                    logger.debug(f"Download {download_id} not in active set")
                    return

                self.active_downloads[download_id] = True
                start_time = time.time()
                downloaded = 0
                total_size = 0

                async with aiohttp.ClientSession() as session:
                    async with session.get(
                        url,
                        timeout=aiohttp.ClientTimeout(total=DOWNLOAD_TIMEOUT),
                        headers={'User-Agent': 'Mozilla/5.0 (compatible; MusicDownloader/1.0)'},
                        allow_redirects=True
                    ) as resp:
                        if resp.status != 200:
                            raise Exception(f"HTTP {resp.status}: {resp.reason}")

                        total_size = int(resp.headers.get('content-length', 0))

                        # Get filename from Content-Disposition or use sanitized version
                        content_disposition = resp.headers.get('Content-Disposition', '')
                        if 'filename=' in content_disposition:
                            filename = content_disposition.split('filename=')[1].strip('"\'')
                        else:
                            filename = f"{sanitize_filename('download')}.mp3"

                        # Sanitize the filename
                        safe_filename = sanitize_filename(Path(filename).stem) + '.mp3'
                        file_path = DOWNLOADS_DIR / safe_filename

                        # Verify path is within downloads directory (prevent symlink escape)
                        try:
                            file_path.resolve().relative_to(DOWNLOADS_DIR.resolve())
                        except ValueError:
                            raise Exception("Path validation failed - file outside downloads directory")

                        # Create file
                        async with aiofiles.open(file_path, 'wb') as f:
                            async for chunk in resp.content.iter_chunked(CHUNK_SIZE):
                                # Check if download cancelled
                                if download_id not in self.active_downloads:
                                    logger.info(f"Download {download_id} cancelled")
                                    Path(file_path).unlink(missing_ok=True)
                                    return

                                # Check if download paused
                                if download_id in self.paused_downloads:
                                    # Don't write, but keep downloading in background
                                    continue

                                await f.write(chunk)
                                downloaded += len(chunk)

                                # Calculate progress metrics
                                elapsed = time.time() - start_time
                                if elapsed > 0:
                                    speed = (downloaded / (1024 * 1024)) / elapsed
                                    eta = (total_size - downloaded) / (speed * 1024 * 1024) if speed > 0 else 0
                                    progress = int((downloaded / total_size * 100)) if total_size > 0 else 0

                                    await manager.send_progress(
                                        download_id, "downloading",
                                        min(progress, 100),
                                        max(0, speed),
                                        max(0, eta)
                                    )

                # Update database with success
                async with get_db_context() as db:
                    download = db.query(Download).filter(Download.id == download_id).first()
                    if download:
                        download.status = DownloadStatus.COMPLETED
                        download.downloaded_size = downloaded
                        download.file_size = total_size
                        download.file_path = str(file_path)
                        download.completed_at = datetime.utcnow()

                logger.info(f"Download {download_id} completed: {file_path}")
                await manager.send_download_complete(download_id, str(file_path))

        except Exception as e:
            logger.error(f"Download {download_id} failed: {e}", exc_info=True)

            # Cleanup failed file
            if file_path:
                try:
                    Path(file_path).unlink(missing_ok=True)
                except Exception as cleanup_error:
                    logger.error(f"Failed to cleanup {file_path}: {cleanup_error}")

            # Update database with error
            try:
                async with get_db_context() as db:
                    download = db.query(Download).filter(Download.id == download_id).first()
                    if download:
                        download.status = DownloadStatus.FAILED
                        download.error_message = str(e)[:500]  # Limit error message length
            except Exception as db_error:
                logger.error(f"Failed to update DB for {download_id}: {db_error}")

            await manager.send_error(download_id, str(e))

        finally:
            self.active_downloads.pop(download_id, None)

    async def pause_download(self, download_id: int):
        """Pause a download"""
        self.paused_downloads.add(download_id)

        try:
            async with get_db_context() as db:
                download = db.query(Download).filter(Download.id == download_id).first()
                if download and download.status == DownloadStatus.DOWNLOADING:
                    download.status = DownloadStatus.PAUSED
                    download.paused = True
                    logger.info(f"Download {download_id} paused")
        except Exception as e:
            logger.error(f"Failed to pause download {download_id}: {e}")

    async def resume_download(self, download_id: int):
        """Resume a paused download"""
        self.paused_downloads.discard(download_id)

        try:
            async with get_db_context() as db:
                download = db.query(Download).filter(Download.id == download_id).first()
                if download and download.status == DownloadStatus.PAUSED:
                    download.status = DownloadStatus.DOWNLOADING
                    download.paused = False
                    logger.info(f"Download {download_id} resumed")
        except Exception as e:
            logger.error(f"Failed to resume download {download_id}: {e}")

    async def cancel_download(self, download_id: int):
        """Cancel a download"""
        self.active_downloads.pop(download_id, None)
        self.paused_downloads.discard(download_id)
        logger.info(f"Download {download_id} cancelled")

    async def shutdown(self):
        """Graceful shutdown"""
        logger.info("Shutting down download manager")
        # Cancel all active downloads
        for download_id in list(self.active_downloads.keys()):
            await self.cancel_download(download_id)
        logger.info("Download manager shutdown complete")

# Singleton instance
manager_instance = DownloadManager()
