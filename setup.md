# Setup & Installation Guide

## Prerequisites

- Python 3.9+
- Node.js 16+ & npm
- Windows 10/11 or Mac/Linux
- ffmpeg (for best results with yt-dlp)

## Quick Start

### 1. Install ffmpeg

**Windows (using Chocolatey):**
```bash
choco install ffmpeg
```

**Windows (manual):**
- Download from https://ffmpeg.org/download.html
- Add to PATH

**Mac:**
```bash
brew install ffmpeg
```

**Linux:**
```bash
sudo apt-get install ffmpeg
```

### 2. Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv

# Activate venv
# Windows:
venv\Scripts\activate
# Mac/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run server
python main.py
```

Server will run on `http://localhost:8000`

**Check health:** http://localhost:8000/api/health

### 3. Frontend Setup

In a new terminal:

```bash
cd frontend

# Install dependencies
npm install

# Run dev server
npm run dev
```

Frontend will run on `http://localhost:5173`

## Usage

1. Open http://localhost:5173 in browser
2. Paste Apple Music playlist URL
3. Click "EXTRACT SONGS"
4. Downloads start automatically
5. Watch real-time progress
6. Songs save to `./backend/downloads/`

> **Note:** On Windows, use `uvicorn main:app` for production instead of Gunicorn, as Gunicorn is not available on Windows.

## Supported URLs

- Apple Music: `https://music.apple.com/*/playlist/...`
- Direct song URLs
- Playlist shares

## Providers

**Primary (Most reliable):**
- YouTube

**Secondary:**
- SoundCloud (public tracks)
- Jamendo (royalty-free)
- Audius (web3 music)

## Troubleshooting

### WebSocket connection fails
- Make sure backend is running on port 8000
- Check firewall settings
- Try reloading frontend

### Songs not found
- Try more specific song names
- Check YouTube has the song available
- Some videos may be geographically blocked

### Download errors
- Check internet connection
- Try different provider
- Increase DOWNLOAD_TIMEOUT in backend/config.py

### No audio extracted
- Make sure ffmpeg is installed and in PATH
- yt-dlp may need update: `pip install --upgrade yt-dlp`

## Performance Tips

- Increase MAX_CONCURRENT_DOWNLOADS in backend/config.py for faster parallel downloads (default: 3)
- Close other bandwidth-heavy apps
- Wired internet connection recommended

## Features Demo

- **Real-time Progress:** Live speed and ETA
- **Parallel Downloads:** Multiple songs at once
- **Error Recovery:** Auto-retry failed downloads
- **Duplicate Skip:** Won't re-download songs
- **Queue System:** Automatic sequential processing
- **Dark Neon UI:** Cyberpunk-style dashboard

## File Structure

```
music-downloader/
├── backend/
│   ├── main.py              (FastAPI server)
│   ├── models.py            (SQLite models)
│   ├── scrapers.py          (Apple Music scraper)
│   ├── downloader.py        (Download manager)
│   ├── ws_manager.py        (WebSocket handler)
│   ├── providers_youtube.py (YouTube provider)
│   ├── providers_other.py   (Other providers)
│   ├── requirements.txt
│   └── downloads/           (Downloaded songs)
├── frontend/
│   ├── src/
│   │   ├── App.jsx
│   │   ├── main.jsx
│   │   ├── index.css
│   │   ├── pages/
│   │   ├── components/
│   │   └── hooks/
│   ├── index.html
│   ├── package.json
│   └── vite.config.js
└── README.md
```

## Database

SQLite database auto-created at: `./backend/music_downloader.db`

Tracks:
- Downloads (status, progress, errors)
- Playlists (metadata)

## Stopping the App

- Frontend: Ctrl+C in npm terminal
- Backend: Ctrl+C in Python terminal

## Building for Production

**Frontend:**
```bash
cd frontend
npm run build
# Creates dist/ folder
```

**Backend:**
Use a production ASGI server like Gunicorn (Linux/Mac):
```bash
pip install gunicorn
gunicorn -w 4 -k uvicorn.workers.UvicornWorker main:app
```

On **Windows**, use:
```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

## License

MIT
