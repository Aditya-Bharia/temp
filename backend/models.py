from sqlalchemy import create_engine, Column, String, Integer, Float, DateTime, Enum
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime
import enum
from config import DATABASE_URL

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
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
    song_name = Column(String, index=True)
    artist = Column(String)
    provider = Column(String)
    download_url = Column(String)
    file_path = Column(String)
    status = Column(Enum(DownloadStatus), default=DownloadStatus.PENDING)
    file_size = Column(Integer, default=0)
    downloaded_size = Column(Integer, default=0)
    speed_mbps = Column(Float, default=0.0)
    eta_seconds = Column(Float, default=0.0)
    error_message = Column(String)
    playlist_id = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime)

class Playlist(Base):
    __tablename__ = "playlists"

    id = Column(Integer, primary_key=True)
    url = Column(String, unique=True)
    name = Column(String)
    total_songs = Column(Integer, default=0)
    downloaded_count = Column(Integer, default=0)
    failed_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)

def init_db():
    Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
