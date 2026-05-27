from datetime import datetime, timezone

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query
)

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.schemas import (
    TranscriptRequest,
    MeetingResponse
)

from app.services.pipeline import run_pipeline
from app.db.database import SessionLocal
from app.db.models import MeetingAnalysis
from app.core.logger import get_logger

logger = get_logger(__name__)

router = APIRouter()


# =====================================
# DATABASE DEPENDENCY
# =====================================

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# =====================================
# HEALTH CHECK
# =====================================
# Call this to check if the app + database are alive
# Example: GET /health

@router.get(
    "/health",
    tags=["Health"],
    summary="Check if the app and database are running"
)
def health_check(db: Session = Depends(get_db)):

    logger.info("Health check requested.")

    # Try a simple database query
    try:
        db.execute(text("SELECT 1"))
        db_status = "healthy"
    except Exception as e:
        logger.error(f"Database health check failed: {str(e)}")
        db_status = "unhealthy"

    status = "ok" if db_status == "healthy" else "degraded"

    return {
        "status": status,
        "database": db_status,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "version": "1.0.0",
        "service": "VartaIQ AI Meeting Analyzer"
    }


# =====================================
# ANALYZE MEETING
# =====================================
# POST /analyze — Send a transcript, get AI analysis back

@router.post(
    "/analyze",
    response_model=dict,
    tags=["Analysis"],
    summary="Analyze a meeting transcript"
)
def analyze_meeting(
    request: TranscriptRequest,
    db: Session = Depends(get_db)
):

    logger.info(
        f"Analyze request received. "
        f"Transcript items: {len(request.transcript)}"
    )

    # ---------------------------------
    # Validate input is not empty
    # ---------------------------------

    if not request.transcript:
        logger.warning("Empty transcript received.")
        raise HTTPException(
            status_code=400,
            detail="Transcript cannot be empty."
        )

    # ---------------------------------
    # Convert Pydantic → dict
    # ---------------------------------

    data = [item.dict() for item in request.transcript]

    # ---------------------------------
    # Run AI Pipeline
    # ---------------------------------

    logger.info("Running AI pipeline...")

    try:
        result = run_pipeline(data)
    except Exception as e:
        logger.error(f"Pipeline failed: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="AI pipeline failed. Please try again."
        )

    logger.info("AI pipeline completed successfully.")

    # ---------------------------------
    # Save Meeting Analysis to DB
    # ---------------------------------

    speakers = set([x["speaker"] for x in data])

    meeting = MeetingAnalysis(
        meeting_title=(
            f"Meeting with {len(speakers)} participants"
        ),
        participant_count=len(speakers),
        transcript_length=len(data),
        summary=result["summary"],
        topics=result["topics"],
        transcript=data,
        action_items=result["action_items"],
        decisions=result["decisions"],
        useless_talk=result["useless_talk"],
        speaker_analysis=result["speaker_analysis"],
        sentiment_analysis=result["sentiment_analysis"],
        score=result["score"],
        followups=result["followups"],
        ai_insights=result["ai_insights"]
    )

    db.add(meeting)
    db.commit()
    db.refresh(meeting)

    logger.info(f"Meeting saved to database with ID: {meeting.id}")

    return {
        "meeting_id": meeting.id,
        "analysis": result
    }


# =====================================
# GET SINGLE MEETING
# =====================================
# GET /meetings/5 — Get meeting with ID 5

@router.get(
    "/meetings/{meeting_id}",
    response_model=MeetingResponse,
    tags=["Meetings"],
    summary="Get a single meeting by ID"
)
def get_meeting(
    meeting_id: int,
    db: Session = Depends(get_db)
):

    logger.info(f"Fetching meeting ID: {meeting_id}")

    meeting = db.query(MeetingAnalysis).filter(
        MeetingAnalysis.id == meeting_id
    ).first()

    if not meeting:
        logger.warning(f"Meeting ID {meeting_id} not found.")
        raise HTTPException(
            status_code=404,
            detail=f"Meeting with ID {meeting_id} not found."
        )

    return meeting


# =====================================
# GET ALL MEETINGS — WITH PAGINATION
# =====================================
# GET /meetings          → Page 1, 10 per page (default)
# GET /meetings?page=2   → Page 2
# GET /meetings?page=1&page_size=5 → Page 1, 5 per page

@router.get(
    "/meetings",
    tags=["Meetings"],
    summary="Get all meetings with pagination"
)
def get_all_meetings(
    page: int = Query(default=1, ge=1, description="Page number (starts at 1)"),
    page_size: int = Query(default=10, ge=1, le=100, description="Number of results per page (max 100)"),
    db: Session = Depends(get_db)
):

    logger.info(f"Fetching meetings — page: {page}, page_size: {page_size}")

    # Calculate how many records to skip
    offset = (page - 1) * page_size

    # Get total count
    total = db.query(MeetingAnalysis).count()

    # Get the meetings for this page only
    meetings = (
        db.query(MeetingAnalysis)
        .order_by(MeetingAnalysis.created_at.desc())
        .offset(offset)
        .limit(page_size)
        .all()
    )

    total_pages = (total + page_size - 1) // page_size  # ceiling division

    logger.info(
        f"Returning {len(meetings)} meetings "
        f"(page {page}/{total_pages}, total: {total})"
    )

    # Convert SQLAlchemy models to dictionaries for JSON serialization
    meetings_data = [
        {
            "id": meeting.id,
            "meeting_title": meeting.meeting_title,
            "participant_count": meeting.participant_count,
            "transcript_length": meeting.transcript_length,
            "summary": meeting.summary,
            "topics": meeting.topics,
            "transcript": meeting.transcript,
            "action_items": meeting.action_items,
            "decisions": meeting.decisions,
            "useless_talk": meeting.useless_talk,
            "speaker_analysis": meeting.speaker_analysis,
            "sentiment_analysis": meeting.sentiment_analysis,
            "score": meeting.score,
            "ai_insights": meeting.ai_insights,
            "followups": meeting.followups,
            "created_at": meeting.created_at.isoformat(),
            "updated_at": meeting.updated_at.isoformat()
        }
        for meeting in meetings
    ]

    return {
        "pagination": {
            "total": total,
            "page": page,
            "page_size": page_size,
            "total_pages": total_pages,
            "has_next": page < total_pages,
            "has_previous": page > 1
        },
        "meetings": meetings_data
    }