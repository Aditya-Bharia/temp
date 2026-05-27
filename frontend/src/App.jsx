import React, { useState, useEffect } from 'react'
import './index.css'
import Dashboard from './pages/Dashboard'
import useWebSocket from './hooks/useWebSocket'

export default function App() {
  const [playlistUrl, setPlaylistUrl] = useState('')
  const [songs, setSongs] = useState([])
  const [loading, setLoading] = useState(false)
  const [playlistId, setPlaylistId] = useState(null)
  const [stats, setStats] = useState({
    total: 0,
    completed: 0,
    failed: 0,
    current_song: ''
  })

  const ws = useWebSocket('ws://localhost:8000/ws')

  useEffect(() => {
    if (!ws) return

    const handleMessage = (event) => {
      try {
        const data = JSON.parse(event.data)
        if (data.type === 'stats') {
          setStats(data)
        }
      } catch (e) {
        console.error('WebSocket message error:', e)
      }
    }

    ws.addEventListener('message', handleMessage)
    return () => ws.removeEventListener('message', handleMessage)
  }, [ws])

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
      setSongs(data.songs)
      setPlaylistId(data.playlist_id)
      setStats({ total: data.total, completed: 0, failed: 0, current_song: '' })
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

      <div className="relative z-10 p-6 max-w-7xl mx-auto">
        {!songs.length ? (
          <div className="flex flex-col items-center justify-center min-h-screen">
            <div className="glass p-12 rounded-2xl max-w-xl w-full border-2 border-neon-blue/50">
              <h1 className="neon-text text-4xl font-bold mb-2 text-center">
                MUSIC DOWNLOADER
              </h1>
              <div className="text-neon-blue/60 text-center mb-8">
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
          <Dashboard
            playlistId={playlistId}
            songs={songs}
            stats={stats}
            ws={ws}
          />
        )}
      </div>
    </div>
  )
}
