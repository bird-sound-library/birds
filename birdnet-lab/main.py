
import os
import hmac
import tempfile
from pathlib import Path

from fastapi import FastAPI, UploadFile, File, Header, HTTPException
from contextlib import asynccontextmanager

from birdnet_service import BirdNETService


MAX_FILE_SIZE = 25 * 1024 * 1024

ALLOWED_EXTENSIONS = {
    ".wav",
    ".mp3",
    ".flac",
    ".ogg",
    ".m4a"
}

service = BirdNETService(threshold=0.5)


@asynccontextmanager
async def lifespan(app: FastAPI):
    print("Starting BirdNET inference server...")

    service.load_model()

    print("BirdNET is ready.")

    yield

    print("Shutting down BirdNET server...")


app = FastAPI(
    title="BirdNET Inference API",
    version="1.0.0",
    lifespan=lifespan
)


def verify_api_key(api_key):
    expected_key = os.getenv("BIRDNET_API_KEY")

    if not expected_key:
        raise HTTPException(
            status_code=500,
            detail="Server API key is not configured"
        )

    if not api_key or not hmac.compare_digest(
        api_key,
        expected_key
    ):
        raise HTTPException(
            status_code=401,
            detail="Invalid API key"
        )


@app.get("/")
def root():
    return {
        "service": "BirdNET Inference API",
        "status": "online"
    }


@app.get("/health")
def health():
    return {
        "status": "ready" if service.model is not None else "not_ready",
        "gpu": "CUDA"
    }


@app.post("/recognize")
def recognize(
    file: UploadFile = File(...),
    x_api_key: str = Header(
        default=None,
        alias="X-API-Key"
    )
):
    verify_api_key(x_api_key)

    extension = Path(file.filename or "").suffix.lower()

    if extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail="Unsupported audio format"
        )

    temp_path = None

    try:
        with tempfile.NamedTemporaryFile(
            suffix=extension,
            delete=False
        ) as temp_file:

            temp_path = Path(temp_file.name)

            total_size = 0

            while True:
                chunk = file.file.read(1024 * 1024)

                if not chunk:
                    break

                total_size += len(chunk)

                if total_size > MAX_FILE_SIZE:
                    raise HTTPException(
                        status_code=413,
                        detail="Audio file is too large"
                    )

                temp_file.write(chunk)

        result = service.recognize(temp_path)

        return result

    except HTTPException:
        raise

    except Exception as exc:
        print(
            f"Inference error: {type(exc).__name__}: {exc}"
        )

        raise HTTPException(
            status_code=500,
            detail="Bird recognition failed"
        )

    finally:
        if temp_path and temp_path.exists():
            temp_path.unlink()

        file.file.close()
