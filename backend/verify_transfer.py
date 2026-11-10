
from pathlib import Path

from dotenv import dotenv_values
from sqlalchemy import MetaData, create_engine, select
from sqlalchemy.engine import URL

from settings import settings


ROOT_DIR = Path(__file__).resolve().parent.parent
env = dotenv_values(ROOT_DIR / ".env")

source_engine = create_engine(
    URL.create(
        "postgresql+psycopg",
        username=env["POSTGRES_USER"],
        password=env["POSTGRES_PASSWORD"],
        host="127.0.0.1",
        port=5433,
        database=env["POSTGRES_DB"],
    )
)

target_engine = create_engine(settings.database_url)

TABLES = [
    "category",
    "bird",
    "sound",
    "bird_category",
    "has",
    "classifies",
]


def read_table(engine, metadata, name):
    with engine.connect() as conn:
        return [
            dict(row)
            for row in conn.execute(
                select(metadata.tables[name])
            ).mappings()
        ]


def normalize(rows):
    return sorted(rows, key=lambda row: repr(sorted(row.items())))


def main():
    source_meta = MetaData()
    target_meta = MetaData()

    source_meta.reflect(bind=source_engine, only=TABLES)
    target_meta.reflect(bind=target_engine, only=TABLES)

    all_ok = True

    print("TRANSFER VERIFICATION\n")

    for name in TABLES:
        source_rows = read_table(source_engine, source_meta, name)
        target_rows = read_table(target_engine, target_meta, name)

        source_count = len(source_rows)
        target_count = len(target_rows)

        same_data = (
            normalize(source_rows) == normalize(target_rows)
        )

        status = "OK" if same_data else "MISMATCH"

        print(
            f"{name}: local={source_count}, "
            f"supabase={target_count}, "
            f"data={status}"
        )

        if not same_data:
            all_ok = False

    print()
    print(
        "ALL DATA MATCHES"
        if all_ok
        else "DATA DIFFERENCES FOUND"
    )


if __name__ == "__main__":
    try:
        main()
    finally:
        source_engine.dispose()
        target_engine.dispose()
