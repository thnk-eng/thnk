# Bubble Motor

A scalable API serving framework for machine learning models.

## Installation

```bash
pip install bubble_motor
```

## Quick Start

```python
from bubble_motor import BubbleAPI, BubbleServer

class MyAPI(BubbleAPI):
    async def setup(self, device):
        # Setup your model
        pass

    async def predict(self, x):
        # Make predictions
        return result

api = MyAPI()
server = BubbleServer(api)
server.run()
```
