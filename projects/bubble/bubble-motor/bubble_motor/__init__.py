"""
Bubble Motor - A scalable API serving framework
"""

from .core.base import BubbleAPI, BubbleSpec
from .server import BubbleServer

__version__ = "0.1.0"
__all__ = ["BubbleAPI", "BubbleSpec", "BubbleServer"]
