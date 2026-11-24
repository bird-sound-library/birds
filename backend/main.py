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
from models import Bird, Recording, User, IdentifiedAs, DetectionInterval, Sound, has_sound
from schemas import BirdResponse, SoundResponse, RecordingResponse
from routers.auth import router as auth_router
from dependencies import get_current_user, get_optional_user
from settings import settings

import html
import re
import httpx

from sqlalchemy.dialects.postgresql import insert as pg_insert


app = FastAPI()
app.include_router(auth_router)

UPLOAD_DIR = Path(__file__).resolve().parent / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

logger = logging.getLogger(__name__)

# ============================================================
# Automatic bird creation
# ============================================================

AUTO_ADD_MIN_CONFIDENCE = Decimal("0.70")
AUTO_ADD_MIN_DETECTIONS = 2

WIKIPEDIA_API_URL = "https://en.wikipedia.org/w/api.php"


async def _get_wikipedia_page(
    client: httpx.AsyncClient,
    title: str
) -> dict | None:
    """
    Gets an English Wikipedia article by its title.
    Returns article title, URL, description and image.
    """

    params = {
        "action": "query",
        "format": "json",
        "formatversion": "2",
        "prop": "extracts|pageimages|info|pageprops",
        "exintro": "1",
        "explaintext": "1",
        "inprop": "url",
        "piprop": "original|thumbnail",
        "pithumbsize": "800",
        "redirects": "1",
        "titles": title
    }

    response = await client.get(
        WIKIPEDIA_API_URL,
        params=params
    )
    response.raise_for_status()

    data = response.json()
    pages = data.get("query", {}).get("pages", [])

    if not pages:
        return None

    page = pages[0]

    # Article does not exist or is a disambiguation page.
    if "missing" in page:
        return None

    if "disambiguation" in page.get("pageprops", {}):
        return None

    description = page.get("extract", "").strip()

    if not description:
        return None

    # Prefer an optimized thumbnail instead of a huge original image.
    image_url = (
        page.get("thumbnail", {}).get("source")
        or page.get("original", {}).get("source")
    )

    return {
        "title": page.get("title"),
        "url": page.get("fullurl"),
        "description": description,
        "image_url": image_url
    }


async def fetch_wikipedia_metadata(
    scientific_name: str,
    common_name: str | None = None
) -> dict | None:
    """
    Searches English Wikipedia using the scientific name.
    If necessary, also tries the common name.
    """

    headers = {
        "User-Agent": (
            "BirdSoundLibrary/1.0 "
            "(https://github.com/bird-sound-library/birds)"
        )
    }

    try:
        async with httpx.AsyncClient(
            timeout=10.0,
            follow_redirects=True,
            headers=headers
        ) as client:

            # First, try the scientific name as an article title.
            page = await _get_wikipedia_page(
                client,
                scientific_name
            )

            if page is not None:
                return page

            # If the direct article does not exist, use Wikipedia search.
            search_queries = [
                f'"{scientific_name}"'
            ]

            if common_name:
                search_queries.append(
                    f'"{common_name}" bird'
                )

            for search_query in search_queries:
                response = await client.get(
                    WIKIPEDIA_API_URL,
                    params={
                        "action": "query",
                        "format": "json",
                        "list": "search",
                        "srsearch": search_query,
                        "srlimit": "5"
                    }
                )

                response.raise_for_status()

                results = response.json().get(
                    "query", {}
                ).get("search", [])

                if not results:
                    continue

                scientific_lower = scientific_name.casefold()
                common_lower = (
                    common_name.casefold()
                    if common_name else ""
                )

                def candidate_score(result):
                    title = result.get("title", "").casefold()

                    snippet = html.unescape(
                        re.sub(
                            r"<[^>]+>",
                            " ",
                            result.get("snippet", "")
                        )
                    ).casefold()

                    if common_lower and title == common_lower:
                        return 0

                    if (
                        scientific_lower in title
                        or scientific_lower in snippet
                    ):
                        return 1

                    return 2

                results.sort(key=candidate_score)

                for candidate in results[:3]:
                    title = candidate.get("title")

                    if not title:
                        continue

                    # Avoid unrelated articles from common-name searches.
                    if (
                        search_query != search_queries[0]
                        and candidate_score(candidate) == 2
                    ):
                        continue

                    page = await _get_wikipedia_page(
                        client,
                        title
                    )

                    if page is not None:
                        return page

    except Exception:
        logger.exception(
            "Wikipedia lookup failed for %s",
            scientific_name
        )

    # The bird can still be added without Wikipedia metadata.
    return None


