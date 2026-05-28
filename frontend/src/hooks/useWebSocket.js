import { useState, useEffect, useRef, useCallback } from 'react'

export default function useWebSocket(url) {
  const wsRef = useRef(null)
  const [isConnected, setIsConnected] = useState(false)
  const reconnectRef = useRef({ attempts: 0, timer: null })

  const connect = useCallback(() => {
    if (wsRef.current && (wsRef.current.readyState === WebSocket.OPEN || wsRef.current.readyState === WebSocket.CONNECTING)) return

    const ws = new WebSocket(url)
    wsRef.current = ws

    ws.onopen = () => {
      reconnectRef.current.attempts = 0
      setIsConnected(true)
    }

    ws.onclose = () => {
      setIsConnected(false)
      // Exponential backoff reconnect
      reconnectRef.current.attempts += 1
      const delay = Math.min(30000, 1000 * 2 ** (reconnectRef.current.attempts - 1))
      reconnectRef.current.timer = setTimeout(() => connect(), delay)
    }

    ws.onerror = (err) => {
      console.error('WebSocket error', err)
    }
  }, [url])

  useEffect(() => {
    connect()
    return () => {
      if (reconnectRef.current.timer) clearTimeout(reconnectRef.current.timer)
      if (wsRef.current) {
        wsRef.current.onopen = null
        wsRef.current.onclose = null
        wsRef.current.onerror = null
        try { wsRef.current.close() } catch (e) {}
      }
    }
  }, [connect])

  const send = useCallback((data) => {
    const ws = wsRef.current
    if (!ws || ws.readyState !== WebSocket.OPEN) return false
    try {
      ws.send(typeof data === 'string' ? data : JSON.stringify(data))
      return true
    } catch (e) {
      console.error('WebSocket send failed', e)
      return false
    }
  }, [])

  return { send, isConnected, raw: wsRef }
}
