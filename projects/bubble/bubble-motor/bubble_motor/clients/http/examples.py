"""HTTP client examples."""

import requests

def simple_request():
    """Example of a simple prediction request."""
    response = requests.post(
        "http://localhost:8000/predict",
        json={"input": "example"}
    )
    return response.json()
