from dependencies import get_current_user
import uuid
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from database import get_db
from models import User, UserSession
from schemas import (
    UserCreate,
    UserLogin,
    UserResponse,
    TokenResponse,
    RefreshTokenRequest
)
from security import (
    hash_password,
    verify_password,
    hash_refresh_token,
    create_access_token,
    create_refresh_token,
    decode_token,
    REFRESH_TOKEN_EXPIRE_DAYS
)

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"]
)


def create_session_tokens(
    user: User,
    db: Session
) -> TokenResponse:

    session_id = uuid.uuid4()

    refresh_token = create_refresh_token(
        user.user_id,
        str(session_id)
    )

    session = UserSession(
        session_id=session_id,
        user_id=user.user_id,
        refresh_token_hash=hash_refresh_token(refresh_token),
        expires_at=datetime.now(timezone.utc)
        + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    )

    db.add(session)

    access_token = create_access_token(user.user_id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token
    )


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=201
)
def register(
    data: UserCreate,
    db: Session = Depends(get_db)
):
    email = str(data.email).strip().lower()

    user = User(
        email=email,
        password_hash=hash_password(data.password)
    )

    db.add(user)

    try:
        db.commit()
        db.refresh(user)

    except IntegrityError:
        db.rollback()

        raise HTTPException(
            status_code=409,
            detail="Email is already registered"
        )

    return user


@router.post(
    "/login",
    response_model=TokenResponse
)
def login(
    data: UserLogin,
    db: Session = Depends(get_db)
):
    email = str(data.email).strip().lower()

    user = db.scalar(
        select(User).where(User.email == email)
    )

    if (
        user is None
        or not verify_password(data.password, user.password_hash)
    ):
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password"
        )

    if not user.is_active:
        raise HTTPException(
            status_code=403,
            detail="Account is inactive"
        )

    tokens = create_session_tokens(user, db)

    db.commit()

    return tokens


@router.post(
    "/refresh",
    response_model=TokenResponse
)
def refresh(
    data: RefreshTokenRequest,
    db: Session = Depends(get_db)
):
    try:
        payload = decode_token(data.refresh_token)

        if payload.get("type") != "refresh":
            raise ValueError("Wrong token type")

        user_id = int(payload["sub"])
        session_id = uuid.UUID(payload["sid"])

    except (jwt.InvalidTokenError, ValueError, KeyError, TypeError):
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired refresh token"
        )

    session = db.scalar(
        select(UserSession)
        .where(UserSession.session_id == session_id)
        .with_for_update()
    )

    if session is None:
        raise HTTPException(
            status_code=401,
            detail="Session not found"
        )

    token_hash = hash_refresh_token(data.refresh_token)

    if not secrets.compare_digest(
        session.refresh_token_hash,
        token_hash
    ):
        raise HTTPException(
            status_code=401,
            detail="Refresh token has already been rotated"
        )

    now = datetime.now(timezone.utc)

    if session.revoked_at is not None or session.expires_at <= now:
        raise HTTPException(
            status_code=401,
            detail="Session expired or revoked"
        )

    user = db.get(User, user_id)

    if user is None or not user.is_active or session.user_id != user_id:
        raise HTTPException(
            status_code=401,
            detail="User is inactive or unavailable"
        )

    new_refresh_token = create_refresh_token(
        user.user_id,
        str(session.session_id)
    )

    session.refresh_token_hash = hash_refresh_token(
        new_refresh_token
    )

    session.expires_at = now + timedelta(
        days=REFRESH_TOKEN_EXPIRE_DAYS
    )

    new_access_token = create_access_token(user.user_id)

    db.commit()

    return TokenResponse(
        access_token=new_access_token,
        refresh_token=new_refresh_token
    )


@router.post("/logout")
def logout(
    data: RefreshTokenRequest,
    db: Session = Depends(get_db)
):
    try:
        payload = decode_token(data.refresh_token)

        if payload.get("type") != "refresh":
            raise ValueError("Wrong token type")

        session_id = uuid.UUID(payload["sid"])

    except (jwt.InvalidTokenError, ValueError, KeyError, TypeError):
        return {"message": "Logged out"}

    session = db.get(UserSession, session_id)

    if session is not None:
        token_hash = hash_refresh_token(data.refresh_token)

        if secrets.compare_digest(
            session.refresh_token_hash,
            token_hash
        ):
            session.revoked_at = datetime.now(timezone.utc)
            db.commit()

    return {"message": "Logged out"}


@router.get(
    "/me",
    response_model=UserResponse
)
def get_me(
    user: User = Depends(get_current_user)
):
    return user
