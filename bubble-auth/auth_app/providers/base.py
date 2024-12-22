from abc import ABC, abstractmethod
from typing import Any

class BaseAuthProvider(ABC):
    @abstractmethod
    def get_authorization_url(self) -> str:
        pass

    @abstractmethod
    def exchange_code_for_token(self, code: str, state: str) -> str:
        pass

    @abstractmethod
    def get_user_info(self, token: str) -> Any:
        pass
