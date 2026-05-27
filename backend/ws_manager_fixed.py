# ============================================================================
# 5. ws_manager.py - FIXED WITH ERROR TRACKING AND CLEANUP
# ============================================================================

import json
import logging
from typing import Set

logger = logging.getLogger(__name__)

class WebSocketManager:
    """Manages WebSocket connections with proper error handling"""

    def __init__(self):
        self.active_connections: Set = set()

    async def connect(self, websocket):
        """Register a new WebSocket connection"""
        await websocket.accept()
        self.active_connections.add(websocket)
        logger.debug(f"WebSocket connected. Total connections: {len(self.active_connections)}")

    def disconnect(self, websocket):
        """Unregister a WebSocket connection"""
        self.active_connections.discard(websocket)
        logger.debug(f"WebSocket disconnected. Total connections: {len(self.active_connections)}")

    async def broadcast(self, message: dict):
        """Broadcast message to all connected clients with error tracking"""
        if not message:
            logger.warning("Empty message received for broadcast")
            return

        failed_connections = []

        for connection in self.active_connections.copy():  # Copy to avoid set mutation during iteration
            try:
                await connection.send_json(message)
            except Exception as e:
                logger.debug(f"Failed to send to client: {e}")
                failed_connections.append(connection)

        # Clean up failed connections
        for conn in failed_connections:
            self.disconnect(conn)

    async def send_progress(self, download_id: int, status: str, progress: int, speed: float, eta: float):
        """Send download progress update"""
        message = {
            "type": "progress",
            "download_id": download_id,
            "status": status,
            "progress": max(0, min(progress, 100)),  # Ensure 0-100 range
            "speed_mbps": round(max(0, speed), 2),
            "eta_seconds": max(0, int(eta))
        }
        await self.broadcast(message)

    async def send_download_complete(self, download_id: int, file_path: str):
        """Send download completion notification"""
        message = {
            "type": "download_complete",
            "download_id": download_id,
            "file_path": file_path
        }
        await self.broadcast(message)

    async def send_error(self, download_id: int, error: str):
        """Send error notification"""
        message = {
            "type": "error",
            "download_id": download_id,
            "error": str(error)[:500]  # Limit error length
        }
        await self.broadcast(message)

    async def send_stats(self, total: int, completed: int, failed: int, current_song: str):
        """Send overall statistics"""
        message = {
            "type": "stats",
            "total": max(0, total),
            "completed": max(0, completed),
            "failed": max(0, failed),
            "current_song": str(current_song)[:200]
        }
        await self.broadcast(message)

# Singleton instance
manager = WebSocketManager()
