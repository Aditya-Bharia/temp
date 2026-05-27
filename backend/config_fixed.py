# PRODUCTION-READY BACKEND CODE
# This file contains all corrected Python files for production deployment

# ============================================================================
# 1. config.py - FIXED WITH ENVIRONMENT CONFIGURATION
# ============================================================================

import os
from pathlib import Path
from enum import Enum
from dotenv import load_dotenv
import logging

load_dotenv()

# Base directories
BASE_DIR = Path(__file__).parent.parent
DOWNLOADS_DIR = BASE_DIR / "downloads"

# Environment management
class Environment(str, Enum):
    DEVELOPMENT = "development"
    TESTING = "testing"
    PRODUCTION = "production"

def get_environment():
    return os.getenv("ENVIRONMENT", "development")

# Database configuration - production uses PostgreSQL
if get_environment() == "production":
    DATABASE_URL = os.getenv(
        "DATABASE_URL",
        "postgresql://user:password@localhost/music_downloader"
    )
else:
    DATABASE_URL = os.getenv(
        "DATABASE_URL",
        "sqlite:///./music_downloader.db"
    )

# CORS configuration
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "http://localhost:5173").split(",")

# Download configuration
MAX_CONCURRENT_DOWNLOADS = int(os.getenv("MAX_CONCURRENT_DOWNLOADS", "3"))
DOWNLOAD_TIMEOUT = int(os.getenv("DOWNLOAD_TIMEOUT", "300"))
CHUNK_SIZE = int(os.getenv("CHUNK_SIZE", "8192"))

# Provider configuration
APPLE_MUSIC_TIMEOUT = int(os.getenv("APPLE_MUSIC_TIMEOUT", "10"))
SEARCH_TIMEOUT = int(os.getenv("SEARCH_TIMEOUT", "15"))

# Logging configuration
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
LOG_DIR = Path("logs")
LOG_DIR.mkdir(exist_ok=True)

# Security configuration
DEBUG = os.getenv("ENVIRONMENT") != "production"
SECRET_KEY = os.getenv("SECRET_KEY", "dev-key-change-in-production")

# API Key configuration
JAMENDO_CLIENT_ID = os.getenv("JAMENDO_CLIENT_ID", "")

# Validation limits
MAX_URL_LENGTH = 2000
MAX_SONG_NAME_LENGTH = 500
MAX_SONGS_PER_PLAYLIST = 1000

logger = logging.getLogger(__name__)
