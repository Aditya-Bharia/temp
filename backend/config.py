import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).parent.parent
DOWNLOADS_DIR = BASE_DIR / "downloads"
DATABASE_URL = "sqlite:///./music_downloader.db"

# Directory creation handled in FastAPI startup event

DEBUG = True
MAX_CONCURRENT_DOWNLOADS = 3
DOWNLOAD_TIMEOUT = 300
CHUNK_SIZE = 8192

APPLE_MUSIC_TIMEOUT = 10
SEARCH_TIMEOUT = 15

LOG_LEVEL = "INFO"
