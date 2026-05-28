from pydantic_settings import BaseSettings
from pathlib import Path

class Settings(BaseSettings):
    app_name: str = "music-downloader"
    debug: bool = False
    host: str = "0.0.0.0"
    port: int = 8000

    # Storage and persistence
    downloads_dir: str = str(Path(__file__).resolve().parent.parent / "downloads")
    database_url: str = "sqlite:///./music_downloader.db"
    redis_url: str = "redis://redis:6379/0"

    # Worker and queue
    task_timeout: int = 3600
    max_retries: int = 3
    retry_intervals: tuple[int, ...] = (10, 30, 60)

    # Limits
    max_concurrent_downloads: int = 3
    download_timeout: int = 300
    chunk_size: int = 8192
    max_request_size: int = 5 * 1024 * 1024  # 5 MB

    # CORS
    allowed_origins: str = "http://localhost:3000"

    # Logging
    log_level: str = "INFO"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
