"""add_user_sessions_and_recording_cascade

Revision ID: f4806c3f09da
Revises: e97c6a6790d0
Create Date: 2026-11-10 22:06:32.246243

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'f4806c3f09da'
down_revision: Union[str, Sequence[str], None] = 'e97c6a6790d0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Fix recording -> identified_as cascade
    op.drop_constraint(
        "identified_as_recording_id_fkey",
        "identified_as",
        type_="foreignkey"
    )

    op.create_foreign_key(
        "identified_as_recording_id_fkey",
        "identified_as",
        "recording",
        ["recording_id"],
        ["recording_id"],
        ondelete="CASCADE"
    )

    # Create user sessions
    op.create_table(
        "user_sessions",
        sa.Column(
            "session_id",
            postgresql.UUID(as_uuid=True),
            nullable=False
        ),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column(
            "refresh_token_hash",
            sa.String(length=64),
            nullable=False
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False
        ),
        sa.Column(
            "expires_at",
            sa.DateTime(timezone=True),
            nullable=False
        ),
        sa.Column(
            "revoked_at",
            sa.DateTime(timezone=True),
            nullable=True
        ),
        sa.PrimaryKeyConstraint("session_id"),
        sa.UniqueConstraint(
            "refresh_token_hash",
            name="uq_user_sessions_refresh_token_hash"
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.user_id"],
            ondelete="CASCADE",
            name="fk_user_sessions_user_id_users"
        )
    )

    op.create_index(
        "ix_user_sessions_user_id",
        "user_sessions",
        ["user_id"],
        unique=False
    )


def downgrade() -> None:
    op.drop_index(
        "ix_user_sessions_user_id",
        table_name="user_sessions"
    )

    op.drop_table("user_sessions")

    op.drop_constraint(
        "identified_as_recording_id_fkey",
        "identified_as",
        type_="foreignkey"
    )

    op.create_foreign_key(
        "identified_as_recording_id_fkey",
        "identified_as",
        "recording",
        ["recording_id"],
        ["recording_id"]
    )