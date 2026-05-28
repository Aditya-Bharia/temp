import React, { createContext, useReducer, useEffect, useCallback } from 'react'

export const DownloadContext = createContext()

const STORAGE_KEY = 'music_downloader_state'
const PERSIST_THROTTLE = 500

const initialState = {
  playlistId: null,
  playlistUrl: '',
  songs: [],
  downloads: [],
  stats: {
    total: 0,
    completed: 0,
    failed: 0,
    current_song: ''
  },
  history: []
}

function downloadReducer(state, action) {
  switch (action.type) {
    case 'SET_PLAYLIST':
      return {
        ...state,
        playlistId: action.payload.id,
        playlistUrl: action.payload.url,
        songs: action.payload.songs,
        stats: {
          total: action.payload.total,
          completed: 0,
          failed: 0,
          current_song: ''
        }
      }

    case 'ADD_DOWNLOAD':
      return {
        ...state,
        downloads: [...state.downloads, action.payload]
      }

    case 'UPDATE_DOWNLOAD':
      return {
        ...state,
        downloads: state.downloads.map(d =>
          d.id === action.payload.id ? { ...d, ...action.payload.updates } : d
        )
      }

    case 'UPDATE_STATS':
      return {
        ...state,
        stats: { ...state.stats, ...action.payload }
      }

    case 'ADD_TO_HISTORY':
      const newHistory = [action.payload, ...state.history].slice(0, 100)
      return {
        ...state,
        history: newHistory
      }

    case 'CLEAR_DOWNLOADS':
      return {
        ...state,
        downloads: [],
        songs: [],
        playlistId: null
      }

    case 'RESTORE_STATE':
      return action.payload

    default:
      return state
  }
}

export function DownloadProvider({ children }) {
  const [state, dispatch] = useReducer(downloadReducer, initialState)

  // Load state from localStorage
  useEffect(() => {
    const saved = localStorage.getItem(STORAGE_KEY)
    if (saved) {
      try {
        const parsed = JSON.parse(saved)
        dispatch({ type: 'RESTORE_STATE', payload: parsed })
      } catch (e) {
        console.error('Failed to restore state:', e)
      }
    }
  }, [])

  // Persist state to localStorage with throttling
  useEffect(() => {
    const timer = setTimeout(() => {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state))
    }, PERSIST_THROTTLE)

    return () => clearTimeout(timer)
  }, [state])

  const setPlaylist = useCallback((id, url, songs, total) => {
    dispatch({
      type: 'SET_PLAYLIST',
      payload: { id, url, songs, total }
    })
  }, [])

  const addDownload = useCallback((download) => {
    dispatch({ type: 'ADD_DOWNLOAD', payload: download })
  }, [])

  const updateDownload = useCallback((id, updates) => {
    dispatch({ type: 'UPDATE_DOWNLOAD', payload: { id, updates } })
  }, [])

  const updateStats = useCallback((stats) => {
    dispatch({ type: 'UPDATE_STATS', payload: stats })
  }, [])

  const addToHistory = useCallback((entry) => {
    dispatch({ type: 'ADD_TO_HISTORY', payload: entry })
  }, [])

  const clearDownloads = useCallback(() => {
    dispatch({ type: 'CLEAR_DOWNLOADS' })
  }, [])

  const value = {
    state,
    setPlaylist,
    addDownload,
    updateDownload,
    updateStats,
    addToHistory,
    clearDownloads
  }

  return (
    <DownloadContext.Provider value={value}>
      {children}
    </DownloadContext.Provider>
  )
}

export function useDownloadContext() {
  const context = React.useContext(DownloadContext)
  if (!context) {
    throw new Error('useDownloadContext must be used within DownloadProvider')
  }
  return context
}
