from abc import ABC, abstractmethod
from typing import Any, Optional, List

class BubbleSpec(ABC):
    """Base specification class for API formats."""

    def __init__(self):
        self._endpoints = []
        self._server = None

    @abstractmethod
    def decode_request(self, request: Any) -> Any:
        """Convert request payload to model input."""
        pass

    @abstractmethod
    def encode_response(self, output: Any) -> Any:
        """Convert model output to response payload."""
        pass

class BubbleAPI(ABC):
    """Base class for model inference APIs."""

    @abstractmethod
    async def setup(self, device: str):
        """Set up the model for inference."""
        pass

    @abstractmethod
    async def predict(self, x: Any) -> Any:
        """Run model inference."""
        pass
