
# IMPORTANT: spaces must be imported before torch and birdnet.
import spaces
import gradio as gr

from birdnet_service import BirdNETService

print("Initializing BirdNET Service...", flush=True)

service = BirdNETService(threshold=0.5)

# Load and prepare the model during Space startup.
print("Loading BirdNET model...", flush=True)
service.load_model()
print("BirdNET model is ready.", flush=True)


@spaces.GPU(duration=60)
def recognize_audio(audio_path):
    if audio_path is None:
        raise gr.Error("Please upload an audio file.")

    try:
        result = service.recognize(audio_path)
        return result

    except Exception as exc:
        print(
            f"Inference error: {type(exc).__name__}: {exc}",
            flush=True
        )
        raise gr.Error("Bird recognition failed. Check Space logs.")


demo = gr.Interface(
    fn=recognize_audio,
    inputs=gr.File(
        label="Upload audio",
        file_types=["audio"],
        type="filepath"
    ),
    outputs=gr.JSON(label="Recognition results"),
    title="BirdNET 3.0",
    description=(
        "Upload a bird recording to identify bird species "
        "using BirdNET 3.0."
    )
)

demo.queue(default_concurrency_limit=1)
demo.launch()
