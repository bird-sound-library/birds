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
    title: str | None = None
    file_url: str | None = None
    type: str | None = None
    source: str | None = None
    description: str | None = None
    duration: int | None = None
    external_id: str | None = None
    license: str | None = None
    source_url: str | None = None

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