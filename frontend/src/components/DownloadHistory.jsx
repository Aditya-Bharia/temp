import React, { useState } from 'react'
import { useDownloadContext } from '../context/DownloadContext'

export default function DownloadHistory() {
  const { state } = useDownloadContext()
  const [filter, setFilter] = useState('all')

  const filtered = state.history.filter(entry => {
    if (filter === 'all') return true
    return entry.status === filter
  })

  const stats = {
    total: state.history.length,
    completed: state.history.filter(e => e.status === 'completed').length,
    failed: state.history.filter(e => e.status === 'failed').length,
    success_rate: state.history.length > 0
      ? Math.round((state.history.filter(e => e.status === 'completed').length / state.history.length) * 100)
      : 0
  }

  return (
    <div className="glass p-6 rounded-xl">
      <h2 className="neon-text text-2xl font-bold mb-6">Download History</h2>

      <div className="grid grid-cols-4 gap-4 mb-6">
        <div className="bg-dark-tertiary/50 p-4 rounded-lg">
          <div className="text-neon-blue/60 text-sm">Total</div>
          <div className="text-2xl font-bold text-neon-blue">{stats.total}</div>
        </div>
        <div className="bg-dark-tertiary/50 p-4 rounded-lg">
          <div className="text-neon-green/60 text-sm">Completed</div>
          <div className="text-2xl font-bold text-neon-green">{stats.completed}</div>
        </div>
        <div className="bg-dark-tertiary/50 p-4 rounded-lg">
          <div className="text-neon-pink/60 text-sm">Failed</div>
          <div className="text-2xl font-bold text-neon-pink">{stats.failed}</div>
        </div>
        <div className="bg-dark-tertiary/50 p-4 rounded-lg">
          <div className="text-neon-purple/60 text-sm">Success Rate</div>
          <div className="text-2xl font-bold text-neon-purple">{stats.success_rate}%</div>
        </div>
      </div>

      <div className="flex gap-2 mb-6">
        {['all', 'completed', 'failed'].map(f => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition ${
              filter === f
                ? 'bg-neon-blue/30 border border-neon-blue text-neon-blue'
                : 'bg-dark-tertiary/50 border border-transparent text-neon-blue/60 hover:border-neon-blue/50'
            }`}
          >
            {f.charAt(0).toUpperCase() + f.slice(1)}
          </button>
        ))}
      </div>

      <div className="space-y-2 max-h-96 overflow-y-auto">
        {filtered.length === 0 ? (
          <div className="text-neon-blue/40 text-sm py-8 text-center">
            No downloads yet
          </div>
        ) : (
          filtered.map(entry => (
            <div
              key={`${entry.id}-${entry.timestamp}`}
              className={`p-4 rounded-lg border-l-4 ${
                entry.status === 'completed'
                  ? 'bg-neon-green/5 border-neon-green/50'
                  : 'bg-neon-pink/5 border-neon-pink/50'
              }`}
            >
              <div className="flex justify-between items-start">
                <div>
                  <div className="text-neon-blue font-medium">{entry.song}</div>
                  <div className="text-xs text-neon-blue/40 mt-1">
                    {entry.provider && `Provider: ${entry.provider}`}
                  </div>
                </div>
                <div className="text-right">
                  <div className={`text-sm font-medium ${
                    entry.status === 'completed' ? 'text-neon-green' : 'text-neon-pink'
                  }`}>
                    {entry.status.toUpperCase()}
                  </div>
                  <div className="text-xs text-neon-blue/40 mt-1">
                    {new Date(entry.timestamp).toLocaleString()}
                  </div>
                </div>
              </div>
              {entry.error && (
                <div className="text-xs text-neon-pink/70 mt-2">
                  Error: {entry.error}
                </div>
              )}
            </div>
          ))
        )}
      </div>
    </div>
  )
}
