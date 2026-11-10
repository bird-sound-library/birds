from sqlalchemy.engine import make_url
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

from settings import settings


engine = create_engine(
    settings.database_url,
    pool_pre_ping=True
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

url = make_url(str(engine.url))

print("SQLAlchemy Engine:")
print("Host:", url.host)
print("Port:", url.port)
print("Database:", url.database)

class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()
