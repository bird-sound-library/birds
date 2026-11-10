
from sqlalchemy import select
from database import engine
from models import Sound

with engine.connect() as conn:
    rows = conn.execute(
        select(
            Sound.sound_id,
            Sound.title,
            Sound.file_url,
            Sound.source,
            Sound.external_id,
        )
    ).fetchall()

    for row in rows:
        print("-" * 60)
        print("ID:", row.sound_id)
        print("Title:", row.title)
        print("URL:", row.file_url)
        print("Source:", row.source)
        print("External ID:", row.external_id)
