from sqlalchemy import create_engine, Column, String, Integer, Float, DateTime, Enum, inspect, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime
import enum
from .settings import Settings
from pathlib import Path

_settings = Settings()
DATABASE_URL = _settings.database_url

# SQLite concurrency support for development
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class DownloadStatus(str, enum.Enum):
    PENDING = "pending"
    QUEUED = "queued"
    PROCESSING = "processing"
    PAUSED = "paused"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class Download(Base):
    __tablename__ = "downloads"

    id = Column(Integer, primary_key=True)
    song_name = Column(String, index=True, nullable=False)
    artist = Column(String, default="")
    provider = Column(String, default="yt-dlp")
    download_url = Column(String, default="")
    status = Column(Enum(DownloadStatus), default=DownloadStatus.PENDING, server_default=DownloadStatus.PENDING.value, nullable=False)
    retry_count = Column(Integer, default=0, nullable=False)
    progress = Column(Integer, default=0, nullable=False)
    temp_path = Column(String, default="")
    final_path = Column(String, default="")
    error_message = Column(String, default="")
    playlist_id = Column(String, default="")
    started_at = Column(DateTime)
    resumed_at = Column(DateTime)
    completed_at = Column(DateTime)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)


class Playlist(Base):
    __tablename__ = "playlists"

    id = Column(Integer, primary_key=True)
    url = Column(String, unique=True)
    name = Column(String)
    total_songs = Column(Integer, default=0)
    downloaded_count = Column(Integer, default=0)
    failed_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)


def _ensure_schema():
    inspector = inspect(engine)
    if "downloads" not in inspector.get_table_names():
        return

    existing = {column["name"] for column in inspector.get_columns("downloads")}
    with engine.begin() as conn:
        if "retry_count" not in existing:
            conn.execute(text("ALTER TABLE downloads ADD COLUMN retry_count INTEGER DEFAULT 0"))
        if "progress" not in existing:
            conn.execute(text("ALTER TABLE downloads ADD COLUMN progress INTEGER DEFAULT 0"))
        if "temp_path" not in existing:
            conn.execute(text("ALTER TABLE downloads ADD COLUMN temp_path VARCHAR DEFAULT ''"))
        if "final_path" not in existing:
            conn.execute(text("ALTER TABLE downloads ADD COLUMN final_path VARCHAR DEFAULT ''"))
        if "started_at" not in existing:
            conn.execute(text("ALTER TABLE downloads ADD COLUMN started_at DATETIME"))
        if "resumed_at" not in existing:
            conn.execute(text("ALTER TABLE downloads ADD COLUMN resumed_at DATETIME"))
        if "updated_at" not in existing:
            conn.execute(text("ALTER TABLE downloads ADD COLUMN updated_at DATETIME DEFAULT CURRENT_TIMESTAMP"))
        if "status" in existing:
            # no changes needed for existing status values
            pass


def init_db():
    Path(_settings.downloads_dir).mkdir(parents=True, exist_ok=True)
    Base.metadata.create_all(bind=engine)
    _ensure_schema()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
