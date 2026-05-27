import aiohttp
from bs4 import BeautifulSoup
from urllib.parse import urlparse, parse_qs
import re

async def extract_apple_music_songs(url: str) -> list:
    """Extract songs from Apple Music playlist URL"""
    try:
        async with aiohttp.ClientSession() as session:
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            async with session.get(url, headers=headers, timeout=aiohttp.ClientTimeout(total=10)) as resp:
                if resp.status != 200:
                    return []

                html = await resp.text()
                soup = BeautifulSoup(html, 'lxml')

                songs = []

                # Apple Music embeds data in script tags
                scripts = soup.find_all('script', type='application/ld+json')
                for script in scripts:
                    try:
                        import json
                        data = json.loads(script.string)
                        if isinstance(data, dict) and 'itemListElement' in data:
                            for item in data['itemListElement']:
                                if 'name' in item:
                                    songs.append(item['name'])
                    except:
                        pass

                if songs:
                    return songs

                # Fallback: look for song info in meta tags and page text
                meta_tags = soup.find_all('meta', property='og:title')
                for tag in meta_tags:
                    content = tag.get('content', '')
                    if content and len(content) > 3:
                        songs.append(content)

                return list(set(songs))[:50]  # Remove duplicates, limit to 50

    except Exception as e:
        print(f"Error scraping Apple Music: {e}")
        return []

def parse_playlist_url(url: str) -> dict:
    """Parse Apple Music URL to extract playlist info"""
    try:
        parsed = urlparse(url)
        if 'music.apple.com' in parsed.netloc:
            # Extract playlist ID and region from URL
            path_parts = parsed.path.split('/')
            playlist_id = path_parts[-1] if path_parts else "unknown"
            return {
                "type": "apple_music",
                "playlist_id": playlist_id,
                "url": url
            }
    except:
        pass
    return {"type": "unknown", "url": url}
