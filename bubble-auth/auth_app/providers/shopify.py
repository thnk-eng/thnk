import os
import requests
import hmac
import hashlib
from urllib.parse import urlencode
from .base import BaseAuthProvider
from typing import Any

class ShopifyAuthProvider(BaseAuthProvider):
    def __init__(self, shop: str, state: str):
        self.shop = shop
        self.state = state
        self.client_id = os.getenv('SHOPIFY_API_KEY')
        self.client_secret = os.getenv('SHOPIFY_API_SECRET')
        self.redirect_uri = os.getenv('SHOPIFY_REDIRECT_URI', 'https://your-domain.com/api/auth/callback/shopify/')

    def get_authorization_url(self) -> str:
        scopes = 'read_products,write_products'
        params = {
            'client_id': self.client_id,
            'scope': scopes,
            'redirect_uri': self.redirect_uri,
            'state': self.state,
        }
        return f"https://{self.shop}/admin/oauth/authorize?{urlencode(params)}"

    def exchange_code_for_token(self, code: str, state: str) -> str:
        token_request_url = f"https://{self.shop}/admin/oauth/access_token"
        token_payload = {
            'client_id': self.client_id,
            'client_secret': self.client_secret,
            'code': code
        }
        response = requests.post(token_request_url, data=token_payload)
        response.raise_for_status()
        return response.json()['access_token']

    def get_user_info(self, token: str) -> Any:
        # Implement method to get user info if needed
        return {'shop': self.shop}

    def validate_hmac(self, params: dict) -> bool:
        hmac_received = params.pop('hmac', None)
        sorted_params = "&".join([f"{k}={v}" for k, v in sorted(params.items())])
        secret = self.client_secret.encode('utf-8')
        hash = hmac.new(secret, sorted_params.encode('utf-8'), hashlib.sha256).hexdigest()
        return hmac.compare_digest(hash, hmac_received or '')
