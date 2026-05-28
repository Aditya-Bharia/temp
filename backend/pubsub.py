import asyncio
import json
from .queue import redis_conn
from .ws_manager import manager as ws_manager

CHANNEL = "download_events"

async def start_pubsub_listener():
    pubsub = redis_conn.pubsub(ignore_subscribe_messages=True)
    pubsub.subscribe(CHANNEL)

    try:
        while True:
            message = pubsub.get_message(timeout=1.0)
            if message and message.get("type") == "message":
                try:
                    payload = json.loads(message.get("data", "{}"))
                    await ws_manager.broadcast(payload)
                except Exception:
                    pass
            await asyncio.sleep(0.1)
    except asyncio.CancelledError:
        pass
    finally:
        try:
            pubsub.close()
        except Exception:
            pass
