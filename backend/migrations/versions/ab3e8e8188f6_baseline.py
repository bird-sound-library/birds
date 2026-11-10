
"""Initial database schema.

Revision ID: ab3e8e8188f6
"""

from alembic import op
import sqlalchemy as sa


revision = "ab3e8e8188f6"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "bird",
        sa.Column("bird_id", sa.Integer(), primary_key=True, autoincrement=False),
        sa.Column("common_name", sa.Text(), nullable=True),
        sa.Column("scientific_name", sa.Text(), nullable=True),
        sa.Column("wikipedia_url", sa.Text(), nullable=True),
        sa.Column("image_url", sa.Text(), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.UniqueConstraint("scientific_name", name="bird_scientific_name_key"),
    )

    op.create_table(
        "category",
        sa.Column("category_id", sa.Integer(), primary_key=True, autoincrement=False),
        sa.Column("name", sa.Text(), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("parent_category_id", sa.Integer(), nullable=True),
        sa.UniqueConstraint("name", name="category_name_key"),
        sa.ForeignKeyConstraint(
            ["parent_category_id"],
            ["category.category_id"],
            name="category_parent_category_id_fkey",
        ),
    )

    op.create_table(
        "sound",
        sa.Column("sound_id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("title", sa.Text(), nullable=True),
        sa.Column("file_url", sa.Text(), nullable=True),
        sa.Column("type", sa.Text(), nullable=True),
        sa.Column("source", sa.Text(), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("recorded_at", sa.DateTime(), nullable=True),
        sa.Column("category_id", sa.Integer(), nullable=True),
        sa.Column("duration", sa.Integer(), nullable=True),
        sa.Column("external_id", sa.Text(), nullable=True),
        sa.Column("license", sa.Text(), nullable=True),
        sa.Column("source_url", sa.Text(), nullable=True),
        sa.UniqueConstraint("external_id", name="sound_external_id_key"),
        sa.ForeignKeyConstraint(
            ["category_id"],
            ["category.category_id"],
            name="sound_category_id_fkey",
        ),
    )

    op.create_table(
        "recording",
        sa.Column("recording_id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("file_url", sa.Text(), nullable=True),
        sa.Column("duration", sa.Numeric(), nullable=True),
        sa.Column("recorded_at", sa.DateTime(), nullable=True),
        sa.Column("location", sa.Text(), nullable=True),
        sa.Column("status", sa.Text(), nullable=True),
        sa.Column("confidence", sa.Numeric(), nullable=True),
    )

    op.create_table(
        "bird_category",
        sa.Column("bird_id", sa.Integer(), nullable=True),
        sa.Column("category_id", sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(
            ["bird_id"],
            ["bird.bird_id"],
            name="bird_category_bird_id_fkey",
        ),
        sa.ForeignKeyConstraint(
            ["category_id"],
            ["category.category_id"],
            name="bird_category_category_id_fkey",
        ),
    )

    op.create_table(
        "has",
        sa.Column("bird_id", sa.Integer(), nullable=False),
        sa.Column("sound_id", sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint("bird_id", "sound_id", name="has_pkey"),
        sa.ForeignKeyConstraint(
            ["bird_id"],
            ["bird.bird_id"],
            name="has_bird_id_fkey",
        ),
        sa.ForeignKeyConstraint(
            ["sound_id"],
            ["sound.sound_id"],
            name="has_sound_id_fkey",
        ),
    )

    op.create_table(
        "classifies",
        sa.Column("bird_id", sa.Integer(), nullable=False),
        sa.Column("category_id", sa.Integer(), nullable=False),
        sa.Column("sound_id", sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint(
            "bird_id", "category_id", "sound_id",
            name="classifies_pkey",
        ),
        sa.ForeignKeyConstraint(
            ["bird_id"],
            ["bird.bird_id"],
            name="classifies_bird_id_fkey",
        ),
        sa.ForeignKeyConstraint(
            ["category_id"],
            ["category.category_id"],
            name="classifies_category_id_fkey",
        ),
        sa.ForeignKeyConstraint(
            ["sound_id"],
            ["sound.sound_id"],
            name="classifies_sound_id_fkey",
        ),
    )

    op.create_table(
        "identified_as",
        sa.Column("recording_id", sa.Integer(), nullable=False),
        sa.Column("bird_id", sa.Integer(), nullable=False),
        sa.Column("model_version", sa.Text(), nullable=True),
        sa.Column("identified_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint(
            "recording_id", "bird_id",
            name="identified_as_pkey",
        ),
        sa.ForeignKeyConstraint(
            ["recording_id"],
            ["recording.recording_id"],
            name="identified_as_recording_id_fkey",
        ),
        sa.ForeignKeyConstraint(
            ["bird_id"],
            ["bird.bird_id"],
            name="identified_as_bird_id_fkey",
        ),
    )


def downgrade():
    op.drop_table("identified_as")
    op.drop_table("classifies")
    op.drop_table("has")
    op.drop_table("bird_category")
    op.drop_table("recording")
    op.drop_table("sound")
    op.drop_table("category")
    op.drop_table("bird")
