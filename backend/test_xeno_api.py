
import requests
from settings import settings

API_URL = "https://xeno-canto.org/api/3/recordings"

queries = [
    "1175751",
    "nr:1175751",
    "recording:1175751",
]

for query in queries:
    response = requests.get(
        API_URL,
        params={
            "query": query,
            "key": settings.xeno_canto_api_key,
        },
        timeout=30,
    )

    print(f"\nQuery: {query}")
    print("HTTP:", response.status_code)

    data = response.json()
    recordings = data.get("recordings", [])

    print("Total:", data.get("numRecordings"))

    for recording in recordings[:3]:
        print(
            recording.get("id"),
            recording.get("rec"),
            recording.get("en"),
        )
