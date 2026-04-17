import datetime
import hashlib
import os
import re
from pathlib import Path

_INVALID_CHARS_WIN = r'<>:"/\\|?*\x00-\x1F'
_INVALID_RE = re.compile(f'[{_INVALID_CHARS_WIN}]')

def sanitize_filename(name: str, keep_extension=True, drop_non_bmp=True, maxlen=240) -> str:
    if not isinstance(name, str):
        name = str(name)
    if drop_non_bmp:
        name = "".join(ch for ch in name if ord(ch) <= 0xFFFF)
    name = _INVALID_RE.sub("_", name)
    if keep_extension:
        base, ext = os.path.splitext(name)
        base = base[:maxlen] or "file"
        return base + ext
    else:
        name = name[:maxlen] or "file"
        return name

def safe_write_text(path: str | os.PathLike, text: str, *, encoding="utf-8"):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "w", encoding=encoding, errors="replace") as f:
        f.write(text)

def safe_read_text(path: str | os.PathLike, *, encoding="utf-8") -> str:
    with open(path, "r", encoding=encoding, errors="replace") as f:
        return f.read()

def sizeof_fmt(num, suffix="B"):
  for unit in ("", "Ki", "Mi", "Gi", "Ti", "Pi", "Ei", "Zi"):
    if abs(num) < 1024.0:
      return f"{num:3.1f}{unit}{suffix}"
    num /= 1024.0
  return f"{num:.1f}Yi{suffix}"

def convert_isoformat_date(strdate):
  return datetime.datetime.strptime(strdate, "%Y-%m-%dT%H:%M:%S.%fZ")

def get_file_sha512(filename):
  h  = hashlib.sha512()
  b  = bytearray(128*1024)
  mv = memoryview(b)
  with open(filename, 'rb', buffering=0) as f:
    while n := f.readinto(mv):
      h.update(mv[:n])
  return h.hexdigest()
