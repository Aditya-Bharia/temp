import React, { useState, useEffect } from 'react'

export default function SettingsPage() {
  const [settings, setSettings] = useState(null)
  const [loading, setLoading] = useState(true)
  const [saved, setSaved] = useState(false)

  useEffect(() => {
    fetchSettings()
  }, [])

  const fetchSettings = async () => {
    try {
      const res = await fetch('/api/settings')
      const data = await res.json()
      setSettings(data)
    } catch (error) {
      console.error('Failed to fetch settings:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleChange = (key, value) => {
    setSettings(prev => ({ ...prev, [key]: value }))
    setSaved(false)
  }

  const handleSave = async () => {
    try {
      const res = await fetch('/api/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(settings)
      })
      if (res.ok) {
        setSaved(true)
        setTimeout(() => setSaved(false), 3000)
      }
    } catch (error) {
      console.error('Failed to save settings:', error)
    }
  }

  if (loading || !settings) {
    return <div className="text-neon-blue">Loading...</div>
  }

  return (
    <div className="glass p-6 rounded-xl max-w-2xl">
      <h2 className="neon-text text-2xl font-bold mb-6">Settings</h2>

      <div className="space-y-6">
        <div>
          <label className="block text-neon-blue/80 mb-2 font-medium">Audio Quality</label>
          <select
            value={settings.audio_quality}
            onChange={(e) => handleChange('audio_quality', e.target.value)}
            className="input-neon w-full"
          >
            <option value="low">Low (128 kbps)</option>
            <option value="medium">Medium (192 kbps)</option>
            <option value="high">High (320 kbps)</option>
          </select>
        </div>

        <div>
          <label className="block text-neon-blue/80 mb-2 font-medium">Output Format</label>
          <select
            value={settings.output_format}
            onChange={(e) => handleChange('output_format', e.target.value)}
            className="input-neon w-full"
          >
            <option value="mp3">MP3</option>
            <option value="m4a">M4A</option>
            <option value="wav">WAV</option>
          </select>
        </div>

        <div>
          <label className="block text-neon-blue/80 mb-2 font-medium">Auto Retry Failed Downloads</label>
          <input
            type="checkbox"
            checked={settings.auto_retry}
            onChange={(e) => handleChange('auto_retry', e.target.checked)}
            className="w-4 h-4"
          />
        </div>

        <div>
          <label className="block text-neon-blue/80 mb-2 font-medium">Max Retries</label>
          <input
            type="number"
            min="1"
            max="10"
            value={settings.max_retries}
            onChange={(e) => handleChange('max_retries', parseInt(e.target.value))}
            className="input-neon w-full"
          />
        </div>

        <div>
          <label className="block text-neon-blue/80 mb-2 font-medium">Concurrent Downloads</label>
          <input
            type="number"
            min="1"
            max="5"
            value={settings.concurrent_downloads}
            onChange={(e) => handleChange('concurrent_downloads', parseInt(e.target.value))}
            className="input-neon w-full"
          />
        </div>

        <div className="space-y-2">
          <label className="block text-neon-blue/80 mb-2 font-medium">Available Providers</label>
          <div className="grid grid-cols-2 gap-2">
            {settings.providers.map(provider => (
              <div key={provider} className="text-neon-blue/70 text-sm p-2 bg-dark-tertiary/50 rounded">
                ✓ {provider.charAt(0).toUpperCase() + provider.slice(1)}
              </div>
            ))}
          </div>
        </div>

        <button
          onClick={handleSave}
          className="btn-neon w-full"
        >
          {saved ? 'Saved!' : 'Save Settings'}
        </button>
      </div>
    </div>
  )
}
