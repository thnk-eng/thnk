import os
import requests
from urllib.parse import urlencode
from .base import BaseAuthProvider
from typing import Any

class PrintfulAuthProvider(BaseAuthProvider):
    def __init__(self, state: str):
        self.state = state
        self.client_id = os.getenv('PRINTFUL_API_KEY')
        self.client_secret = os.getenv('PRINTFUL_API_SECRET')
        self.redirect_uri = os.getenv('PRINTFUL_REDIRECT_URI', 'https://your-domain.com/api/auth/callback/printful/')

    def get_authorization_url(self) -> str:
        scopes = 'read_products write_products'
        params = {
            'client_id': self.client_id,
            'response_type': 'code',
            'scope': scopes,
            'redirect_uri': self.redirect_uri,
            'state': self.state,
        }
        return f"https://www.printful.com/oauth/authorize?{urlencode(params)}"

    def exchange_code_for_token(self, code: str, state: str) -> str:
        token_request_url = "https://www.printful.com/oauth/token"
        token_payload = {
            'client_id': self.client_id,
            'client_secret': self.client_secret,
            'code': code,
            'grant_type': 'authorization_code',
            'redirect_uri': self.redirect_uri,
        }
        response = requests.post(token_request_url, data=token_payload)
        response.raise_for_status()
        return response.json()['access_token']

    def get_user_info(self, token: str) -> Any:
        headers = {'Authorization': f'Bearer {token}'}
        response = requests.get('https://api.printful.com/users/me', headers=headers)
        response.raise_for_status()
        return response.json()
