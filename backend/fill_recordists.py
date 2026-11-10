
import requests

from sqlalchemy import select, update
from database import SessionLocal
from models import Sound
from settings import settings


API_URL = "https://xeno-canto.org/api/3/recordings"


def get_recordist(recording_id):
    response = requests.get(
        API_URL,
        params={
            "query": f"nr:{recording_id}",
            "key": settings.xeno_canto_api_key,
        },
        timeout=30,
    )

    response.raise_for_status()
    data = response.json()

    recordings = data.get("recordings", [])

    matches = [
        recording
        for recording in recordings
        if str(recording.get("id")) == str(recording_id)
    ]

    if len(matches) != 1:
        return None

    return matches[0].get("rec")


def main():
    if not settings.xeno_canto_api_key:
        raise RuntimeError("XENO_CANTO_API_KEY is not configured")

    with SessionLocal() as session:
        sounds = session.scalars(
            select(Sound).where(
                Sound.source == "Xeno-canto"
            )
        ).all()

        updated = 0
        skipped = 0

        for sound in sounds:
            recording_id = sound.external_id

            if not recording_id:
                print(f"Sound {sound.sound_id}: missing external_id")
                skipped += 1
                continue

            try:
                recordist = get_recordist(recording_id)

                if not recordist:
                    print(f"Sound {sound.sound_id}: recordist not found")
                    skipped += 1
                    continue

                session.execute(
                    update(Sound)
                    .where(Sound.sound_id == sound.sound_id)
                    .values(recordist=recordist)
                )

                print(
                    f"Sound {sound.sound_id}: "
                    f"{sound.title} — {recordist}"
                )

                updated += 1

            except requests.RequestException as error:
                print(f"Sound {sound.sound_id}: API error: {error}")
                skipped += 1

        session.commit()

        print("\n========== RESULT ==========")
        print(f"Updated: {updated}")
        print(f"Skipped: {skipped}")


if __name__ == "__main__":
    main()
