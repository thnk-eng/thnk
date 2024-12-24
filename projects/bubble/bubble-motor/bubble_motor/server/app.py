from fastapi import FastAPI
from typing import Optional

class BubbleServer:
    """Main server class for Bubble Motor."""

    def __init__(self, bubble_api, **kwargs):
        self.app = FastAPI()
        self.bubble_api = bubble_api
        self.setup_routes()

    def setup_routes(self):
        """Set up API routes."""
        pass

    async def run(self, port: int = 8000):
        """Run the server."""
        pass
