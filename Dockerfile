# =====================================
# STAGE 1: Builder Stage
# =====================================
# This stage installs all dependencies and downloads models
# We use a separate stage to keep the final image smaller

FROM python:3.11-slim AS builder

# Set working directory
WORKDIR /app

# Install system dependencies needed for building Python packages
# gcc, g++: Required to compile Python packages with C extensions (like torch, numpy)
# libpq-dev: PostgreSQL client library headers (needed for psycopg2)
# curl: Useful for health checks and downloading files
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (Docker layer caching optimization)
# If requirements.txt doesn't change, Docker reuses this layer
COPY requirements.txt .

# Upgrade pip and install Python dependencies
# --no-cache-dir: Don't cache pip packages (saves space)
# --upgrade pip: Ensure we have the latest pip version
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Download spaCy English language model
# This is done during build time so the container starts faster
RUN pip install https://github.com/explosion/spacy-models/releases/download/en_core_web_sm-3.7.1/en_core_web_sm-3.7.1-py3-none-any.whl

# =====================================
# STAGE 2: Production Stage
# =====================================
# This stage creates the final lightweight image

FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install only runtime dependencies (not build tools)
# libpq5: PostgreSQL client library (runtime only, smaller than libpq-dev)
# curl: Needed for health checks
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder stage
# This includes all pip-installed packages and the spaCy model
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Create a non-root user for security
# Running as root inside containers is a security risk
# If the container is compromised, the attacker has root access
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

# Copy application code
COPY --chown=appuser:appuser . .

# Switch to non-root user
USER appuser

# Expose port 8000
# This is the port FastAPI will listen on
EXPOSE 8000

# Health check
# Docker will periodically check if the container is healthy
# If health check fails multiple times, Docker can restart the container
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Start the FastAPI application
# --host 0.0.0.0: Listen on all network interfaces (required for Docker)
# --port 8000: Listen on port 8000
# --workers 1: Number of worker processes (can be increased for production)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
