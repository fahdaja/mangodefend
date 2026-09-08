#!/bin/sh
set -e

# 1. Jalankan Background Worker di background process (&)
echo "[MangoDefend] Starting Background Worker in background..."
python -m app.src.engine.worker &

# 2. Jalankan Uvicorn API Server di foreground
echo "[MangoDefend] Starting Uvicorn API Server on port ${PORT:-8000}..."
exec uvicorn app.src.main:app --host 0.0.0.0 --port "${PORT:-8000}"
