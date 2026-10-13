from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session, selectinload

from database import get_db
from models import Bird
from schemas import BirdResponse, SoundResponse


app = FastAPI()


@app.get("/test-db")
def test_db(db: Session = Depends(get_db)):
    from sqlalchemy import text

    result = db.execute(text("SELECT 1"))
    return result.scalar()


@app.get("/birds", response_model=list[BirdResponse])
def get_birds(db: Session = Depends(get_db)):
    return db.query(Bird).all()


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