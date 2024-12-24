class BubbleMotorError(Exception):
    """Base exception for Bubble Motor."""
    pass

class ConfigurationError(BubbleMotorError):
    """Configuration related errors."""
    pass

class DeviceError(BubbleMotorError):
    """Device related errors."""
    pass
