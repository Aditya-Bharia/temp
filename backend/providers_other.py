import aiohttp
import json
import asyncio

async def search_soundcloud(query: str) -> dict:
    """Search SoundCloud for public tracks"""
    try:
        # Note: Direct API requires auth token; using public search approach
        async with aiohttp.ClientSession() as session:
            # Simple search via web endpoint
            url = f"https://soundcloud.com/search?q={query}&sc=tracks"
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }

            async with session.get(url, headers=headers, timeout=aiohttp.ClientTimeout(total=10)) as resp:
                if resp.status == 200:
                    text = await resp.text()
                    # SoundCloud embeds data in HTML; basic parsing
                    if 'soundcloud.com/' in text:
                        return {
                            "provider": "soundcloud",
                            "status": "available",
                            "note": "Requires authentication for download"
                        }

        return None
    except Exception as e:
        print(f"SoundCloud search error: {e}")
        return None

async def search_jamendo(query: str) -> dict:
    """Search Jamendo for royalty-free music"""
    try:
        async with aiohttp.ClientSession() as session:
            # Jamendo has a public API
            url = "https://api.jamendo.com/v3.0/tracks/"
            params = {
                "client_id": "your_client_id",  # Free tier available
                "search": query,
                "limit": 1,
                "format": "json"
            }

            async with session.get(url, params=params, timeout=aiohttp.ClientTimeout(total=10)) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    if data.get('results'):
                        track = data['results'][0]
                        return {
                            "provider": "jamendo",
                            "url": track.get('audiodownload'),
                            "title": track.get('name'),
                            "artist": track.get('artist_name'),
                            "license": "CC"
                        }

        return None
    except Exception as e:
        print(f"Jamendo search error: {e}")
        return None