def get_or_create_bird(
    db: Session,
    scientific_name: str,
    common_name: str | None,
    confidence: Decimal,
    detections: int,
    wikipedia_data: dict | None
) -> Bird | None:
    """
    Returns an existing bird or creates a new one.

    New birds are added only when they satisfy the confidence
    and detection thresholds.
    """

    scientific_name = scientific_name.strip()

    if not scientific_name:
        return None

    # Check whether the bird already exists.
    bird = db.scalar(
        select(Bird).where(
            Bird.scientific_name == scientific_name
        )
    )

    if bird is not None:
        return bird

    # Do not automatically add uncertain detections.
    if (
        confidence < AUTO_ADD_MIN_CONFIDENCE
        or detections < AUTO_ADD_MIN_DETECTIONS
    ):
        logger.info(
            "New bird rejected: %s "
            "(confidence=%s, detections=%s)",
            scientific_name,
            confidence,
            detections
        )

        return None

    wikipedia_data = wikipedia_data or {}

    final_common_name = (
        common_name.strip()
        if common_name and common_name.strip()
        else wikipedia_data.get("title")
    )

    # Insert safely even if another request adds the same bird
    # at approximately the same time.
    statement = (
        pg_insert(Bird)
        .values(
            scientific_name=scientific_name,
            common_name=final_common_name,
            wikipedia_url=wikipedia_data.get("url"),
            description=wikipedia_data.get("description"),
            image_url=wikipedia_data.get("image_url")
        )
        .on_conflict_do_nothing(
            index_elements=[Bird.scientific_name]
        )
        .returning(Bird.bird_id)
    )

    bird_id = db.execute(
        statement
    ).scalar_one_or_none()

    if bird_id is not None:
        logger.info(
            "New bird added to database: %s",
            scientific_name
        )

        return db.get(Bird, bird_id)

    # Another request may have inserted this bird first.
    return db.scalar(
        select(Bird).where(
            Bird.scientific_name == scientific_name
        )
    )

# ============================================================
# Xeno-canto integration
# ============================================================

XENO_CANTO_API_URL = "https://xeno-canto.org/api/3/recordings"


def parse_xeno_duration(value) -> int | None:
    """Convert Xeno-canto duration to seconds."""

    if not value:
        return None

    try:
        parts = str(value).split(":")

        if len(parts) == 2:
            return int(parts[0]) * 60 + int(parts[1])

        if len(parts) == 3:
            return (
                int(parts[0]) * 3600
                + int(parts[1]) * 60
                + int(parts[2])
            )

        return int(float(value))

    except (ValueError, TypeError):
        return None


async def fetch_xeno_canto_recording(
    scientific_name: str
) -> dict | None:
    """
    Finds the first available recording for a bird
    using its scientific name.
    """

    parts = scientific_name.strip().split()

    if len(parts) < 2:
        return None

    genus, species = parts[0], parts[1]

    try:
        async with httpx.AsyncClient(
            timeout=30.0,
            follow_redirects=True
        ) as client:

            response = await client.get(
                XENO_CANTO_API_URL,
                params={
                    "query": (
                        f'gen:"{genus}" '
                        f'sp:"{species}" '
                        f'grp:birds'
                    ),
                    "key": settings.xeno_canto_api_key
                }
            )

            response.raise_for_status()

            data = response.json()

            recordings = data.get("recordings", [])

            for recording in recordings:
                file_url = (
                    recording.get("file")
                    or recording.get("audio_url")
                )

                if file_url:
                    return recording

    except Exception:
        logger.exception(
            "Xeno-canto search failed for %s",
            scientific_name
        )

    logger.info(
        "No Xeno-canto recording found for %s",
        scientific_name
    )

    return None


