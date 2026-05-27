import yt_dlp
import asyncio
from concurrent.futures import ThreadPoolExecutor

executor = ThreadPoolExecutor(max_workers=3)

async def search_youtube(query: str) -> dict:
    """Search YouTube for song and return best match"""
    try:
        loop = asyncio.get_event_loop()

        def _search():
            ydl_opts = {
                'quiet': True,
                'no_warnings': True,
                'extract_flat': 'in_playlist',
                'default_search': 'ytsearch',
                'socket_timeout': 10,
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

        result = await loop.run_in_executor(executor, _search)
        return result

    except Exception as e:
        print(f"YouTube search error: {e}")
        return None

async def get_youtube_download_url(youtube_url: str) -> dict:
    """Get best audio URL from YouTube"""
    try:
        loop = asyncio.get_event_loop()

        def _get_url():
            ydl_opts = {
                'format': 'bestaudio/best',
                'quiet': True,
                'no_warnings': True,
                'socket_timeout': 15,
            }

            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(youtube_url, download=False)
                if info:
                    return {
                        "url": info.get('url') or info.get('formats', [{}])[0].get('url'),
                        "ext": info.get('ext', 'mp3'),
                        "title": info.get('title', 'unknown'),
                        "filesize": info.get('filesize', 0)
                    }
        return None

        result = await loop.run_in_executor(executor, _get_url)
        return result

    except Exception as e:
        print(f"YouTube URL extraction error: {e}")
        return None
