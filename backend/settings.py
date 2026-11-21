
from pathlib import Path

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


BASE_DIR = Path(__file__).resolve().parent


class Settings(BaseSettings):
    hf_space_id: str = "Mickhail719/birdnet-inference"
    hf_token: SecretStr = SecretStr("")
    birdnet_inference_url: str = "http://127.0.0.1:8001"
    birdnet_api_key: SecretStr = SecretStr("")
    model_config = SettingsConfigDict(
        env_file=BASE_DIR / ".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    database_url: str

    jwt_secret_key: SecretStr
    jwt_algorithm: str = "HS256"

    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 7
    
    cors_origins: list[str] = [
        "http://localhost:5000",
        "http://127.0.0.1:5000",
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "https://bird-sound-library.github.io",
    ]

    xeno_canto_api_key: str

settings = Settings()
