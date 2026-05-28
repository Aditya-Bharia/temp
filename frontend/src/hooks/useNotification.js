import React, { useCallback, useState, useRef } from 'react'

export function useNotification() {
  const [notifications, setNotifications] = useState([])
  const notificationTimeoutsRef = useRef({})

  const addNotification = useCallback((message, type = 'info', duration = 5000) => {
    const id = Date.now()
    const notification = { id, message, type }

    setNotifications(prev => [...prev, notification])

    if (duration > 0) {
      const timeout = setTimeout(() => {
        setNotifications(prev => prev.filter(n => n.id !== id))
        delete notificationTimeoutsRef.current[id]
      }, duration)

      notificationTimeoutsRef.current[id] = timeout
    }

    return id
  }, [])

  const removeNotification = useCallback((id) => {
    setNotifications(prev => prev.filter(n => n.id !== id))
    if (notificationTimeoutsRef.current[id]) {
      clearTimeout(notificationTimeoutsRef.current[id])
      delete notificationTimeoutsRef.current[id]
    }
  }, [])

  const clearAll = useCallback(() => {
    Object.values(notificationTimeoutsRef.current).forEach(timeout => clearTimeout(timeout))
    notificationTimeoutsRef.current = {}
    setNotifications([])
  }, [])

  return {
    notifications,
    addNotification,
    removeNotification,
    clearAll
  }
}

export const NotificationContext = React.createContext()

export function useNotificationContext() {
  const context = React.useContext(NotificationContext)
  if (!context) {
    throw new Error('useNotificationContext must be used within NotificationProvider')
  }
  return context
}

