import React, { useState, useEffect } from 'react'

export default function AdminDashboard() {
  const [stats, setStats] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchStats()
    const interval = setInterval(fetchStats, 5000)
    return () => clearInterval(interval)
  }, [])

  const fetchStats = async () => {
    try {
      const res = await fetch('/api/stats')
      const data = await res.json()
      setStats(data)
    } catch (error) {
      console.error('Failed to fetch stats:', error)
    } finally {
      setLoading(false)
    }
  }

  if (loading || !stats) {
    return <div className="text-neon-blue">Loading stats...</div>
  }

  const s = stats.downloads
  return (
    <div className="space-y-6">
      <h2 className="neon-text text-3xl font-bold">System Analytics</h2>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <div className="glass p-6 rounded-xl">
          <div className="text-neon-blue/60 text-sm mb-2">Total Downloads</div>
          <div className="text-4xl font-bold text-neon-blue">{s.total}</div>
          <div className="text-xs text-neon-blue/40 mt-2">
            Completed: {s.completed} | Failed: {s.failed}
          </div>
        </div>

        <div className="glass p-6 rounded-xl">
          <div className="text-neon-green/60 text-sm mb-2">Success Rate</div>
          <div className="text-4xl font-bold text-neon-green">{s.success_rate.toFixed(1)}%</div>
          <div className="text-xs text-neon-green/40 mt-2">
            {s.completed} successful
          </div>
        </div>

        <div className="glass p-6 rounded-xl">
          <div className="text-neon-purple/60 text-sm mb-2">Active Downloads</div>
          <div className="text-4xl font-bold text-neon-purple">{stats.queue.active}</div>
          <div className="text-xs text-neon-purple/40 mt-2">
            Processing + Queued
          </div>
        </div>

        <div className="glass p-6 rounded-xl">
          <div className="text-neon-pink/60 text-sm mb-2">Failed Downloads</div>
          <div className="text-4xl font-bold text-neon-pink">{s.failed}</div>
          <div className="text-xs text-neon-pink/40 mt-2">
            Available for retry
          </div>
        </div>

        <div className="glass p-6 rounded-xl">
          <div className="text-neon-blue/60 text-sm mb-2">Avg Download Time</div>
          <div className="text-4xl font-bold text-neon-blue">
            {s.avg_download_time_seconds ? Math.round(s.avg_download_time_seconds) : 'N/A'}s
          </div>
          <div className="text-xs text-neon-blue/40 mt-2">
            Per completed download
          </div>
        </div>

        <div className="glass p-6 rounded-xl">
          <div className="text-neon-purple/60 text-sm mb-2">Total Playlists</div>
          <div className="text-4xl font-bold text-neon-purple">{stats.playlists.total}</div>
          <div className="text-xs text-neon-purple/40 mt-2">
            Processed
          </div>
        </div>
      </div>

      <div className="glass p-6 rounded-xl">
        <h3 className="neon-text text-lg font-bold mb-4">Download Progress</h3>
        <div className="space-y-2">
          {[
            { label: 'Completed', value: s.completed, color: 'neon-green' },
            { label: 'Processing', value: s.processing, color: 'neon-blue' },
            { label: 'Queued', value: s.queued, color: 'neon-purple' },
            { label: 'Failed', value: s.failed, color: 'neon-pink' }
          ].map((item, idx) => {
            const percentage = s.total > 0 ? (item.value / s.total) * 100 : 0
            return (
              <div key={idx}>
                <div className="flex justify-between text-sm mb-1">
                  <span className={`text-${item.color}/80`}>{item.label}</span>
                  <span className={`text-${item.color}/60`}>
                    {item.value} ({percentage.toFixed(1)}%)
                  </span>
                </div>
                <div className="w-full bg-dark-tertiary/50 rounded-full h-2 overflow-hidden">
                  <div
                    className={`h-full bg-${item.color} transition-all duration-300`}
                    style={{ width: `${percentage}%` }}
                  />
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
