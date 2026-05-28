import re
from pathlib import Path

def sanitize_filename(name: str, max_length: int = 255) -> str:
    # Remove path separators and unsafe chars
    base = Path(name).name
    safe = re.sub(r"[^0-9A-Za-z. _-]", "_", base)
    return safe[:max_length]
