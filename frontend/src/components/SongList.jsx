import React from 'react'

export default function SongList({ downloads }) {
  const getStatusColor = (status) => {
    switch (status) {
      case 'completed':
        return 'bg-green-500/20 border-green-500/50 text-green-400'
      case 'failed':
        return 'bg-red-500/20 border-red-500/50 text-red-400'
      case 'downloading':
        return 'bg-neon-blue/20 border-neon-blue/50 text-neon-blue'
      default:
        return 'bg-neon-purple/20 border-neon-purple/50 text-neon-purple'
    }
  }

  const getStatusIcon = (status) => {
    switch (status) {
      case 'completed':
        return '✓'
      case 'failed':
        return '✗'
      case 'downloading':
        return '⟳'
      default:
        return '○'
    }
  }

  return (
    <div className="glass p-6 rounded-xl">
      <h3 className="neon-text text-lg font-bold mb-4">Downloads</h3>
      <div className="space-y-3 max-h-96 overflow-y-auto">
        {downloads.length === 0 ? (
          <div className="text-neon-blue/40 text-sm text-center py-8">
            Ready to download...
          </div>
        ) : (
          downloads.map((d) => (
            <div
              key={d.id}
              className={`p-4 border rounded-lg ${getStatusColor(d.status)}`}
            >
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <span className="font-bold text-lg">{getStatusIcon(d.status)}</span>
                  <span className="text-sm font-mono truncate">{d.song.substring(0, 40)}</span>
                </div>
                <span className="text-xs px-2 py-1 bg-black/30 rounded">
                  {d.progress}%
                </span>
              </div>

              {d.status === 'downloading' && (
                <>
                  <div className="w-full bg-black/30 rounded-full h-2 mb-2 overflow-hidden">
                    <div
                      className="progress-bar-animated h-full"
                      style={{ width: `${d.progress}%` }}
                    />
                  </div>
                  <div className="flex justify-between text-xs text-neon-blue/70">
                    <span>{d.speed?.toFixed(2)} MB/s</span>
                    <span>ETA: {d.eta}s</span>
                  </div>
                </>
              )}

              {d.error && (
                <div className="text-xs text-red-300 mt-2">
                  {d.error}
                </div>
              )}
            </div>
          ))
        )}
      </div>
    </div>
  )
}
