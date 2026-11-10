from settings import settings
import hashlib
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from pwdlib import PasswordHash

JWT_SECRET_KEY = settings.jwt_secret_key.get_secret_value()
JWT_ALGORITHM = settings.jwt_algorithm

ACCESS_TOKEN_EXPIRE_MINUTES = (
    settings.access_token_expire_minutes
)

REFRESH_TOKEN_EXPIRE_DAYS = (
    settings.refresh_token_expire_days
)

if not JWT_SECRET_KEY:
    raise RuntimeError("JWT_SECRET_KEY is not configured")

password_hash = PasswordHash.recommended()


def hash_password(password: str) -> str:
    return password_hash.hash(password)


def verify_password(password: str, hashed_password: str) -> bool:
    return password_hash.verify(password, hashed_password)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def create_access_token(user_id: int) -> str:
    now = datetime.now(timezone.utc)

    payload = {
        "sub": str(user_id),
        "type": "access",
        "iat": now,
        "exp": now + timedelta(
            minutes=ACCESS_TOKEN_EXPIRE_MINUTES
        ),
    }

    return jwt.encode(
        payload,
        JWT_SECRET_KEY,
        algorithm=JWT_ALGORITHM
    )


def create_refresh_token(user_id: int, session_id: str) -> str:
    now = datetime.now(timezone.utc)

    payload = {
        "sub": str(user_id),
        "sid": session_id,
        "type": "refresh",
        "jti": secrets.token_urlsafe(16),
        "iat": now,
        "exp": now + timedelta(
            days=REFRESH_TOKEN_EXPIRE_DAYS
        ),
    }

    return jwt.encode(
        payload,
        JWT_SECRET_KEY,
        algorithm=JWT_ALGORITHM
    )


def decode_token(token: str) -> dict:
    return jwt.decode(
        token,
        JWT_SECRET_KEY,
        algorithms=[JWT_ALGORITHM],
        options={
            "require": ["sub", "type", "iat", "exp"]
        }
    )
