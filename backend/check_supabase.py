
from sqlalchemy import text
from database import engine

with engine.connect() as conn:
    tables = conn.execute(text("""
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_type = 'BASE TABLE'
        ORDER BY table_name;
    """)).fetchall()

    print("TABLES:")
    for table in tables:
        print("-", table[0])

    print("\nROW COUNTS:")
    for table in tables:
        name = table[0]
        count = conn.execute(
            text(f'SELECT COUNT(*) FROM "{name}"')
        ).scalar_one()
        print(f"{name}: {count}")
