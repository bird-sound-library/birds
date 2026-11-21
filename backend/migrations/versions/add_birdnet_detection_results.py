
"""Add BirdNET detection results.

Revision ID: c2a71f4d9e10
Revises: 1915dde1c540
"""

from alembic import op
import sqlalchemy as sa


revision = "c2a71f4d9e10"
down_revision = "1915dde1c540"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "identified_as",
        sa.Column("detections", sa.Integer(), nullable=False, server_default="0")
    )

    op.add_column(
        "identified_as",
        sa.Column("max_confidence", sa.Numeric(5, 4), nullable=True)
    )

    op.add_column(
        "identified_as",
        sa.Column("avg_confidence", sa.Numeric(5, 4), nullable=True)
    )

    op.create_table(
        "detection_interval",
        sa.Column("recording_id", sa.Integer(), nullable=False),
        sa.Column("bird_id", sa.Integer(), nullable=False),
        sa.Column("interval_index", sa.Integer(), nullable=False),
        sa.Column("start_time", sa.Numeric(10, 3), nullable=False),
        sa.Column("end_time", sa.Numeric(10, 3), nullable=False),

        sa.PrimaryKeyConstraint(
            "recording_id",
            "bird_id",
            "interval_index"
        ),

        sa.ForeignKeyConstraint(
            ["recording_id", "bird_id"],
            ["identified_as.recording_id", "identified_as.bird_id"],
            ondelete="CASCADE"
        ),

        sa.CheckConstraint(
            "start_time >= 0 AND end_time >= start_time",
            name="ck_detection_interval_valid_time"
        )
    )

    # Remove the temporary default after existing rows are populated.
    op.alter_column(
        "identified_as",
        "detections",
        server_default=None
    )


def downgrade():
    op.drop_table("detection_interval")

    op.drop_column("identified_as", "avg_confidence")
    op.drop_column("identified_as", "max_confidence")
    op.drop_column("identified_as", "detections")
