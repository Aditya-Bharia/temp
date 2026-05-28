import React, { useState, useEffect } from 'react'
import './index.css'
import Dashboard from './pages/Dashboard'
import useWebSocket from './hooks/useWebSocket'
import { DownloadProvider } from './context/DownloadContext'

export default function App() {
  return (
    <DownloadProvider>
      <AppContent />
    </DownloadProvider>
  )
}

function AppContent() {
  const [playlistUrl, setPlaylistUrl] = useState('')
  const [loading, setLoading] = useState(false)
  const [showDashboard, setShowDashboard] = useState(false)

  const ws = useWebSocket('ws://localhost:8000/ws')

  // Load state from storage on mount
  useEffect(() => {
    const saved = localStorage.getItem('music_downloader_state')
    if (saved) {
      const state = JSON.parse(saved)
      if (state.playlistId && state.songs.length > 0) {
        setShowDashboard(true)
      }
    }
  }, [])

  const handleExtractPlaylist = async () => {
    if (!playlistUrl.trim()) {
      alert('Please paste a playlist URL')
      return
    }

    setLoading(true)
    try {
      const response = await fetch('/api/extract-playlist', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ url: playlistUrl })
      })

      if (!response.ok) throw new Error('Failed to extract playlist')

      const data = await response.json()
      setShowDashboard(true)
    } catch (error) {
      alert('Error: ' + error.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-dark-primary via-dark-secondary to-dark-tertiary">
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute top-0 left-0 w-96 h-96 bg-neon-blue/10 rounded-full blur-3xl"></div>
        <div className="absolute bottom-0 right-0 w-96 h-96 bg-neon-purple/10 rounded-full blur-3xl"></div>
      </div>

      <div className="relative z-10 p-4 md:p-6 max-w-7xl mx-auto">
        {!showDashboard ? (
          <div className="flex flex-col items-center justify-center min-h-screen">
            <div className="glass p-8 md:p-12 rounded-2xl max-w-xl w-full border-2 border-neon-blue/50">
              <h1 className="neon-text text-2xl md:text-4xl font-bold mb-2 text-center">
                MUSIC DOWNLOADER
              </h1>
              <div className="text-neon-blue/60 text-center mb-8 text-sm md:text-base">
                Extract → Search → Download
              </div>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm text-neon-blue/80 mb-2">
                    Apple Music Playlist URL
                  </label>
                  <input
                    type="text"
                    value={playlistUrl}
                    onChange={(e) => setPlaylistUrl(e.target.value)}
                    placeholder="https://music.apple.com/..."
                    className="input-neon"
                    onKeyPress={(e) => e.key === 'Enter' && handleExtractPlaylist()}
                  />
                </div>

                <button
                  onClick={handleExtractPlaylist}
                  disabled={loading}
                  className="btn-neon w-full"
                >
                  {loading ? 'EXTRACTING...' : 'EXTRACT SONGS'}
                </button>

                <div className="text-xs text-neon-blue/40 text-center mt-6 space-y-1">
                  <p>Supports: Apple Music, Spotify (via URL)</p>
                  <p>Providers: YouTube, SoundCloud, Jamendo, Audius</p>
                </div>
              </div>
            </div>
          </div>
        ) : (
          <Dashboard ws={ws} onBack={() => setShowDashboard(false)} />
        )}
      </div>
    </div>
  )
}
