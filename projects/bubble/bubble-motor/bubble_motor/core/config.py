from pydantic import BaseSettings

class BubbleMotorSettings(BaseSettings):
    """Global configuration settings."""

    max_batch_size: int = 1
    batch_timeout: float = 0.001
    request_timeout: float = 30.0
    max_workers: int = 1
    api_key: str = None
    log_level: str = "info"

    class Config:
        env_prefix = "BUBBLE_MOTOR_"

settings = BubbleMotorSettings()
