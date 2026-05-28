import React, { useState, useEffect } from 'react'

export default function QueueManager() {
  const [queue, setQueue] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchQueueStatus()
    const interval = setInterval(fetchQueueStatus, 3000)
    return () => clearInterval(interval)
  }, [])

  const fetchQueueStatus = async () => {
    try {
      const res = await fetch('/api/queue-status')
      const data = await res.json()
      setQueue(data)
    } catch (error) {
      console.error('Failed to fetch queue status:', error)
    } finally {
      setLoading(false)
    }
  }

  if (loading || !queue) {
    return <div className="text-neon-blue">Loading queue...</div>
  }

  const getBarColor = (status) => {
    switch (status) {
      case 'queued':
        return 'bg-neon-purple'
      case 'processing':
        return 'bg-neon-blue'
      case 'completed':
        return 'bg-neon-green'
      case 'failed':
        return 'bg-neon-pink'
      default:
        return 'bg-neon-blue'
    }
  }

  const items = [
    { label: 'Queued', value: queue.queued, color: 'neon-purple' },
    { label: 'Processing', value: queue.processing, color: 'neon-blue' },
    { label: 'Completed', value: queue.completed, color: 'neon-green' },
    { label: 'Failed', value: queue.failed, color: 'neon-pink' }
  ]

  const totalProcessed = queue.completed + queue.failed
  const successRate = queue.total > 0 ? Math.round((queue.completed / queue.total) * 100) : 0

  return (
    <div className="glass p-6 rounded-xl">
      <h2 className="neon-text text-2xl font-bold mb-6">Queue Manager</h2>

      <div className="space-y-6">
        <div className="grid grid-cols-4 gap-4">
          {items.map(item => (
            <div key={item.label} className="bg-dark-tertiary/50 p-4 rounded-lg">
              <div className={`text-${item.color}/60 text-sm`}>{item.label}</div>
              <div className={`text-3xl font-bold text-${item.color}`}>{item.value}</div>
            </div>
          ))}
        </div>

        <div>
          <div className="flex justify-between text-sm mb-2">
            <span className="text-neon-blue/80">Overall Progress</span>
            <span className="text-neon-blue/60">{totalProcessed} / {queue.total}</span>
          </div>
          <div className="w-full bg-dark-tertiary/50 rounded-full h-3 overflow-hidden">
            <div
              className="h-full bg-gradient-to-r from-neon-blue to-neon-green transition-all duration-300"
              style={{ width: `${queue.total > 0 ? (totalProcessed / queue.total) * 100 : 0}%` }}
            />
          </div>
          <div className="text-sm text-neon-blue/60 mt-2">
            Success Rate: {successRate}%
          </div>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div className="bg-dark-tertiary/50 p-4 rounded-lg">
            <div className="text-neon-blue/60 text-sm mb-1">Active Downloads</div>
            <div className="text-2xl font-bold text-neon-blue">{queue.active}</div>
          </div>
          <div className="bg-dark-tertiary/50 p-4 rounded-lg">
            <div className="text-neon-blue/60 text-sm mb-1">Total Downloads</div>
            <div className="text-2xl font-bold text-neon-blue">{queue.total}</div>
          </div>
        </div>

        <button
          onClick={fetchQueueStatus}
          className="px-4 py-2 rounded-lg bg-neon-blue/20 border border-neon-blue/50 text-neon-blue hover:bg-neon-blue/30 w-full"
        >
          Refresh
        </button>
      </div>
    </div>
  )
}
