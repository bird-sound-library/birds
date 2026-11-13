
from pathlib import Path
import json

from birdnet_service import BirdNETService


def main():
    service = BirdNETService(threshold=0.5)
    service.load_model()

    audio_dir = Path("test_audio")
    output_dir = Path("results")
    output_dir.mkdir(exist_ok=True)

    for audio_file in audio_dir.iterdir():
        if audio_file.suffix.lower() not in {
            ".wav", ".mp3", ".flac", ".ogg"
        }:
            continue

        print(f"\nProcessing: {audio_file.name}")

        result = service.recognize(audio_file)

        print(json.dumps(
            result,
            indent=4,
            ensure_ascii=False
        ))

        output_file = output_dir / f"{audio_file.stem}.json"

        with open(output_file, "w", encoding="utf-8") as file:
            json.dump(
                result,
                file,
                indent=4,
                ensure_ascii=False
            )

        print("Saved:", output_file)


if __name__ == "__main__":
    import multiprocessing
    multiprocessing.freeze_support()
    main()