def save_xeno_canto_sound(
    db: Session,
    bird: Bird,
    recording: dict
) -> None:
    """
    Saves a Xeno-canto recording and links it to a bird.
    Prevents duplicate sound records and duplicate links.
    """

    external_id = str(recording.get("id", ""))

    if not external_id:
        logger.warning(
            "Xeno-canto recording has no ID"
        )
        return

    file_url = (
        recording.get("file")
        or recording.get("audio_url")
    )

    if not file_url:
        return

    if file_url.startswith("//"):
        file_url = "https:" + file_url

    source_url = (
        recording.get("url")
        or f"https://xeno-canto.org/{external_id}"
    )

    license_value = (
        recording.get("license")
        or recording.get("lic")
    )

    duration = (
        recording.get("length_seconds")
        or parse_xeno_duration(
            recording.get("length")
        )
    )

    # Insert sound only if it does not already exist.
    statement = (
        pg_insert(Sound)
        .values(
            external_id=external_id,
            title=(
                recording.get("en")
                or recording.get("title")
                or bird.common_name
            ),
            file_url=file_url,
            type=recording.get("type"),
            source="Xeno-canto",
            recordist=recording.get("rec"),
            description=recording.get("remarks"),
            duration=duration,
            license=license_value,
            source_url=source_url
        )
        .on_conflict_do_nothing(
            index_elements=[Sound.external_id]
        )
        .returning(Sound.sound_id)
    )

    sound_id = db.execute(
        statement
    ).scalar_one_or_none()

    if sound_id is not None:
        sound = db.get(Sound, sound_id)

    else:
        # Reuse an existing sound with the same Xeno-canto ID.
        sound = db.scalar(
            select(Sound).where(
                Sound.external_id == external_id
            )
        )

    if sound is None:
        return

    # Link the sound to the bird without creating duplicate links.
    link_statement = (
        pg_insert(has_sound)
        .values(
            bird_id=bird.bird_id,
            sound_id=sound.sound_id
        )
        .on_conflict_do_nothing(
            index_elements=[
                has_sound.c.bird_id,
                has_sound.c.sound_id
            ]
        )
    )

    db.execute(link_statement)

    logger.info(
        "Xeno-canto sound linked: %s -> XC%s",
        bird.scientific_name,
        external_id
    )

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

        prepared_species = []

        # ----------------------------------------------------
        # First pass: check which birds already exist.
        # Do not create any database records yet.
        # ----------------------------------------------------

        for species in species_list:
            scientific_name = species.get("scientific_name")

            if not scientific_name:
                continue

            scientific_name = scientific_name.strip()

            max_confidence = Decimal(
                str(species["max_confidence"])
            )

            avg_confidence = Decimal(
                str(species["avg_confidence"])
            )

            detections = int(
                species.get("detections", 0)
            )

            bird_id = db.scalar(
                select(Bird.bird_id).where(
                    Bird.scientific_name == scientific_name
                )
            )

            eligible_for_auto_add = (
                max_confidence >= AUTO_ADD_MIN_CONFIDENCE
                and detections >= AUTO_ADD_MIN_DETECTIONS
            )

            prepared_species.append({
                "species": species,
                "scientific_name": scientific_name,
                "common_name": species.get("common_name"),
                "bird_id": bird_id,
                "max_confidence": max_confidence,
                "avg_confidence": avg_confidence,
                "detections": detections,
                "eligible": eligible_for_auto_add,
                "wikipedia": None
            })

        # Close the read-only transaction before making
        # external Wikipedia requests.
        db.rollback()

        # ----------------------------------------------------
        # Second pass: search Wikipedia for unknown birds.
        # Perform requests concurrently.
        # ----------------------------------------------------

        unknown_species = [
            item
            for item in prepared_species
            if item["bird_id"] is None and item["eligible"]
        ]

        if unknown_species:
            external_results = await asyncio.gather(
                *[
                    asyncio.gather(
                        fetch_wikipedia_metadata(
                            scientific_name=item["scientific_name"],
                            common_name=item["common_name"]
                        ),
                        fetch_xeno_canto_recording(
                            scientific_name=item["scientific_name"]
                        )
                    )
                    for item in unknown_species
                ]
            )

            for item, (wikipedia_data, xeno_recording) in zip(
                unknown_species,
                external_results
            ):
                item["wikipedia"] = wikipedia_data
                item["xeno_canto"] = xeno_recording

        # ----------------------------------------------------
        # Third pass: create birds and save identifications.
        # ----------------------------------------------------

        for item in prepared_species:
            bird = None

            # Load an existing bird.
            if item["bird_id"] is not None:
                bird = db.get(
                    Bird,
                    item["bird_id"]
                )

            # Create a new bird if necessary.
            if bird is None:
                if not item["eligible"]:
                    logger.info(
                        "Unknown bird skipped: %s "
                        "(confidence=%s, detections=%s)",
                        item["scientific_name"],
                        item["max_confidence"],
                        item["detections"]
                    )

                    continue

                bird = get_or_create_bird(
                    db=db,
                    scientific_name=item["scientific_name"],
                    common_name=item["common_name"],
                    confidence=item["max_confidence"],
                    detections=item["detections"],
                    wikipedia_data=item["wikipedia"]
                )

            # Import sound only for newly detected species.
            if bird is not None and item["bird_id"] is None:
                xeno_recording = item.get("xeno_canto")

                if xeno_recording is not None:
                    try:
                        # Isolate sound import in a savepoint.
                        # A sound import failure must not cancel bird creation.
                        with db.begin_nested():
                            save_xeno_canto_sound(
                                db=db,
                                bird=bird,
                                recording=xeno_recording
                            )

                    except Exception:
                        logger.exception(
                            "Failed to save Xeno-canto sound for %s",
                            item["scientific_name"]
                        )

            if bird is None:
                continue

            confidences.append(
                item["max_confidence"]
            )

            # Save identification.
            identification = IdentifiedAs(
                recording_id=recording.recording_id,
                bird_id=bird.bird_id,
                model_version="BirdNET 3.0",
                identified_at=datetime.now(
                    timezone.utc
                ).replace(tzinfo=None),
                detections=item["detections"],
                max_confidence=item["max_confidence"],
                avg_confidence=item["avg_confidence"]
            )

            db.add(identification)

            # Save detection intervals.
            for index, interval in enumerate(
                item["species"].get("intervals", [])
            ):
                db.add(
                    DetectionInterval(
                        recording_id=recording.recording_id,
                        bird_id=bird.bird_id,
                        interval_index=index,
                        start_time=Decimal(
                            str(interval["start"])
                        ),
                        end_time=Decimal(
                            str(interval["end"])
                        )
                    )
                )

        # ----------------------------------------------------
        # Update recording status.
        # ----------------------------------------------------

        recording.confidence = (
            max(confidences) if confidences else None
        )

        recording.status = (
            "completed" if confidences else "no_match"
        )

        db.commit()

        return load_recording_response(
            db,
            recording.recording_id
        )

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
