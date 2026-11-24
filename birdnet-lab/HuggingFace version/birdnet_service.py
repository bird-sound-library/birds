
from pathlib import Path

import numpy as np
import soundfile as sf
import torch

from scipy.signal import resample

import birdnet


class BirdNETService:
    SAMPLE_RATE = 32000
    SEGMENT_SECONDS = 3
    SEGMENT_SAMPLES = SAMPLE_RATE * SEGMENT_SECONDS

    def __init__(self, threshold=0.5):
        self.threshold = threshold

        self.model = None
        self.backend = None
        self.species_names = []

    def load_model(self):
        print("Loading BirdNET...")

        self.model = birdnet.load(
            "acoustic",
            "3.0",
            "pt"
        )

        self.species_names = list(self.model._species_list)

        print("Model loaded")
        print("Species:", len(self.species_names))

    def recognize(self, audio_path):
        """
        Recognize bird species in an audio recording.

        Returns:
            Dictionary containing detected species,
            confidence scores and detection intervals.
        """

        if self.model is None:
            raise RuntimeError("Model is not loaded")

        audio_path = Path(audio_path)

        if not audio_path.is_file():
            raise FileNotFoundError(audio_path)

        # Read audio as float32.
        audio, sample_rate = sf.read(
            audio_path,
            dtype="float32"
        )

        # Convert stereo to mono.
        if audio.ndim == 2:
            audio = np.mean(
                audio,
                axis=1,
                dtype=np.float32
            )

        duration = len(audio) / sample_rate

        if len(audio) == 0:
            return {
                "status": "no_match",
                "duration": 0.0,
                "species": []
            }

        # Resample audio to 32 kHz.
        if sample_rate != self.SAMPLE_RATE:
            new_length = round(
                len(audio) * self.SAMPLE_RATE / sample_rate
            )

            audio = resample(
                audio,
                new_length
            ).astype(np.float32)

        # Split audio into 3-second segments.
        segments = []

        for start in range(
            0,
            len(audio),
            self.SEGMENT_SAMPLES
        ):
            segment = audio[
                start:start + self.SEGMENT_SAMPLES
            ]

            # Pad the last segment with silence.
            if len(segment) < self.SEGMENT_SAMPLES:
                segment = np.pad(
                    segment,
                    (
                        0,
                        self.SEGMENT_SAMPLES - len(segment)
                    )
                )

            segments.append(segment)

        if not segments:
            return {
                "status": "no_match",
                "duration": duration,
                "species": []
            }

        batch = np.stack(segments).astype(np.float32)

        # Run inference directly through the PyTorch backend.
        
        print("\n--- INPUT DIAGNOSTICS ---")
        print("Audio sample rate:", self.SAMPLE_RATE)
        print("Audio shape:", batch.shape)
        print("Audio dtype:", batch.dtype)
        print("Audio min/max:", np.min(batch), np.max(batch))
        print("Audio finite:", np.isfinite(batch).all())

        with torch.inference_mode():
            tensor = self.backend.copy_to_device(batch)

            print("Input tensor:", tensor.shape)
            print("Input device:", tensor.device)
            print("Input dtype:", tensor.dtype)
            print("Input finite:", torch.isfinite(tensor).all().item())
            print("Input min/max:", tensor.min().item(), tensor.max().item())

            output = self.backend.predict(tensor)

            print("Output type:", type(output))

            if isinstance(output, torch.Tensor):
                print("Output shape:", output.shape)
                print("Output device:", output.device)
                print("Output dtype:", output.dtype)
                print("Output finite:", torch.isfinite(output).all().item())
                print("Output min/max:", output.min().item(), output.max().item())

            predictions = self.backend.copy_from_device(output)

        print("--- END DIAGNOSTICS ---\n")


        
        predictions = np.asarray(predictions)

        print("Prediction shape:", predictions.shape)
        print("Prediction dtype:", predictions.dtype)
        print("Prediction min:", np.nanmin(predictions))
        print("Prediction max:", np.nanmax(predictions))
        print("Prediction contains NaN:", np.isnan(predictions).any())
        print("Prediction contains Inf:", np.isinf(predictions).any())
        print("Finite values:", np.isfinite(predictions).sum())
        print("Total values:", predictions.size)

        if predictions.ndim != 2:
            raise RuntimeError(
                f"Unexpected prediction shape: {predictions.shape}"
            )

        if not np.isfinite(predictions).all():
            raise RuntimeError(
                "BirdNET returned NaN or Inf predictions"
            )

        if predictions.shape[1] != len(self.species_names):
            raise RuntimeError(
                f"Species mismatch: predictions={predictions.shape[1]}, "
                f"species={len(self.species_names)}"
            )

        print("First 10 predictions:", predictions[0][:10])


        print("Prediction shape:", predictions.shape)

        # Aggregate detections by species.
        results = {}

        for segment_idx, scores in enumerate(predictions):

            # Select top 5 predictions for this segment.
            top_indices = np.argsort(scores)[-5:][::-1]

            start_time = (
                segment_idx * self.SEGMENT_SECONDS
            )

            end_time = min(
                start_time + self.SEGMENT_SECONDS,
                duration
            )

            for species_idx in top_indices:

                confidence = float(scores[species_idx])

                if confidence < self.threshold:
                    continue

                name = self.species_names[species_idx]

                if name not in results:

                    scientific_name, common_name = name.split(
                        "_",
                        1
                    )

                    results[name] = {
                        "scientific_name": scientific_name,
                        "common_name": common_name,
                        "detections": 0,
                        "max_confidence": 0.0,
                        "confidence_sum": 0.0,
                        "first_seen": start_time,
                        "last_seen": end_time,
                        "intervals": []
                    }

                item = results[name]

                item["detections"] += 1

                item["confidence_sum"] += confidence

                item["max_confidence"] = max(
                    item["max_confidence"],
                    confidence
                )

                item["last_seen"] = end_time

                item["intervals"].append({
                    "start": start_time,
                    "end": end_time
                })

        # Calculate average confidence.
        species = []

        for item in results.values():

            item["avg_confidence"] = round(
                item.pop("confidence_sum") / item["detections"],
                4
            )

            item["max_confidence"] = round(
                item["max_confidence"],
                4
            )

            species.append(item)

        # Sort by maximum confidence.
        species.sort(
            key=lambda x: x["max_confidence"],
            reverse=True
        )

        if not species:
            return {
                "status": "no_match",
                "duration": duration,
                "species": []
            }

        return {
            "status": "completed",
            "duration": duration,
            "species": species
        }
    def test_predict(self, audio_path):
        print("Testing official BirdNET predict...")

        result = self.model.predict(str(audio_path))

        print("Result type:", type(result))
        print(result)

        return result