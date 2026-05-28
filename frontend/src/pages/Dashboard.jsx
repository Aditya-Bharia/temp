import React, { useState, useEffect } from 'react'
import ProgressCard from '../components/ProgressCard'
import SongList from '../components/SongList'
import DownloadHistory from '../components/DownloadHistory'
import { useDownloadContext } from '../context/DownloadContext'
import { useDownloadEvents } from '../hooks/useDownloadEvents'

export default function Dashboard({ ws, onBack }) {
  const { state, setPlaylist, addDownload, updateDownload, addToHistory, clearDownloads } = useDownloadContext()
  const { handleProgressEvent, handleCompleteEvent, handleErrorEvent, handleStatsEvent } = useDownloadEvents()
  const [downloading, setDownloading] = useState(false)
  const [queue, setQueue] = useState([])
  const [view, setView] = useState('downloads')

  // Initialize playlist from context
  useEffect(() => {
    if (state.songs.length > 0 && state.playlistId) {
      setQueue(state.songs)
    }
  }, [state.songs])

  // WebSocket event handling
  useEffect(() => {
    if (!ws?.raw?.current) return

    const handleWsMessage = (event) => {
      try {
        const data = JSON.parse(event.data)

        switch (data.type) {
          case 'progress':
            handleProgressEvent(data)
            break
          case 'download_complete':
            handleCompleteEvent(data)
            setQueue(prev => prev.filter(s => s !== state.downloads.find(d => d.id === data.download_id)?.song))
            setDownloading(false)
            break
          case 'error':
            handleErrorEvent(data)
            setQueue(prev => prev.slice(1))
            setDownloading(false)
            break
          case 'stats':
            handleStatsEvent(data)
            break
        }
      } catch (e) {
        console.error('WS error:', e)
      }
    }

    const wsInstance = ws.raw.current
    wsInstance.addEventListener('message', handleWsMessage)
    return () => wsInstance.removeEventListener('message', handleWsMessage)
  }, [ws, handleProgressEvent, handleCompleteEvent, handleErrorEvent, handleStatsEvent])

  // Auto-queue next download
  useEffect(() => {
    if (!downloading && queue.length > 0) {
      const nextSong = queue[0]
      queueDownload(nextSong)
    }
  }, [downloading, queue])

  const queueDownload = async (songName) => {
    try {
      setDownloading(true)

      const queueRes = await fetch('/api/queue-downloads', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          playlist_id: state.playlistId,
          songs: [songName]
        })
      })

      if (!queueRes.ok) {
        setQueue(prev => prev.slice(1))
        setDownloading(false)
        return
      }

      const queueData = await queueRes.json()
      if (queueData.downloads.length === 0) {
        setQueue(prev => prev.slice(1))
        setDownloading(false)
        return
      }

      const downloadId = queueData.downloads[0].id
      addDownload({
        id: downloadId,
        song: songName,
        status: 'queued',
        progress: 0,
        speed: 0,
        eta: 0
      })

      const startRes = await fetch(`/api/start-download/${downloadId}`, {
        method: 'POST'
      })

      if (!startRes.ok) {
        setQueue(prev => prev.slice(1))
        setDownloading(false)
      }
    } catch (error) {
      console.error('Queue error:', error)
      setQueue(prev => prev.slice(1))
      setDownloading(false)
    }
  }

  const handleRetry = async (downloadId) => {
    try {
      const res = await fetch(`/api/retry-download/${downloadId}`, {
        method: 'POST'
      })
      if (res.ok) {
        updateDownload(downloadId, { status: 'queued', error: null })
      }
    } catch (error) {
      console.error('Retry error:', error)
    }
  }

  const handleCancel = async (downloadId) => {
    try {
      const res = await fetch(`/api/cancel-download/${downloadId}`, {
        method: 'POST'
      })
      if (res.ok) {
        updateDownload(downloadId, { status: 'cancelled' })
      }
    } catch (error) {
      console.error('Cancel error:', error)
    }
  }

  return (
    <div className="space-y-8">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="neon-text text-3xl font-bold">Download Progress</h1>
          <p className="text-neon-blue/60 text-sm mt-1">
            {state.songs.length} songs • {state.playlistUrl}
          </p>
        </div>
        <div className="flex gap-3">
          <button
            onClick={() => setView(view === 'downloads' ? 'history' : 'downloads')}
            className="px-4 py-2 rounded-lg bg-neon-purple/20 border border-neon-purple/50 text-neon-purple hover:bg-neon-purple/30"
          >
            {view === 'downloads' ? 'View History' : 'View Downloads'}
          </button>
          <button
            onClick={onBack}
            className="px-4 py-2 rounded-lg bg-neon-blue/20 border border-neon-blue/50 text-neon-blue hover:bg-neon-blue/30"
          >
            New Playlist
          </button>
        </div>
      </div>

      <div className="grid grid-cols-4 gap-4">
        <ProgressCard
          label="Total Songs"
          value={state.stats.total}
          color="neon-blue"
        />
        <ProgressCard
          label="Downloaded"
          value={state.stats.completed}
          color="neon-green"
        />
        <ProgressCard
          label="Failed"
          value={state.stats.failed}
          color="neon-pink"
        />
        <ProgressCard
          label="Current"
          value={state.stats.current_song || 'Waiting...'}
          color="neon-purple"
          isText
        />
      </div>

      {view === 'downloads' ? (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2">
            <SongList
              downloads={state.downloads}
              onRetry={handleRetry}
              onCancel={handleCancel}
            />
          </div>

          <div className="glass p-6 rounded-xl">
            <h3 className="neon-text text-lg font-bold mb-4">Queue ({queue.length})</h3>
            <div className="space-y-2 max-h-96 overflow-y-auto">
              {queue.length === 0 ? (
                <div className="text-neon-blue/40 text-sm">All done!</div>
              ) : (
                queue.map((song, idx) => (
                  <div
                    key={idx}
                    className="p-2 bg-dark-tertiary/50 rounded text-sm text-neon-blue/70 border-l-2 border-neon-blue/30"
                  >
                    {idx === 0 ? '▶' : idx + 1}. {song.substring(0, 40)}
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      ) : (
        <DownloadHistory />
      )}
    </div>
  )
}
