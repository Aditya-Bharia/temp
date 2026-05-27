import { useState, useEffect } from 'react'

export default function useWebSocket(url) {
  const [ws, setWs] = useState(null)
  const [isConnected, setIsConnected] = useState(false)


  useEffect(() => {
    let websocket = null;
    let reconnectTimeout = null;

    function cleanup() {
      if (websocket) {
        websocket.onopen = null;
        websocket.onclose = null;
        websocket.onerror = null;
        websocket.close();
      }
      if (reconnectTimeout) {
        clearTimeout(reconnectTimeout);
      }
    }

    function connect() {
      websocket = new WebSocket(url);

      websocket.onopen = () => {
        console.log('WebSocket connected');
        setIsConnected(true);
      };

      websocket.onclose = () => {
        console.log('WebSocket disconnected');
        setIsConnected(false);
        // Reconnect after 3 seconds
        reconnectTimeout = setTimeout(() => {
          connect();
        }, 3000);
      };

      websocket.onerror = (error) => {
        console.error('WebSocket error:', error);
      };

      setWs(websocket);
    }

    connect();

    return () => {
      cleanup();
    };
  }, [url]);

  return ws
}
