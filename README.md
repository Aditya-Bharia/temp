# Esee Music Downloader

A fast desktop downloader for Apple Music playlists with live progress, multi-provider search, metadata embedding, and a clean browser frontend.

---

## Table of Contents

- [What This Does](#what-this-does)
- [Features](#features)
- [Quick Start](#quick-start)
- [Backend](#backend)
- [Frontend](#frontend)
- [Usage](#usage)
- [Supported URLs](#supported-urls)
- [Providers](#providers)
- [Downloads](#downloads)
- [Troubleshooting](#troubleshooting)
- [Project Layout](#project-layout)
- [Production](#production)
- [License](#license)

---

## What This Does

Esee Music Downloader takes an Apple Music playlist URL, extracts track names automatically, searches multiple providers for audio sources, and downloads songs with real-time progress and retry handling.

The frontend communicates with a FastAPI backend over WebSocket, so you can watch speed, ETA, and status updates while downloads run.

---

## Features

- Paste an Apple Music playlist URL and extract tracks automatically
- Search 5+ music providers for each song
- Parallel downloads with retries and duplicate detection
- Real-time progress, speed, and queue updates
- Pause / resume support
- Embed metadata and album art into downloaded files
- Browser-based dashboard with live WebSocket updates
- Download queue and automatic fallback providers

---

## Quick Start

### Prerequisites

- Python 3.9+
- Node.js 16+ and npm
- ffmpeg installed and available in `PATH`
- Windows / Mac / Linux

### Install ffmpeg

**Windows (Chocolatey):**

```bash
choco install ffmpeg
```

**Windows manual:**

- Download from https://ffmpeg.org/download.html
- Add `ffmpeg` to `PATH`

**Mac:**

```bash
brew install ffmpeg
```

**Linux:**

```bash
sudo apt-get install ffmpeg
```

---

## Backend

```bash
cd backend
python -m venv venv
venv\Scripts\activate     # Windows
# source venv/bin/activate # Mac/Linux
pip install -r requirements.txt
python main.py
```

Backend runs on `http://localhost:8000`

Health check: `http://localhost:8000/api/health`

---

## Frontend

In a new terminal:

```bash
cd frontend
npm install
npm run dev
```

Frontend runs on `http://localhost:5173`

---

## Usage

1. Open `http://localhost:5173`
2. Paste an Apple Music playlist URL
3. Click `EXTRACT SONGS`
4. Watch downloads start automatically
5. Monitor progress and speed in real time

Downloads are saved to `./backend/downloads/` by default.

---

## Supported URLs

- Apple Music playlist URLs: `https://music.apple.com/*/playlist/...`
- Direct song URLs
- Playlist share links

---

## Providers

**Primary:**

- YouTube

**Secondary:**

- SoundCloud
- Jamendo
- Audius
- Mr-Jatt (fallback)

---

## Downloads

All downloaded files are stored under `./backend/downloads/`.

The folder is created automatically when downloads begin.

---

## Troubleshooting

### WebSocket connection fails

- Ensure the backend is running on port `8000`
- Check firewall settings
- Reload the frontend page

### Songs not found

- Use a more specific song query
- Verify the track exists on YouTube or another provider
- Some videos may be geographically restricted

### Download errors

- Check your internet connection
- Try a different provider
- Increase `DOWNLOAD_TIMEOUT` in `backend/config.py`

### No audio extracted

- Confirm `ffmpeg` is installed and in `PATH`
- Update `yt-dlp` with `pip install --upgrade yt-dlp`

---

## Project Layout

```
eseee/
├── backend/
│   ├── main.py
│   ├── config.py
│   ├── downloader.py
│   ├── providers_youtube.py
│   ├── providers_other.py
│   ├── scrapers.py
│   ├── ws_manager.py
│   ├── requirements.txt
│   └── downloads/
├── frontend/
│   ├── index.html
│   ├── package.json
│   ├── vite.config.js
│   ├── postcss.config.js
│   ├── tailwind.config.js
│   └── src/
│       ├── App.jsx
│       ├── main.jsx
│       ├── index.css
│       ├── components/
│       └── hooks/
└── readme.md
```

---

## Production

### Frontend build

```bash
cd frontend
npm run build
```

### Backend production

On Windows:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

On Mac/Linux:

```bash
pip install gunicorn
gunicorn -w 4 -k uvicorn.workers.UvicornWorker main:app
```

---

## License

MIT

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