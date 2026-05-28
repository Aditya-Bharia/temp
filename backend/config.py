"""Legacy config kept for compatibility. Use `settings.py` for production-grade configuration.
Small shim that exposes legacy constants while new code uses `settings.Settings`.
"""
from pathlib import Path
from .settings import Settings

_settings = Settings()

BASE_DIR = Path(__file__).parent.parent
DOWNLOADS_DIR = Path(_settings.downloads_dir)
DATABASE_URL = _settings.database_url
DEBUG = _settings.debug
MAX_CONCURRENT_DOWNLOADS = _settings.max_concurrent_downloads
DOWNLOAD_TIMEOUT = _settings.download_timeout
CHUNK_SIZE = _settings.chunk_size
LOG_LEVEL = _settings.log_level

__all__ = [
	"BASE_DIR",
	"DOWNLOADS_DIR",
	"DATABASE_URL",
	"DEBUG",
	"MAX_CONCURRENT_DOWNLOADS",
	"DOWNLOAD_TIMEOUT",
	"CHUNK_SIZE",
	"LOG_LEVEL",
]
