from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel, EmailStr, Field

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
    recordist: str | None = None
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

    categories: list[CategoryResponse] = Field(default_factory=list)
    sounds: list[SoundResponse] = Field(default_factory=list)

    model_config = {
        "from_attributes": True
    }

class DetectionIntervalResponse(BaseModel):
    start_time: Decimal
    end_time: Decimal

    model_config = {
        "from_attributes": True
    }


class IdentificationResponse(BaseModel):
    bird_id: int
    model_version: str | None
    detections: int
    max_confidence: Decimal | None
    avg_confidence: Decimal | None

    intervals: list[DetectionIntervalResponse] = Field(
        default_factory=list
    )

    bird: BirdResponse

    model_config = {
        "from_attributes": True
    }


class DetectionIntervalResponse(BaseModel):
    start_time: Decimal
    end_time: Decimal

    model_config = {"from_attributes": True}


class IdentifiedBirdResponse(BaseModel):
    bird_id: int
    scientific_name: str | None
    common_name: str | None

    model_config = {"from_attributes": True}


class IdentificationResponse(BaseModel):
    bird: IdentifiedBirdResponse
    detections: int
    max_confidence: Decimal | None
    avg_confidence: Decimal | None
    model_version: str | None
    intervals: list[DetectionIntervalResponse] = Field(
        default_factory=list
    )

    model_config = {"from_attributes": True}


class RecordingResponse(BaseModel):
    recording_id: int
    file_url: str | None
    duration: Decimal | None
    recorded_at: datetime | None
    location: str | None
    status: str | None
    confidence: Decimal | None

    model_config = {
        "from_attributes": True
    }
    identifications: list[IdentificationResponse] = Field(
        default_factory=list
    )

class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    user_id: int
    email: EmailStr
    created_at: datetime
    is_active: bool

    model_config = {
        "from_attributes": True
    }


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class RefreshTokenRequest(BaseModel):
    refresh_token: str
