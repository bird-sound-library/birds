
import os
import time

import requests
from dotenv import load_dotenv
from sqlalchemy import text

from database import SessionLocal
from models import Bird, Sound


load_dotenv()

API_KEY = os.getenv("XENO_CANTO_API_KEY")
API_URL = "https://xeno-canto.org/api/3/recordings"


def parse_duration(value):
    """Convert a duration such as '1:23' into seconds."""
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


def search_recording(scientific_name):
    """Find one recording for a bird in Xeno-canto."""
    parts = scientific_name.split()

    if len(parts) < 2:
        return None

    genus, species = parts[0], parts[1]

    response = requests.get(
        API_URL,
        params={
            "query": f'gen:"{genus}" sp:"{species}" grp:birds',
            "key": API_KEY,
        },
        timeout=30,
    )

    response.raise_for_status()
    data = response.json()

    recordings = data.get("recordings", [])

    if not recordings:
        return None

    for recording in recordings:
        file_url = recording.get("file") or recording.get("audio_url")

        if file_url:
            return recording

    return None


def import_recording(db, bird, recording):
    external_id = str(recording.get("id", ""))

    if not external_id:
        print("  Skipped: recording has no ID")
        return

    file_url = recording.get("file") or recording.get("audio_url")

    if file_url and file_url.startswith("//"):
        file_url = "https:" + file_url

    if not file_url:
        print("  Skipped: recording has no audio URL")
        return

    source_url = (
        recording.get("url")
        or f"https://xeno-canto.org/{external_id}"
    )

    license_value = (
        recording.get("license")
        or recording.get("lic")
    )

    sound = (
        db.query(Sound)
        .filter(Sound.external_id == external_id)
        .first()
    )

    if sound is None:
        sound = Sound(
            external_id=external_id,
            title=(
                recording.get("en")
                or recording.get("title")
                or bird.common_name
            ),
            file_url=file_url,
            type=recording.get("type"),
            source="Xeno-canto",
            description=recording.get("remarks"),
            duration=(
                recording.get("length_seconds")
                or parse_duration(recording.get("length"))
            ),
            license=license_value,
            source_url=source_url,
        )

        db.add(sound)
        db.flush()

    linked = db.execute(
        text("""
            SELECT 1
            FROM has
            WHERE bird_id = :bird_id
              AND sound_id = :sound_id
            LIMIT 1
        """),
        {
            "bird_id": bird.bird_id,
            "sound_id": sound.sound_id,
        },
    ).first()

    if not linked:
        db.execute(
            text("""
                INSERT INTO has (bird_id, sound_id)
                VALUES (:bird_id, :sound_id)
            """),
            {
                "bird_id": bird.bird_id,
                "sound_id": sound.sound_id,
            },
        )

    db.commit()

    print(
        f"  Imported: {sound.title} "
        f"(XC{external_id})"
    )


def main():
    if not API_KEY:
        raise RuntimeError(
            "XENO_CANTO_API_KEY is missing from backend/.env"
        )

    db = SessionLocal()

    try:
        birds = (
            db.query(Bird)
            .filter(Bird.scientific_name.isnot(None))
            .order_by(Bird.bird_id)
            .all()
        )

        for bird in birds:
            print(
                f"\nSearching: {bird.common_name} "
                f"({bird.scientific_name})"
            )

            try:
                recording = search_recording(
                    bird.scientific_name
                )

                if recording is None:
                    print("  No recording found")
                    continue

                import_recording(db, bird, recording)

            except requests.RequestException as error:
                db.rollback()
                print(f"  API request failed: {error}")

            except Exception:
                db.rollback()
                raise

            time.sleep(1)

    finally:
        db.close()


if __name__ == "__main__":
    main()
