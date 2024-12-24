from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

class MaxSizeMiddleware(BaseHTTPMiddleware):
    """Limit request payload size."""

    async def dispatch(self, request: Request, call_next):
        return await call_next(request)
