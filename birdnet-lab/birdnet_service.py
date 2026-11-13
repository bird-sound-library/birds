
from pathlib import Path

import torch
import birdnet


class BirdNETService:

    def __init__(self, threshold=0.5):
        self.threshold = threshold
        self.model = None

    def load_model(self):
        if not torch.cuda.is_available():
            raise RuntimeError("CUDA is not available")

        print("GPU:", torch.cuda.get_device_name(0))
        print("Loading BirdNET...")

        self.model = birdnet.load("acoustic", "3.0", "pt")

        print("BirdNET loaded")

    def recognize(self, audio_path):
        if self.model is None:
            raise RuntimeError("Model is not loaded")

        audio_path = Path(audio_path)

        if not audio_path.is_file():
            raise FileNotFoundError(audio_path)

        predictions = self.model.predict(str(audio_path))
        df = predictions.to_dataframe()

        filtered = df[
            df["confidence"] >= self.threshold
        ].copy()

        if filtered.empty:
            return {
                "status": "no_match",
                "duration": float(predictions.input_durations[0]),
                "species": []
            }

        summary = (
            filtered.groupby("species_name")
            .agg(
                detections=("confidence", "count"),
                max_confidence=("confidence", "max"),
                avg_confidence=("confidence", "mean"),
                first_seen=("start_time", "min"),
                last_seen=("end_time", "max")
            )
            .reset_index()
            .sort_values(
                "max_confidence",
                ascending=False
            )
        )

        species = []

        for name, group in filtered.groupby("species_name"):
            scientific_name, common_name = name.split("_", 1)

            intervals = merge_intervals(group)

            species.append({
                "scientific_name": scientific_name,
                "common_name": common_name,
                "detections": int(len(group)),
                "max_confidence": round(
                    float(group["confidence"].max()), 4
                ),
                "avg_confidence": round(
                    float(group["confidence"].mean()), 4
                ),
                "first_seen": intervals[0]["start"],
                "last_seen": intervals[-1]["end"],
                "intervals": intervals
            })

        species.sort(
            key=lambda item: item["max_confidence"],
            reverse=True
        )

        return {
            "status": "completed",
            "duration": float(predictions.input_durations[0]),
            "species": species
        }

def merge_intervals(rows, max_gap=3.0):
    intervals = []

    rows = rows.sort_values("start_time")

    for _, row in rows.iterrows():
        start = float(row["start_time"])
        end = float(row["end_time"])

        if not intervals or start - intervals[-1]["end"] > max_gap:
            intervals.append({
                "start": start,
                "end": end
            })
        else:
            intervals[-1]["end"] = max(
                intervals[-1]["end"],
                end
            )

    return intervals