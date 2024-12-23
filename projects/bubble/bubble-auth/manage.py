#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
import os
import sys


"""
import hashlib
import hmac

def validate_hmac(request):
    params = request.GET.dict()
    hmac_received = params.pop('hmac', None)
    sorted_params = "&".join([f"{k}={v}" for k, v in sorted(params.items())])
    secret = SHOPIFY_API_SECRET.encode('utf-8')
    hash = hmac.new(secret, sorted_params.encode('utf-8'), hashlib.sha256).hexdigest()
    return hmac.compare_digest(hash, hmac_received)

"""

def main():
    """Run administrative tasks."""
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'bubble_auth.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == '__main__':
    main()
