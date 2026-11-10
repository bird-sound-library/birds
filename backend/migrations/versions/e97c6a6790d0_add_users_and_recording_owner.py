
"""add_users_and_recording_owner

Revision ID: e97c6a6790d0
Revises: ab3e8e8188f6
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "e97c6a6790d0"
down_revision: Union[str, Sequence[str], None] = "ab3e8e8188f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create users table
    op.create_table(
        "users",
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("email", sa.String(320), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            server_default=sa.text("true"),
            nullable=False
        ),
        sa.PrimaryKeyConstraint("user_id")
    )

    op.create_index(
        "ix_users_email",
        "users",
        ["email"],
        unique=True
    )

    # 2. Delete old identification results
    op.execute("DELETE FROM identified_as")

    # 3. Delete old recordings
    op.execute("DELETE FROM recording")

    # 4. Add user_id to recording
    op.add_column(
        "recording",
        sa.Column("user_id", sa.Integer(), nullable=False)
    )

    # 5. Create foreign key
    op.create_foreign_key(
        "fk_recording_user_id_users",
        "recording",
        "users",
        ["user_id"],
        ["user_id"],
        ondelete="CASCADE"
    )

    # 6. Create index
    op.create_index(
        "ix_recording_user_id",
        "recording",
        ["user_id"],
        unique=False
    )


def downgrade() -> None:
    op.drop_index(
        "ix_recording_user_id",
        table_name="recording"
    )

    op.drop_constraint(
        "fk_recording_user_id_users",
        "recording",
        type_="foreignkey"
    )

    op.drop_column("recording", "user_id")

    op.drop_index(
        "ix_users_email",
        table_name="users"
    )

    op.drop_table("users")
