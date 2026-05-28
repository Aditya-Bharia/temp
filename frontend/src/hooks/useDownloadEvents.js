import { useCallback, useRef } from 'react'
import { useDownloadContext } from '../context/DownloadContext'

export function useDownloadEvents() {
  const { updateDownload, updateStats, addToHistory } = useDownloadContext()
  const pendingUpdatesRef = useRef(new Map())

  const applyOptimistic = useCallback((downloadId, updates) => {
    pendingUpdatesRef.current.set(downloadId, updates)
    updateDownload(downloadId, updates)
  }, [updateDownload])

  const confirmUpdate = useCallback((downloadId, updates) => {
    pendingUpdatesRef.current.delete(downloadId)
    updateDownload(downloadId, updates)
  }, [updateDownload])

  const handleProgressEvent = useCallback((data) => {
    confirmUpdate(data.download_id, {
      progress: data.progress,
      speed: data.speed_mbps,
      eta: data.eta_seconds,
      status: data.status
    })
  }, [confirmUpdate])

  const handleCompleteEvent = useCallback((data) => {
    confirmUpdate(data.download_id, {
      status: 'completed',
      progress: 100,
      completed_at: new Date().toISOString()
    })
    addToHistory({
      id: data.download_id,
      song: data.song_name,
      status: 'completed',
      timestamp: new Date().toISOString(),
      provider: data.provider
    })
  }, [confirmUpdate, addToHistory])

  const handleErrorEvent = useCallback((data) => {
    confirmUpdate(data.download_id, {
      status: 'failed',
      error: data.error,
      retry_count: (data.retry_count || 0) + 1
    })
    addToHistory({
      id: data.download_id,
      song: data.song_name,
      status: 'failed',
      error: data.error,
      timestamp: new Date().toISOString()
    })
  }, [confirmUpdate, addToHistory])

  const handleStatsEvent = useCallback((data) => {
    updateStats({
      total: data.total,
      completed: data.completed,
      failed: data.failed,
      current_song: data.current_song
    })
  }, [updateStats])

  return {
    applyOptimistic,
    handleProgressEvent,
    handleCompleteEvent,
    handleErrorEvent,
    handleStatsEvent
  }
}
