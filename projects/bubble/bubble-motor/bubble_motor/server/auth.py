from fastapi import HTTPException, Depends
from fastapi.security import APIKeyHeader

async def verify_api_key(api_key: str = Depends(APIKeyHeader(name="X-API-Key"))):
    """Verify API key middleware."""
    pass
