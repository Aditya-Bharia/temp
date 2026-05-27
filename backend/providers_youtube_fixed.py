# ============================================================================
# 6. providers_youtube.py - FIXED WITH PROPER EXECUTOR MANAGEMENT
# ============================================================================

import yt_dlp
import asyncio
from concurrent.futures import ThreadPoolExecutor
import logging

logger = logging.getLogger(__name__)

class YouTubeProvider:
    """Encapsulate YouTube provider with proper resource management"""

    def __init__(self, max_workers: int = 3):
        self.executor = ThreadPoolExecutor(
            max_workers=max_workers,
            thread_name_prefix="yt_dlp_"
        )

    async def search(self, query: str, timeout: float = 10.0) -> dict:
        """Search YouTube for song with timeout"""
        try:
            loop = asyncio.get_event_loop()
            result = await asyncio.wait_for(
                loop.run_in_executor(self.executor, self._search_sync, query),
                timeout=timeout
            )
            return result
        except asyncio.TimeoutError:
            logger.warning(f"YouTube search timeout for: {query}")
            return None
        except Exception as e:
            logger.error(f"YouTube search error for '{query}': {e}")
            return None

    def _search_sync(self, query: str) -> dict:
        """Blocking search operation"""
        try:
            ydl_opts = {
                'quiet': True,
                'no_warnings': True,
                'extract_flat': 'in_playlist',
                'default_search': 'ytsearch',
                'socket_timeout': 10,
                'no_color': True,
            }

            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                result = ydl.extract_info(f"ytsearch1:{query}", download=False)
                if result and 'entries' in result and len(result['entries']) > 0:
                    entry = result['entries'][0]
                    return {
                        "provider": "youtube",
                        "url": f"https://www.youtube.com/watch?v={entry['id']}",
                        "title": entry.get('title', query),
                        "duration": entry.get('duration', 0),
                        "quality": "high"
                    }
            return None
        except Exception as e:
            logger.error(f"YouTube sync search error: {e}")
            return None

    async def get_download_url(self, youtube_url: str, timeout: float = 15.0) -> dict:
        """Get best audio URL from YouTube with timeout"""
        try:
            loop = asyncio.get_event_loop()
            result = await asyncio.wait_for(
                loop.run_in_executor(self.executor, self._get_url_sync, youtube_url),
                timeout=timeout
            )
            return result
        except asyncio.TimeoutError:
            logger.warning(f"YouTube URL extraction timeout: {youtube_url}")
            return None
        except Exception as e:
            logger.error(f"YouTube URL extraction error: {e}")
            return None

    def _get_url_sync(self, youtube_url: str) -> dict:
        """Blocking URL extraction"""
        try:
            ydl_opts = {
                'format': 'bestaudio/best',
                'quiet': True,
                'no_warnings': True,
                'socket_timeout': 15,
                'no_color': True,
            }

            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(youtube_url, download=False)
                if info:
                    url = info.get('url')
                    if not url and info.get('formats'):
                        url = info['formats'][0].get('url')

                    if url:
                        return {
                            "url": url,
                            "ext": info.get('ext', 'mp3'),
                            "title": info.get('title', 'unknown'),
                            "filesize": info.get('filesize', 0)
                        }
            return None
        except Exception as e:
            logger.error(f"YouTube sync URL extraction error: {e}")
            return None

    def shutdown(self):
        """Clean up executor threads"""
        logger.info("Shutting down YouTube provider")
        self.executor.shutdown(wait=True)

# Singleton instance
youtube_provider = YouTubeProvider()

# For backward compatibility
async def search_youtube(query: str) -> dict:
    return await youtube_provider.search(query)

async def get_youtube_download_url(youtube_url: str) -> dict:
    return await youtube_provider.get_download_url(youtube_url)
