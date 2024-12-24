import aiohttp
from typing import Any, Optional

class BubbleClient:
    """Python client for Bubble Motor."""

    def __init__(self, base_url: str, api_key: Optional[str] = None):
        self.base_url = base_url
        self.api_key = api_key

    async def predict(self, data: Any):
        """Make prediction request."""
        pass
