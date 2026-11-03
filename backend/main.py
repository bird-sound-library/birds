import uuid
from pathlib import Path
from datetime import datetime, timezone
from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Form
from fastapi.staticfiles import StaticFiles
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from database import get_db
from models import Bird, Recording
from schemas import BirdResponse, SoundResponse, RecordingResponse
from decimal import Decimal
from mutagen import File as MutagenFile

app = FastAPI()
UPLOAD_DIR = Path(__file__).resolve().parent / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

app.mount(
    "/uploads",
    StaticFiles(directory=UPLOAD_DIR),
    name="uploads"
)


@app.get("/test-db")
def test_db(db: Session = Depends(get_db)):
    from sqlalchemy import text

    result = db.execute(text("SELECT 1"))
    return result.scalar()


@app.get("/birds", response_model=list[BirdResponse])
def get_birds(db: Session = Depends(get_db)):
    return db.query(Bird).all()


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
    db: Session = Depends(get_db)
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

    try:
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
        try:
            duration = get_audio_duration(file_path)
        except ValueError as exc:
            raise HTTPException(
                status_code=400,
                detail=str(exc)
            )
        recording = Recording(
            file_url=f"/uploads/{filename}",
            recorded_at=datetime.now(timezone.utc).replace(tzinfo=None),
            location=location,
            status="uploaded",
            duration=duration,
            confidence=None
        )

        db.add(recording)
        db.commit()
        db.refresh(recording)

        return recording

    except Exception:
        db.rollback()

        if file_path.exists():
            file_path.unlink()

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
    db: Session = Depends(get_db)
):
    recordings = db.scalars(
        select(Recording)
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
    db: Session = Depends(get_db)
):
    recording = db.get(Recording, recording_id)

    if recording is None:
        raise HTTPException(
            status_code=404,
            detail="Recording not found"
        )

    return recording