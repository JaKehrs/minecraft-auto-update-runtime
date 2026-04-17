#!/usr/bin/env python3
# -*- coding: utf8 -*-
# --- force UTF-8 console on Windows ---
import os, sys
try:
    # Python 3.7+: reconfigure verfügbar
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

# Fallback-Umgebungsvariablen; harmless wenn schon UTF-8 aktiv
os.environ.setdefault("PYTHONUTF8", "1")
os.environ.setdefault("PYTHONIOENCODING", "utf-8")
# --- end UTF-8 shim ---

# from termmodrinth.modrinth.api import ModrinthAPI
from termmodrinth.worker import Worker

if __name__ == "__main__":
  Worker().run()
