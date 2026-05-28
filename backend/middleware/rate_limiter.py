import time
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse
from typing import Dict

class RateLimiterMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, max_requests: int = 60, window_seconds: int = 60):
        super().__init__(app)
        self.max_requests = max_requests
        self.window = window_seconds
        self.clients: Dict[str, Dict[str, int]] = {}

    async def dispatch(self, request: Request, call_next):
        # Use client IP - fallback to unknown
        client = request.client.host if request.client else "unknown"
        now = int(time.time())
        data = self.clients.get(client)
        if not data or now - data.get("start", 0) > self.window:
            # reset window
            self.clients[client] = {"count": 1, "start": now}
        else:
            data["count"] += 1
            if data["count"] > self.max_requests:
                return JSONResponse({"detail": "Too many requests"}, status_code=429)
        return await call_next(request)
