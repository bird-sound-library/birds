
from pathlib import Path

from dotenv import dotenv_values
from sqlalchemy import MetaData, create_engine, insert, select, func, text
from sqlalchemy.engine import URL

from settings import settings


ROOT_DIR = Path(__file__).resolve().parent.parent
LOCAL_ENV = dotenv_values(ROOT_DIR / ".env")

DB_NAME = LOCAL_ENV.get("POSTGRES_DB")
DB_USER = LOCAL_ENV.get("POSTGRES_USER")
DB_PASSWORD = LOCAL_ENV.get("POSTGRES_PASSWORD")

if not all([DB_NAME, DB_USER, DB_PASSWORD]):
    raise RuntimeError("Missing local database settings in root .env")

local_url = URL.create(
    drivername="postgresql+psycopg",
    username=DB_USER,
    password=DB_PASSWORD,
    host="127.0.0.1",
    port=5433,
    database=DB_NAME,
)

source_engine = create_engine(local_url)
target_engine = create_engine(settings.database_url)

TABLES = [
    "category",
    "bird",
    "sound",
    "bird_category",
    "has",
    "classifies",
]


def order_categories(rows):
    remaining = {row["category_id"]: row for row in rows}
    ordered = []
    added = set()

    while remaining:
        ready = []

        for category_id, row in remaining.items():
            parent_id = row["parent_category_id"]

            if parent_id is None or parent_id in added:
                ready.append(category_id)

        if not ready:
            raise RuntimeError(
                "Circular or invalid category parent references"
            )

        for category_id in ready:
            ordered.append(remaining.pop(category_id))
            added.add(category_id)

    return ordered


def get_rows(connection, table):
    return [
        dict(row)
        for row in connection.execute(select(table)).mappings()
    ]


def main():
    source_metadata = MetaData()
    target_metadata = MetaData()

    source_metadata.reflect(
        bind=source_engine,
        only=TABLES,
    )

    with source_engine.connect() as source:
        source_rows = {
            name: get_rows(source, source_metadata.tables[name])
            for name in TABLES
        }

    print("LOCAL DATABASE:")
    for name in TABLES:
        print(f"{name}: {len(source_rows[name])}")

    with target_engine.begin() as target:
        target_metadata.reflect(
            bind=target,
            only=TABLES,
        )

        # Stop if any destination table already contains data.
        for name in TABLES:
            table = target_metadata.tables[name]
            count = target.execute(
                select(func.count()).select_from(table)
            ).scalar_one()

            if count != 0:
                raise RuntimeError(
                    f"Supabase table '{name}' is not empty: {count} rows"
                )

        # Verify source and destination columns.
        for name in TABLES:
            source_columns = set(
                source_metadata.tables[name].columns.keys()
            )
            target_columns = set(
                target_metadata.tables[name].columns.keys()
            )

            if source_columns != target_columns:
                raise RuntimeError(
                    f"Column mismatch in '{name}': "
                    f"source={source_columns}, target={target_columns}"
                )

        # Insert in dependency order.
        for name in TABLES:
            rows = source_rows[name]

            if name == "category":
                rows = order_categories(rows)

            if rows:
                target.execute(
                    insert(target_metadata.tables[name]),
                    rows,
                )

            print(f"Transferred {name}: {len(rows)} rows")

        # Verify transferred row counts before commit.
        for name in TABLES:
            table = target_metadata.tables[name]
            actual = target.execute(
                select(func.count()).select_from(table)
            ).scalar_one()

            expected = len(source_rows[name])

            if actual != expected:
                raise RuntimeError(
                    f"Count mismatch in '{name}': "
                    f"expected {expected}, got {actual}"
                )

        # Synchronize the sound_id sequence.
        sequence = target.execute(
            text("""
                SELECT pg_get_serial_sequence(
                    'public.sound',
                    'sound_id'
                )
            """)
        ).scalar_one()

        if sequence and source_rows["sound"]:
            max_id = target.execute(
                text("SELECT MAX(sound_id) FROM public.sound")
            ).scalar_one()

            target.execute(
                text("""
                    SELECT setval(
                        CAST(:sequence AS regclass),
                        :max_id,
                        true
                    )
                """),
                {
                    "sequence": sequence,
                    "max_id": max_id,
                },
            )

    print("\nTransfer completed successfully.")


if __name__ == "__main__":
    try:
        main()
    finally:
        source_engine.dispose()
        target_engine.dispose()
