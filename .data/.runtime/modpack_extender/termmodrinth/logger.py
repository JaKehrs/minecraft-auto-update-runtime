import datetime
import os
import sys
from termcolor import colored
from termmodrinth.singleton import Singleton

# ---- Console encoding hardening (Windows-friendly) ----
try:
    # Versuche UTF-8 + "replace" zu erzwingen, damit Emojis & Co. nie crashen
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

# Fallback-Umgebungsvariablen (stören nicht, wenn schon gesetzt)
os.environ.setdefault("PYTHONUTF8", "1")
os.environ.setdefault("PYTHONIOENCODING", "utf-8")


def _to_str(x) -> str:
    if isinstance(x, str):
        return x
    return str(x)


def safe_print(*parts, sep=" ", end="\n"):
    """
    Schreibt immer in die Konsole, ohne Encoding-Fehler zu werfen.
    Nutzt die tatsächliche stdout-Encoding (oder utf-8) und errors='replace'.
    """
    msg = sep.join(_to_str(p) for p in parts)
    enc = getattr(sys.stdout, "encoding", None) or "utf-8"
    try:
        # direkt in den Buffer schreiben, um Python-Print-Codec zu umgehen
        sys.stdout.buffer.write(msg.encode(enc, errors="replace"))
        sys.stdout.buffer.write(end.encode(enc, errors="replace"))
        sys.stdout.flush()
    except Exception:
        # letzte Rettung
        try:
            print(msg.encode("utf-8", "replace").decode("utf-8", "replace"), end=end)
        except Exception:
            # wenn selbst das fehlschlägt, ohne Farben/sondern nur ASCII
            ascii_msg = msg.encode("ascii", "replace").decode("ascii", "replace")
            print(ascii_msg, end=end)


class Logger(Singleton):
    levels = {
        'inf': 'green',
        'wrn': 'yellow',
        'err': 'red',
    }

    def _timestamp(self):
        return colored(datetime.datetime.now().strftime("%H:%M:%S"), 'blue')

    def _level(self, level):
        return colored(level, self.levels.get(level, 'white'))

    def log(self, level, msg, color):
        safe_print(
            "[{}] [{}] {}".format(
                self._timestamp(),
                self._level(level),
                colored(_to_str(msg), color)
            )
        )

    def projectLog(self, level, project_type, slug, msg, msg_color='white'):
        safe_print(
            "[{}] [{}] {}: {}".format(
                self._timestamp(),
                self._level(level),
                colored(f'{_to_str(project_type)}:{_to_str(slug)}', "magenta"),
                colored(_to_str(msg), msg_color)
            )
        )
