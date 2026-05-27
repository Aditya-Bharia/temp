import React from 'react'

export default function ProgressCard({ label, value, color, isText }) {
  const colorMap = {
    'neon-blue': 'text-neon-blue from-neon-blue/20',
    'neon-green': 'text-green-400 from-green-500/20',
    'neon-pink': 'text-pink-500 from-pink-500/20',
    'neon-purple': 'text-neon-purple from-neon-purple/20',
  }

  const [textColor, bgColor] = colorMap[color]?.split(' ') || ['text-neon-blue', 'from-neon-blue/20']

  return (
    <div className={`glass p-6 rounded-xl border border-${color}/30 bg-gradient-to-br ${bgColor} to-transparent`}>
      <div className="text-xs text-neon-blue/50 uppercase tracking-wider mb-2">
        {label}
      </div>
      <div className={`text-3xl font-bold ${textColor}`}>
        {isText ? String(value).substring(0, 20) : value}
      </div>
    </div>
  )
}
