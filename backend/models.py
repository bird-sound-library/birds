from datetime import datetime
from decimal import Decimal
import uuid

from sqlalchemy import (
    Integer,
    Text,
    String,
    Numeric,
    DateTime,
    ForeignKey,
    Table,
    Column,
    Boolean,
    func,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database import Base


# ============================================================
# Association table: bird <-> category
# ============================================================

bird_category = Table(
    "bird_category",
    Base.metadata,
    Column(
        "bird_id",
        ForeignKey("bird.bird_id"),
    ),
    Column(
        "category_id",
        ForeignKey("category.category_id"),
    ),
)


# ============================================================
# Association table: bird <-> sound
# ============================================================

has_sound = Table(
    "has",
    Base.metadata,
    Column(
        "bird_id",
        ForeignKey("bird.bird_id"),
    ),
    Column(
        "sound_id",
        ForeignKey("sound.sound_id"),
    ),
)


# ============================================================
# Bird
# ============================================================

class Bird(Base):
    __tablename__ = "bird"

    bird_id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True
    )

    common_name: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    scientific_name: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    wikipedia_url: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    image_url: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    # Bird <-> Category
    categories: Mapped[list["Category"]] = relationship(
        secondary=bird_category,
        back_populates="birds"
    )

    # Bird <-> Sound
    sounds: Mapped[list["Sound"]] = relationship(
        secondary=has_sound,
        back_populates="birds"
    )

    # Bird <-> Classifies
    classifications: Mapped[list["Classifies"]] = relationship(
        back_populates="bird"
    )

    # Bird <-> IdentifiedAs
    identifications: Mapped[list["IdentifiedAs"]] = relationship(
        back_populates="bird"
    )


# ============================================================
# Category
# ============================================================

class Category(Base):
    __tablename__ = "category"

    category_id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True
    )

    name: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    parent_category_id: Mapped[int | None] = mapped_column(
        ForeignKey("category.category_id"),
        nullable=True
    )

    # Parent category
    parent: Mapped["Category | None"] = relationship(
        "Category",
        remote_side=[category_id],
        back_populates="children"
    )

    # Child categories
    children: Mapped[list["Category"]] = relationship(
        "Category",
        back_populates="parent"
    )

    # Bird <-> Category
    birds: Mapped[list["Bird"]] = relationship(
        secondary=bird_category,
        back_populates="categories"
    )

    # Classifications
    classifications: Mapped[list["Classifies"]] = relationship(
        back_populates="category"
    )

    # Sounds belonging to category
    sounds: Mapped[list["Sound"]] = relationship(
        back_populates="category"
    )


# ============================================================
# Sound
# ============================================================

class Sound(Base):
    __tablename__ = "sound"

    sound_id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True
    )

    title: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    file_url: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    external_id: Mapped[str | None] = mapped_column(
        Text,
        unique=True,
        nullable=True
    )

    license: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    source_url: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    type: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    source: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    recorded_at: Mapped[datetime | None] = mapped_column(
        DateTime,
        nullable=True
    )

    category_id: Mapped[int | None] = mapped_column(
        ForeignKey("category.category_id"),
        nullable=True
    )

    duration: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    # Category
    category: Mapped["Category | None"] = relationship(
        back_populates="sounds"
    )

    # Bird <-> Sound
    birds: Mapped[list["Bird"]] = relationship(
        secondary=has_sound,
        back_populates="sounds"
    )

    # Classifications
    classifications: Mapped[list["Classifies"]] = relationship(
        back_populates="sound"
    )

# ============================================================
# User
# ============================================================

class User(Base):
    __tablename__ = "users"

    user_id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True
    )

    email: Mapped[str] = mapped_column(
        String(320),
        unique=True,
        index=True,
        nullable=False
    )

    password_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False
    )

    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="true",
        nullable=False
    )

    recordings: Mapped[list["Recording"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True
    )

    sessions: Mapped[list["UserSession"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True
    )

class UserSession(Base):
    __tablename__ = "user_sessions"

    session_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    refresh_token_hash: Mapped[str] = mapped_column(
        String(64),
        unique=True,
        nullable=False
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False
    )

    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False
    )

    revoked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    user: Mapped["User"] = relationship(
        back_populates="sessions"
    )

# ============================================================
# Recording
# ============================================================

class Recording(Base):
    __tablename__ = "recording"

    recording_id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    file_url: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    duration: Mapped[Decimal | None] = mapped_column(
        Numeric,
        nullable=True
    )

    recorded_at: Mapped[datetime | None] = mapped_column(
        DateTime,
        nullable=True
    )

    location: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    status: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    confidence: Mapped[Decimal | None] = mapped_column(
        Numeric,
        nullable=True
    )

    # Identification results
    user: Mapped["User"] = relationship(
        back_populates="recordings"
    )

    identifications: Mapped[list["IdentifiedAs"]] = relationship(
        back_populates="recording",
        cascade="all, delete-orphan",
        passive_deletes=True
    )


# ============================================================
# Classifies
# ============================================================

class Classifies(Base):
    __tablename__ = "classifies"

    # Composite Primary Key:
    # bird_id + category_id + sound_id

    bird_id: Mapped[int] = mapped_column(
        ForeignKey("bird.bird_id"),
        primary_key=True
    )

    category_id: Mapped[int] = mapped_column(
        ForeignKey("category.category_id"),
        primary_key=True
    )

    sound_id: Mapped[int] = mapped_column(
        ForeignKey("sound.sound_id"),
        primary_key=True
    )

    bird: Mapped["Bird"] = relationship(
        back_populates="classifications"
    )

    category: Mapped["Category"] = relationship(
        back_populates="classifications"
    )

    sound: Mapped["Sound"] = relationship(
        back_populates="classifications"
    )


# ============================================================
# IdentifiedAs
# ============================================================

class IdentifiedAs(Base):
    __tablename__ = "identified_as"

    # Composite Primary Key:
    # recording_id + bird_id

    recording_id: Mapped[int] = mapped_column(
        ForeignKey("recording.recording_id", ondelete="CASCADE"),
        primary_key=True
    )

    bird_id: Mapped[int] = mapped_column(
        ForeignKey("bird.bird_id"),
        primary_key=True
    )

    model_version: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    identified_at: Mapped[datetime | None] = mapped_column(
        DateTime,
        nullable=True
    )

    recording: Mapped["Recording"] = relationship(
        back_populates="identifications"
    )

    bird: Mapped["Bird"] = relationship(
        back_populates="identifications"
    )