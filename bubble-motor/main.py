import asyncio
from typing import Any
from bubble_motor.server import BubbleAPI, BubbleServer

class MyBubbleAPI(BubbleAPI):
    async def setup(self, device: str):
        print(f"Setting up MyBubbleAPI on device: {device}")
        # Add any specific setup logic here

    async def predict(self, x: Any, **kwargs) -> Any:
        # This is a dummy prediction. Replace with your actual prediction logic.
        return f"MyBubbleAPI Prediction for input: {x}"

if __name__ == "__main__":
    bubble_api = MyBubbleAPI()
    server = BubbleServer(bubble_api)
    asyncio.run(server.run())
