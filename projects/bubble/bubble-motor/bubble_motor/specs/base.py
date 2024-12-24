from abc import ABC, abstractmethod

class BaseSpec(ABC):
    """Base class for API specifications."""

    @abstractmethod
    def decode_request(self, request):
        pass

    @abstractmethod
    def encode_response(self, response):
        pass
