import time
from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

from app.routes import router
from app.db.database import engine
from app.db.models import Base
from app.core.logger import get_logger

logger = get_logger(__name__)

# =====================================
# CREATE DATABASE TABLES
# =====================================

Base.metadata.create_all(bind=engine)
logger.info("Database tables verified/created.")

# =====================================
# FASTAPI APP
# =====================================

app = FastAPI(
    title="VartaIQ — AI Meeting Analyzer",
    description="Analyzes meeting transcripts and generates AI-powered insights.",
    version="1.0.0"
)

# =====================================
# CORS MIDDLEWARE
# =====================================
# Allow cross-origin requests from specified origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://65.2.158.83:3001",
        "http://127.0.0.1:3000",
        "http://localhost:3000",
        "https://sabha-mind.vercel.app"
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =====================================
# REQUEST LOGGING MIDDLEWARE
# =====================================
# This runs for EVERY request — logs method, URL, status, and time taken

@app.middleware("http")
async def log_requests(request: Request, call_next):

    start_time = time.time()

    logger.info(
        f"REQUEST  → {request.method} {request.url.path}"
    )

    try:
        response = await call_next(request)
    except Exception as e:
        logger.error(f"Unhandled error during request: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error"}
        )

    duration_ms = round((time.time() - start_time) * 1000, 2)

    logger.info(
        f"RESPONSE ← {request.method} {request.url.path} "
        f"| Status: {response.status_code} | {duration_ms}ms"
    )

    return response


# =====================================
# STARTUP EVENT
# =====================================

@app.on_event("startup")
async def on_startup():
    logger.info("=" * 50)
    logger.info("VartaIQ AI Meeting Analyzer is starting up...")
    logger.info("API Docs available at: /docs")
    logger.info("Health check available at: /health")
    logger.info("=" * 50)


# =====================================
# INCLUDE ROUTES
# =====================================

app.include_router(router)