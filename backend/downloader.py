import aiohttp
import aiofiles
import asyncio
from pathlib import Path
import time
from datetime import datetime
from config import DOWNLOADS_DIR, CHUNK_SIZE, MAX_CONCURRENT_DOWNLOADS, DOWNLOAD_TIMEOUT
from models import Download, DownloadStatus, SessionLocal
from ws_manager import manager
from providers_youtube import search_youtube, get_youtube_download_url
from providers_other import search_jamendo
import mutagen
from mutagen.mp3 import MP3
import io

class DownloadManager:
    def __init__(self):
        self.active_downloads = {}
        self.semaphore = asyncio.Semaphore(MAX_CONCURRENT_DOWNLOADS)
        self.paused_downloads = set()

    async def search_providers(self, song_name: str) -> dict:
        """Search all providers for song"""
        best_result = None

        # Try YouTube first (most reliable)
        yt_result = await search_youtube(song_name)
        if yt_result:
            best_result = yt_result
            yt_url = await get_youtube_download_url(yt_result['url'])
            if yt_url:
                best_result['download_url'] = yt_url['url']
                return best_result

        # Try other providers in parallel
        jamendo_result = await search_jamendo(song_name)
        if jamendo_result and jamendo_result.get('url'):
            if not best_result:
                best_result = jamendo_result

        return best_result

    async def download_file(self, download_id: int, url: str, file_path: str):
        """Download file with progress tracking"""
        try:
            async with self.semaphore:
                if download_id in self.paused_downloads:
                    await manager.send_error(download_id, "Download paused")
                    return

                self.active_downloads[download_id] = True
                start_time = time.time()
                downloaded = 0
                total_size = 0

                async with aiohttp.ClientSession() as session:
                    async with session.get(
                        url,
                        timeout=aiohttp.ClientTimeout(total=DOWNLOAD_TIMEOUT),
                        headers={'User-Agent': 'Mozilla/5.0'}
                    ) as resp:
                        if resp.status != 200:
                            raise Exception(f"HTTP {resp.status}")

                        total_size = int(resp.headers.get('content-length', 0))

                        async with aiofiles.open(file_path, 'wb') as f:
                            async for chunk in resp.content.iter_chunked(CHUNK_SIZE):
                                if download_id not in self.active_downloads:
                                    Path(file_path).unlink(missing_ok=True)
                                    return

                                if download_id in self.paused_downloads:
                                    continue

                                await f.write(chunk)
                                downloaded += len(chunk)

                                elapsed = time.time() - start_time
                                if elapsed > 0:
                                    speed = (downloaded / (1024 * 1024)) / elapsed
                                    eta = (total_size - downloaded) / (speed * 1024 * 1024) if speed > 0 else 0
                                    progress = int((downloaded / total_size * 100)) if total_size > 0 else 0

                                    await manager.send_progress(download_id, "downloading", progress, speed, eta)

                db = SessionLocal()
                download = db.query(Download).filter(Download.id == download_id).first()
                if download:
                    download.status = DownloadStatus.COMPLETED
                    download.downloaded_size = downloaded
                    download.completed_at = datetime.utcnow()
                    db.commit()

                await manager.send_download_complete(download_id, str(file_path))

        except Exception as e:
            db = SessionLocal()
            download = db.query(Download).filter(Download.id == download_id).first()
            if download:
                download.status = DownloadStatus.FAILED
                download.error_message = str(e)
                db.commit()

            await manager.send_error(download_id, str(e))

        finally:
            self.active_downloads.pop(download_id, None)
            db.close()

    async def pause_download(self, download_id: int):
        """Pause a download"""
        self.paused_downloads.add(download_id)
        db = SessionLocal()
        download = db.query(Download).filter(Download.id == download_id).first()
        if download:
            download.status = DownloadStatus.PAUSED
            db.commit()
        db.close()

    async def resume_download(self, download_id: int):
        """Resume a paused download"""
        self.paused_downloads.discard(download_id)
        db = SessionLocal()
        download = db.query(Download).filter(Download.id == download_id).first()
        if download:
            download.status = DownloadStatus.DOWNLOADING
            db.commit()
        db.close()

    async def cancel_download(self, download_id: int):
        """Cancel a download"""
        self.active_downloads.pop(download_id, None)
        self.paused_downloads.discard(download_id)

manager_instance = DownloadManager()
