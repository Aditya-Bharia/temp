from redis import Redis
from rq import Queue
from .settings import Settings

_settings = Settings()

redis_conn = Redis.from_url(_settings.redis_url, decode_responses=True)
download_queue = Queue("downloads", connection=redis_conn, default_timeout=_settings.task_timeout)
