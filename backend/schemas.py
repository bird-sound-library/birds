from pydantic import BaseModel


class CategoryResponse(BaseModel):
    category_id: int
    name: str | None
    description: str | None

    model_config = {
        "from_attributes": True
    }


class SoundResponse(BaseModel):
    sound_id: int
    title: str | None
    file_url: str | None
    type: str | None
    source: str | None
    description: str | None
    duration: int | None

    model_config = {
        "from_attributes": True
    }


class BirdResponse(BaseModel):
    bird_id: int
    common_name: str | None
    scientific_name: str | None
    wikipedia_url: str | None
    image_url: str | None
    description: str | None

    categories: list[CategoryResponse] = []
    sounds: list[SoundResponse] = []

    model_config = {
        "from_attributes": True
    }