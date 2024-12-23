# bubble motor

Server made specifically for ml models. Can be tweaked to allow custom models (it will soon). 

1. create a new directory & file
```bash
mkdir <your_project_name>
cd <your_project_name>
touch main.py
```

2. clone this repo 
```bash
git clone git@github.com:thnk-eng/bubble-motor.git
# OR
git clone https://github.com/thnk-eng/bubble-motor.git
```

3. Install requirements
```bash
pip install -r requirments.txt 
```

4. Put this in your `main.py` 
```python
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
```

4. Test it out
```bash
python main.py 
```

5. Openapi 
```json
{
  "openapi":"3.1.0",
  "info":{
    "title":"FastAPI",
    "version":"0.1.0"
  },
  "paths":{
    "/":{
      "get":{
        "summary":"Index",
        "operationId":"index__get",
        "responses":{
          "200":{
            "description":"Successful Response",
            "content":{
              "application/json":{
                "schema":{ }
              }
            }
          }
        }
      }
    },
    "/health":{
      "get":{
        "summary":"Health",
        "operationId":"health_health_get",
        "responses":{
          "200":{
            "description":"Successful Response",
            "content":{
              "application/json":{
                "schema":{ }
              }
            }
          }
        }
      }
    },
    "/predict":{
      "post":{
        "summary":"Predict",
        "operationId":"predict_predict_post",
        "responses":{
          "200":{
            "description":"Successful Response",
            "content":{
              "application/json":{
                "schema":{ }
              }
            }
          }
        }
      }
    }
  }
}
```
