# ============================================================================
# 2. models.py - FIXED WITH PROPER DATABASE SETUP
# ============================================================================

from sqlalchemy import create_engine, Column, String, Integer, Float, DateTime, Enum, Boolean, Index
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import QueuePool
from datetime import datetime
import enum
from config import DATABASE_URL, get_environment
import logging

logger = logging.getLogger(__name__)

# Configure engine based on environment
if "postgresql" in DATABASE_URL:
    # PostgreSQL - production database
    engine = create_engine(
        DATABASE_URL,
        poolclass=QueuePool,
        pool_size=20,
        max_overflow=40,
        pool_pre_ping=True,  # Verify connections before use
        pool_recycle=3600,  # Recycle connections every hour
        echo=False,
    )
else:
    # SQLite - development only
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False, "timeout": 10},
        echo=False,
        execution_options={"sqlite_synchronous": 1},
    )

    # Enable WAL mode for better concurrency
    with engine.connect() as conn:
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA busy_timeout=5000")
        conn.commit()

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class DownloadStatus(str, enum.Enum):
    PENDING = "pending"
    DOWNLOADING = "downloading"
    COMPLETED = "completed"
    FAILED = "failed"
    PAUSED = "paused"

class Download(Base):
    __tablename__ = "downloads"

    id = Column(Integer, primary_key=True)
    song_name = Column(String(500), index=True)
    artist = Column(String(300))
    provider = Column(String(100))
    download_url = Column(String(2000))
    file_path = Column(String(1000))
    status = Column(Enum(DownloadStatus), default=DownloadStatus.PENDING, index=True)
    paused = Column(Boolean, default=False)
    file_size = Column(Integer, default=0)
    downloaded_size = Column(Integer, default=0)
    speed_mbps = Column(Float, default=0.0)
    eta_seconds = Column(Float, default=0.0)
    error_message = Column(String(500))
    playlist_id = Column(Integer, index=True)
    version = Column(Integer, default=0)  # For optimistic locking
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    completed_at = Column(DateTime)

    __table_args__ = (
        Index('idx_playlist_status', 'playlist_id', 'status'),
        Index('idx_created_desc', 'created_at'),
    )

class Playlist(Base):
    __tablename__ = "playlists"

    id = Column(Integer, primary_key=True)
    url = Column(String(2000), unique=True)
    name = Column(String(300))
    total_songs = Column(Integer, default=0)
    downloaded_count = Column(Integer, default=0)
    failed_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    __table_args__ = (
        Index('idx_created_playlist', 'created_at'),
    )

def init_db():
    """Initialize database tables"""
    Base.metadata.create_all(bind=engine)
    logger.info("Database tables initialized")

def get_db():
    """Database session dependency"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
