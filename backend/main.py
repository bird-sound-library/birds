import uuid
import asyncio
from functools import lru_cache

from gradio_client import Client, handle_file
import logging
from pathlib import Path
from datetime import datetime, timezone
from decimal import Decimal

from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Form
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select, func
from sqlalchemy.orm import Session, selectinload
from mutagen import File as MutagenFile

from database import get_db
from models import Bird, Recording, User, IdentifiedAs, DetectionInterval
from schemas import BirdResponse, SoundResponse, RecordingResponse
from routers.auth import router as auth_router
from dependencies import get_current_user, get_optional_user
from settings import settings


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


# CORS settings
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
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
MAX_RECORDING_DURATION = Decimal("15.0")


def get_audio_duration(file_path: Path) -> Decimal:
    audio = MutagenFile(file_path)

    if audio is None or audio.info is None:
        raise ValueError("Invalid or unsupported audio file")

    duration = audio.info.length

    if duration <= 0:
        raise ValueError("Audio file is empty")

    return Decimal(str(duration))

@lru_cache(maxsize=1)
def get_huggingface_client() -> Client:
    token = settings.hf_token.get_secret_value() or None
    return Client(
        settings.hf_space_id,
        token=token,
        verbose=False
    )


def _recognize_with_huggingface(file_path: Path) -> dict:
    client = get_huggingface_client()
    result = client.predict(
        audio_path=handle_file(str(file_path)),
        api_name="/recognize_audio"
    )

    if not isinstance(result, dict):
        raise ValueError(
            f"Unexpected Hugging Face response type: {type(result).__name__}"
        )
    if result.get("status") not in {"completed", "no_match"}:
        raise ValueError("Unexpected BirdNET response status")
    if not isinstance(result.get("species"), list):
        raise ValueError("Invalid BirdNET species data")

    return result


async def recognize_with_birdnet(file_path: Path) -> dict:
    # gradio_client is synchronous; keep it off FastAPI's event loop.
    return await asyncio.to_thread(
        _recognize_with_huggingface,
        file_path
    )


def load_recording_response(db: Session, recording_id: int):
    statement = (
        select(Recording)
        .options(
            selectinload(Recording.identifications)
            .selectinload(IdentifiedAs.bird),

            selectinload(Recording.identifications)
            .selectinload(IdentifiedAs.intervals)
        )
        .where(Recording.recording_id == recording_id)
    )

    return db.scalar(statement)

@app.post(
    "/recordings",
    response_model=RecordingResponse,
    status_code=201
)

async def upload_recording(
    file: UploadFile = File(...),
    location: str | None = Form(None),
    db: Session = Depends(get_db),
    user: User | None = Depends(get_optional_user)
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
        oldest_recording = None

        if user is not None:
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

            recordings_count = db.scalar(
                select(func.count())
                .select_from(Recording)
                .where(Recording.user_id == user.user_id)
            )

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

        # 1. Save audio
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

        # 2. Validate audio
        try:
            duration = get_audio_duration(file_path)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc))
        if duration > MAX_RECORDING_DURATION:
            raise HTTPException(
            status_code=413,
            detail=(
                "Recording is too long. "
                f"Maximum duration is "
                f"{MAX_RECORDING_DURATION} seconds."
            )
        )
        # 3. Create recording before inference
        recording = Recording(
            user_id=user.user_id if user else None,
            file_url=f"/uploads/{filename}",
            recorded_at=datetime.now(timezone.utc).replace(tzinfo=None),
            location=location,
            status="processing",
            duration=duration,
            confidence=None
        )

        db.add(recording)

        if oldest_recording is not None:
            old_file_path = UPLOAD_DIR / Path(
                oldest_recording.file_url
            ).name
            db.delete(oldest_recording)

        db.commit()
        committed = True
        db.refresh(recording)

        if old_file_path is not None:
            old_file_path.unlink(missing_ok=True)

        # 4. Run BirdNET
        try:
            result = await recognize_with_birdnet(file_path)

        except Exception:
            logger.exception(
                "BirdNET inference failed for recording %s",
                recording.recording_id
            )

            recording.status = "failed"
            db.commit()

            return load_recording_response(db, recording.recording_id)

        # 5. Save identification results
        species_list = result.get("species", [])
        confidences = []

        for species in species_list:
            scientific_name = species.get("scientific_name")

            if not scientific_name:
                continue

            bird = db.scalar(
                select(Bird).where(
                    Bird.scientific_name == scientific_name
                )
            )

            # Skip species not present in our catalog
            if bird is None:
                logger.warning(
                    "Bird not found in catalog: %s",
                    scientific_name
                )
                continue

            max_confidence = Decimal(
                str(species["max_confidence"])
            )
            avg_confidence = Decimal(
                str(species["avg_confidence"])
            )

            confidences.append(max_confidence)

            identification = IdentifiedAs(
                recording_id=recording.recording_id,
                bird_id=bird.bird_id,
                model_version="BirdNET 3.0",
                identified_at=datetime.now(timezone.utc).replace(
                    tzinfo=None
                ),
                detections=int(species.get("detections", 0)),
                max_confidence=max_confidence,
                avg_confidence=avg_confidence
            )

            db.add(identification)

            for index, interval in enumerate(
                species.get("intervals", [])
            ):
                db.add(
                    DetectionInterval(
                        recording_id=recording.recording_id,
                        bird_id=bird.bird_id,
                        interval_index=index,
                        start_time=Decimal(str(interval["start"])),
                        end_time=Decimal(str(interval["end"]))
                    )
                )

        recording.confidence = (
            max(confidences) if confidences else None
        )

        recording.status = (
            "completed" if species_list else "no_match"
        )

        db.commit()

        return load_recording_response(db, recording.recording_id)

    except HTTPException:
        if not committed:
            db.rollback()
            file_path.unlink(missing_ok=True)
        raise

    except Exception:
        if not committed:
            db.rollback()
            file_path.unlink(missing_ok=True)
        else:
            db.rollback()
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
