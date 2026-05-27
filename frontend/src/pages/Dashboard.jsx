import React, { useState, useEffect } from 'react'
import ProgressCard from '../components/ProgressCard'
import SongList from '../components/SongList'

export default function Dashboard({ playlistId, songs, stats, ws }) {
  const [downloads, setDownloads] = useState([])
  const [downloading, setDownloading] = useState(false)
  const [queue, setQueue] = useState(songs)

  useEffect(() => {
    if (!downloading && queue.length > 0) {
      const nextSong = queue[0]
      queueDownload(nextSong)
    }
  }, [downloading, queue])

  useEffect(() => {
    const handleWsMessage = (event) => {
      try {
        const data = JSON.parse(event.data)

        if (data.type === 'progress') {
          setDownloads(prev => prev.map(d =>
            d.id === data.download_id
              ? {
                  ...d,
                  progress: data.progress,
                  speed: data.speed_mbps,
                  eta: data.eta_seconds,
                  status: data.status
                }
              : d
          ))
        } else if (data.type === 'download_complete') {
          setDownloads(prev => prev.map(d =>
            d.id === data.download_id
              ? { ...d, status: 'completed', progress: 100 }
              : d
          ))
          setQueue(prev => prev.slice(1))
          setDownloading(false)
        } else if (data.type === 'error') {
          setDownloads(prev => prev.map(d =>
            d.id === data.download_id
              ? { ...d, status: 'failed', error: data.error }
              : d
          ))
          setQueue(prev => prev.slice(1))
          setDownloading(false)
        }
      } catch (e) {
        console.error('WS error:', e)
      }
    }

    if (ws) {
      ws.addEventListener('message', handleWsMessage)
      return () => ws.removeEventListener('message', handleWsMessage)
    }
  }, [ws])

  const queueDownload = async (songName) => {
    try {
      setDownloading(true)

      // Queue the download
      const queueRes = await fetch('/api/queue-downloads', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          playlist_id: playlistId,
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

      setDownloads(prev => [...prev, {
        id: downloadId,
        song: songName,
        status: 'queued',
        progress: 0,
        speed: 0,
        eta: 0
      }])

      // Start download
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

  return (
    <div className="space-y-8">
      <div className="grid grid-cols-4 gap-4">
        <ProgressCard
          label="Total Songs"
          value={stats.total}
          color="neon-blue"
        />
        <ProgressCard
          label="Downloaded"
          value={stats.completed}
          color="neon-green"
        />
        <ProgressCard
          label="Failed"
          value={stats.failed}
          color="neon-pink"
        />
        <ProgressCard
          label="Current"
          value={stats.current_song || 'Waiting...'}
          color="neon-purple"
          isText
        />
      </div>

      <div className="grid grid-cols-3 gap-6">
        <div className="col-span-2">
          <SongList downloads={downloads} />
        </div>

        <div className="glass p-6 rounded-xl">
          <h3 className="neon-text text-lg font-bold mb-4">Queue</h3>
          <div className="space-y-2 max-h-96 overflow-y-auto">
            {queue.length === 0 ? (
              <div className="text-neon-blue/40 text-sm">
                All done!
              </div>
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
    </div>
  )
}
