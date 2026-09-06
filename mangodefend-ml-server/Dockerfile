# ==========================================
# STAGE 1: Builder (Instalasi Dependensi)
# ==========================================
FROM python:3.11-slim AS builder

WORKDIR /app

# Hindari pembuatan file .pyc dan aktifkan unbuffered output
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install system dependencies yang dibutuhkan untuk kompilasi (jika ada)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install virtualenv
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy & Install Python dependencies terlebih dahulu (Agar Layer Caching Maksimal!)
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt


# ==========================================
# STAGE 2: Runner (Runtime Akhir yang Ringan)
# ==========================================
FROM python:3.11-slim AS runner

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    PATH="/opt/venv/bin:$PATH"

# Copy virtual environment dari stage builder
COPY --from=builder /opt/venv /opt/venv

# Buat User Non-Root demi keamanan (Best Practice!)
RUN useradd -m -u 1000 appuser && \
    mkdir -p /app/model_weights && \
    chown -R appuser:appuser /app

# Copy Source Code aplikasi
COPY --chown=appuser:appuser ./app /app/app

# Pindah ke user non-root
USER appuser

# Expose Port HTTP API
EXPOSE 8000

# Command default untuk API Server (Bisa di-override oleh Docker Compose untuk Worker)
CMD ["uvicorn", "app.src.main:app", "--host", "0.0.0.0", "--port", "8000"]
