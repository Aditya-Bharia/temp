import React from 'react'

export default function NotificationDisplay({ notifications, onRemove }) {
  const getColorClasses = (type) => {
    switch (type) {
      case 'success':
        return 'bg-neon-green/20 border-neon-green/50 text-neon-green'
      case 'error':
        return 'bg-neon-pink/20 border-neon-pink/50 text-neon-pink'
      case 'warning':
        return 'bg-neon-purple/20 border-neon-purple/50 text-neon-purple'
      default:
        return 'bg-neon-blue/20 border-neon-blue/50 text-neon-blue'
    }
  }

  return (
    <div className="fixed top-4 right-4 z-50 space-y-2 max-w-md">
      {notifications.map(notif => (
        <div
          key={notif.id}
          className={`glass p-4 rounded-lg border animate-fade-in ${getColorClasses(notif.type)}`}
        >
          <div className="flex justify-between items-start gap-4">
            <div className="flex-1">{notif.message}</div>
            <button
              onClick={() => onRemove(notif.id)}
              className="text-lg hover:opacity-70 transition"
            >
              ✕
            </button>
          </div>
        </div>
      ))}
    </div>
  )
}
