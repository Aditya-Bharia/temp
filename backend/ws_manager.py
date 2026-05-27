import json
from typing import Set

class WebSocketManager:
    def __init__(self):
        self.active_connections: Set = set()

    async def connect(self, websocket):
        await websocket.accept()
        self.active_connections.add(websocket)

    def disconnect(self, websocket):
        self.active_connections.discard(websocket)

    async def broadcast(self, message: dict):
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except Exception:
                pass

    async def send_progress(self, download_id: int, status: str, progress: int, speed: float, eta: float):
        await self.broadcast({
            "type": "progress",
            "download_id": download_id,
            "status": status,
            "progress": progress,
            "speed_mbps": round(speed, 2),
            "eta_seconds": int(eta)
        })

    async def send_download_complete(self, download_id: int, file_path: str):
        await self.broadcast({
            "type": "download_complete",
            "download_id": download_id,
            "file_path": file_path
        })

    async def send_error(self, download_id: int, error: str):
        await self.broadcast({
            "type": "error",
            "download_id": download_id,
            "error": error
        })

    async def send_stats(self, total: int, completed: int, failed: int, current_song: str):
        await self.broadcast({
            "type": "stats",
            "total": total,
            "completed": completed,
            "failed": failed,
            "current_song": current_song
        })

manager = WebSocketManager()
