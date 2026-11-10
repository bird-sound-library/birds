
from sqlalchemy import select
from database import engine
from models import Sound

with engine.connect() as conn:
    rows = conn.execute(
        select(
            Sound.sound_id,
            Sound.title,
            Sound.external_id,
            Sound.license,
            Sound.source_url,
        ).order_by(Sound.sound_id)
    ).fetchall()

    for row in rows:
        print("-" * 50)
        print("ID:", row.sound_id)
        print("Title:", row.title)
        print("External ID:", row.external_id)
        print("License:", row.license)
        print("Source URL:", row.source_url)
