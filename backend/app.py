from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware import Middleware
from .logging_config import configure_logging
from .settings import Settings
from .middleware.rate_limiter import RateLimiterMiddleware
from .models import init_db
from .recovery import recover_unfinished_downloads, cleanup_orphan_temp_files
from .pubsub import start_pubsub_listener
import logging
from prometheus_client import make_asgi_app
from starlette.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException
from fastapi.exceptions import RequestValidationError
import asyncio

_settings = Settings()

configure_logging(_settings.log_level)
logger = logging.getLogger(__name__)

middleware = [
    Middleware(RateLimiterMiddleware, max_requests=60, window_seconds=60),
]

app = FastAPI(title=_settings.app_name, middleware=middleware)

# CORS
allowed = [o.strip() for o in _settings.allowed_origins.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

# Prometheus metrics mounted at /metrics
app.mount("/metrics", make_asgi_app())


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    logger.warning("HTTP error %s %s", exc.status_code, exc.detail)
    return JSONResponse({"detail": exc.detail}, status_code=exc.status_code)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    logger.warning("Validation error: %s", exc.errors())
    return JSONResponse({"detail": exc.errors()}, status_code=422)


@app.on_event("startup")
async def on_startup():
    logger.info("Starting application")
    init_db()
    cleanup_orphan_temp_files()
    recover_unfinished_downloads()
    app.state.pubsub_task = asyncio.create_task(start_pubsub_listener())


@app.on_event("shutdown")
async def on_shutdown():
    logger.info("Shutting down application")
    task = getattr(app.state, "pubsub_task", None)
    if task is not None:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass


# include API routes
from . import api  # noqa: E402,F401
app.include_router(api.router, prefix="/api")

# expose ASGI app for uvicorn
__all__ = ["app"]
