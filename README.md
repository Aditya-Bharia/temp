# Music Downloader

A simple, fast desktop app to download songs from Apple Music playlists.

Features

Paste Apple Music playlist URL

Auto-extract song names

Search 5+ music providers

Parallel downloads

Real-time progress & speed

Pause/Resume

Retry failed downloads

Skip duplicates

Embed metadata & album art

Setup

Backend

cd backend
pip install -r requirements.txt
python main.py

Runs on http://localhost:8000WebSocket: ws://localhost:8000/ws

Frontend

cd frontend
npm install
npm run dev

Runs on http://localhost:5173

Providers

YouTube (yt-dlp)

SoundCloud

Jamendo

Audius

Mr-Jatt (fallback)

Usage

Paste Apple Music playlist URL

Click "Download"

Watch real-time progress

Songs save to ./downloads/

Downloads Location

./downloads/ (created automatically)

Requirements

Python 3.9+

Node.js 16+

Windows/Mac/Linux

Setup & Installation Guide

Prerequisites

Python 3.9+

Node.js 16+ & npm

Windows 10/11 or Mac/Linux

ffmpeg (for best results with yt-dlp)

Quick Start

1. Install ffmpeg

Windows (using Chocolatey):

choco install ffmpeg

Windows (manual):

Download from https://ffmpeg.org/download.html

Add to PATH

Mac:

brew install ffmpeg

Linux:

sudo apt-get install ffmpeg

2. Backend Setup

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

Server will run on http://localhost:8000

Check health: http://localhost:8000/api/health

3. Frontend Setup

In a new terminal:

cd frontend

# Install dependencies
npm install

# Run dev server
npm run dev

Frontend will run on http://localhost:5173

Usage

Open http://localhost:5173 in browser

Paste Apple Music playlist URL

Click "EXTRACT SONGS"

Downloads start automatically

Watch real-time progress

Songs save to ./backend/downloads/

Supported URLs

Apple Music: https://music.apple.com/*/playlist/...

Direct song URLs

Playlist shares

Providers

Primary (Most reliable):

YouTube

Secondary:

SoundCloud (public tracks)

Jamendo (royalty-free)

Audius (web3 music)

Troubleshooting

WebSocket connection fails

Make sure backend is running on port 8000

Check firewall settings

Try reloading frontend

Songs not found

Try more specific song names

Check YouTube has the song available

Some videos may be geographically blocked

Download errors

Check internet connection

Try different provider

Increase DOWNLOAD_TIMEOUT in backend/config.py

No audio extracted

Make sure ffmpeg is installed and in PATH

yt-dlp may need update: pip install --upgrade yt-dlp

Performance Tips

Increase MAX_CONCURRENT_DOWNLOADS in backend/config.py for faster parallel downloads (default: 3)

Close other bandwidth-heavy apps

Wired internet connection recommended

Features Demo

Real-time Progress: Live speed and ETA

Parallel Downloads: Multiple songs at once

Error Recovery: Auto-retry failed downloads

Duplicate Skip: Won't re-download songs

Queue System: Automatic sequential processing

Dark Neon UI: Cyberpunk-style dashboard

File Structure

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

Database

SQLite database auto-created at: ./backend/music_downloader.db

Tracks:

Downloads (status, progress, errors)

Playlists (metadata)

Stopping the App

Frontend: Ctrl+C in npm terminal

Backend: Ctrl+C in Python terminal

Building for Production

Frontend:

cd frontend
npm run build
# Creates dist/ folder

Backend:Use a production ASGI server like Gunicorn:

pip install gunicorn
gunicorn -w 4 -k uvicorn.workers.UvicornWorker main:app

License

MIT



Setup & Installation Guide

Prerequisites

Python 3.9+

Node.js 16+ & npm

Windows 10/11 or Mac/Linux

ffmpeg (for best results with yt-dlp)

Quick Start

1. Install ffmpeg

Windows (using Chocolatey):

choco install ffmpeg

Windows (manual):

Download from https://ffmpeg.org/download.html

Add to PATH

Mac:

brew install ffmpeg

Linux:

sudo apt-get install ffmpeg

2. Backend Setup

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

Server will run on http://localhost:8000

Check health: http://localhost:8000/api/health

3. Frontend Setup

In a new terminal:

cd frontend

# Install dependencies
npm install

# Run dev server
npm run dev

Frontend will run on http://localhost:5173

Usage

Open http://localhost:5173 in browser

Paste Apple Music playlist URL

Click "EXTRACT SONGS"

Downloads start automatically

Watch real-time progress

Songs save to ./backend/downloads/

Supported URLs

Apple Music: https://music.apple.com/*/playlist/...

Direct song URLs

Playlist shares

Providers

Primary (Most reliable):

YouTube

Secondary:

SoundCloud (public tracks)

Jamendo (royalty-free)

Audius (web3 music)

Troubleshooting

WebSocket connection fails

Make sure backend is running on port 8000

Check firewall settings

Try reloading frontend

Songs not found

Try more specific song names

Check YouTube has the song available

Some videos may be geographically blocked

Download errors

Check internet connection

Try different provider

Increase DOWNLOAD_TIMEOUT in backend/config.py

No audio extracted

Make sure ffmpeg is installed and in PATH

yt-dlp may need update: pip install --upgrade yt-dlp

Performance Tips

Increase MAX_CONCURRENT_DOWNLOADS in backend/config.py for faster parallel downloads (default: 3)

Close other bandwidth-heavy apps

Wired internet connection recommended

Features Demo

Real-time Progress: Live speed and ETA

Parallel Downloads: Multiple songs at once

Error Recovery: Auto-retry failed downloads

Duplicate Skip: Won't re-download songs

Queue System: Automatic sequential processing

Dark Neon UI: Cyberpunk-style dashboard

File Structure

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

Database

SQLite database auto-created at: ./backend/music_downloader.db

Tracks:

Downloads (status, progress, errors)

Playlists (metadata)

Stopping the App

Frontend: Ctrl+C in npm terminal

Backend: Ctrl+C in Python terminal

Building for Production

Frontend:

cd frontend
npm run build
# Creates dist/ folder

Backend:Use a production ASGI server like Gunicorn:

pip install gunicorn
gunicorn -w 4 -k uvicorn.workers.UvicornWorker main:app

License

MITlsinit.py    models.py             requirements.txtpycache    music_downloader.db   scrapers.pyconfig.py      package-lock.json     ws_manager.pydownloader.py  providers_other.pymain.py        providers_youtube.py



/frontend$ lsindex.html    package-lock.json  postcss.config.js  tailwind.config.jsnode_modules  package.json       src                vite.config.js