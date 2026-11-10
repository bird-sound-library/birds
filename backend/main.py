import uuid
import logging
from pathlib import Path
from datetime import datetime, timezone
from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Form, status
from fastapi.staticfiles import StaticFiles
from sqlalchemy import select, func
from sqlalchemy.orm import Session, selectinload

from database import get_db
from models import Bird, Recording, User
from schemas import BirdResponse, SoundResponse, RecordingResponse
from decimal import Decimal
from mutagen import File as MutagenFile
from routers.auth import router as auth_router
from dependencies import get_current_user
from settings import settings
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()
app.include_router(auth_router)
UPLOAD_DIR = Path(__file__).resolve().parent / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
logger = logging.getLogger(__name__)

app.mount(
    "/uploads",
    StaticFiles(directory=UPLOAD_DIR),
    name="uploads"
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)



@app.get("/test-db")
def test_db(db: Session = Depends(get_db)):
    from sqlalchemy import text

    result = db.execute(text("SELECT 1"))
    return result.scalar()


@app.get("/birds", response_model=list[BirdResponse])
def get_birds(db: Session = Depends(get_db)):
    birds = (
        db.query(Bird)
        .options(
            selectinload(Bird.categories),
            selectinload(Bird.sounds)
        )
        .order_by(Bird.bird_id)
        .all()
    )

    return birds


@app.get("/birds/{bird_id}", response_model=BirdResponse)
def get_bird(bird_id: int, db: Session = Depends(get_db)):

    bird = (
        db.query(Bird)
        .options(
            selectinload(Bird.categories),
            selectinload(Bird.sounds)
        )
        .filter(Bird.bird_id == bird_id)
        .first()
    )

    if bird is None:
        raise HTTPException(
            status_code=404,
            detail="Bird not found"
        )

    return bird

@app.get(
    "/birds/{bird_id}/sounds",
    response_model=list[SoundResponse]
)
def get_bird_sounds(
    bird_id: int,
    db: Session = Depends(get_db)
):
    bird = (
        db.query(Bird)
        .options(selectinload(Bird.sounds))
        .filter(Bird.bird_id == bird_id)
        .first()
    )

    if bird is None:
        raise HTTPException(
            status_code=404,
            detail="Bird not found"
        )

    return bird.sounds


ALLOWED_EXTENSIONS = {
    ".mp3",
    ".wav",
    ".m4a",
    ".ogg",
    ".flac",
    ".webm",
}

MAX_FILE_SIZE = 25 * 1024 * 1024

def get_audio_duration(file_path: Path) -> Decimal:
    audio = MutagenFile(file_path)

    if audio is None or audio.info is None:
        raise ValueError("Invalid or unsupported audio file")

    duration = audio.info.length

    if duration <= 0:
        raise ValueError("Audio file is empty")

    return Decimal(str(duration))


@app.post(
    "/recordings",
    response_model=RecordingResponse,
    status_code=201
)
async def upload_recording(
    file: UploadFile = File(...),
    location: str | None = Form(None),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user)
):
    extension = Path(file.filename or "").suffix.lower()

    if extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail="Unsupported audio format"
        )

    filename = f"{uuid.uuid4().hex}{extension}"
    file_path = UPLOAD_DIR / filename

    size = 0
    old_file_path = None
    committed = False

    try:
        # Lock user row to prevent concurrent uploads
        locked_user = db.scalar(
            select(User)
            .where(User.user_id == user.user_id)
            .with_for_update()
        )

        if locked_user is None or not locked_user.is_active:
            raise HTTPException(
                status_code=401,
                detail="User is unavailable"
            )

        # Count user's recordings
        recordings_count = db.scalar(
            select(func.count())
            .select_from(Recording)
            .where(Recording.user_id == user.user_id)
        )

        oldest_recording = None

        # Find oldest recording if limit reached
        if recordings_count >= 100:
            oldest_recording = db.scalar(
                select(Recording)
                .where(Recording.user_id == user.user_id)
                .order_by(
                    Recording.recorded_at.asc(),
                    Recording.recording_id.asc()
                )
                .limit(1)
            )

        # Save new audio file
        with file_path.open("wb") as output:
            while True:
                chunk = await file.read(1024 * 1024)

                if not chunk:
                    break

                size += len(chunk)

                if size > MAX_FILE_SIZE:
                    raise HTTPException(
                        status_code=413,
                        detail="File is too large. Maximum size is 25 MB."
                    )

                output.write(chunk)

        # Validate audio
        try:
            duration = get_audio_duration(file_path)
        except ValueError as exc:
            raise HTTPException(
                status_code=400,
                detail=str(exc)
            )

        # Create new recording
        recording = Recording(
            user_id=user.user_id,
            file_url=f"/uploads/{filename}",
            recorded_at=datetime.now(timezone.utc).replace(tzinfo=None),
            location=location,
            status="uploaded",
            duration=duration,
            confidence=None
        )

        db.add(recording)

        # Delete oldest database record if needed
        if oldest_recording is not None:
            old_file_path = (
                UPLOAD_DIR / Path(oldest_recording.file_url).name
            )

            db.delete(oldest_recording)

        db.commit()
        committed = True

        db.refresh(recording)

        # Remove old file only after successful commit
        if old_file_path is not None:
            old_file_path.unlink(missing_ok=True)

        return recording

    except Exception:
        if not committed:
            db.rollback()

            if file_path.exists():
                file_path.unlink(missing_ok=True)

        raise

    finally:
        await file.close()



@app.get(
    "/recordings",
    response_model=list[RecordingResponse]
)
def get_recordings(
    skip: int = 0,
    limit: int = 20,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    limit = min(max(limit, 1), 100)
    skip = max(skip, 0)

    recordings = db.scalars(
        select(Recording)
        .where(Recording.user_id == user.user_id)
        .order_by(Recording.recording_id.desc())
        .offset(skip)
        .limit(limit)
    ).all()

    return recordings

@app.get(
    "/recordings/{recording_id}",
    response_model=RecordingResponse
)
def get_recording(
    recording_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    recording = db.scalar(
        select(Recording).where(
            Recording.recording_id == recording_id,
            Recording.user_id == user.user_id
        )
    )

    if recording is None:
        raise HTTPException(
            status_code=404,
            detail="Recording not found"
        )

    return recording


@app.delete(
    "/recordings/{recording_id}",
    status_code=200
)
def delete_recording(
    recording_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    recording = db.scalar(
        select(Recording).where(
            Recording.recording_id == recording_id,
            Recording.user_id == user.user_id
        )
    )

    if recording is None:
        raise HTTPException(
            status_code=404,
            detail="Recording not found"
        )

    file_path = UPLOAD_DIR / Path(recording.file_url).name

    try:
        db.delete(recording)
        db.commit()

    except Exception:
        db.rollback()
        raise

    try:
        file_path.unlink(missing_ok=True)

    except OSError:
        logger.exception(
            "Failed to delete recording file: %s",
            file_path
        )

    return {
        "message": "Recording deleted successfully",
        "recording_id": recording_id
    }
