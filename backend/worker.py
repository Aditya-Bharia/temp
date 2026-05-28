import logging
from rq import Worker
from .queue import redis_conn, download_queue
from .settings import Settings

settings = Settings()
logging.basicConfig(level=settings.log_level)
logger = logging.getLogger(__name__)

if __name__ == "__main__":
    worker = Worker([download_queue], name="download-worker", connection=redis_conn)
    logger.info("Starting RQ worker")
    worker.work(logging_level=settings.log_level)
