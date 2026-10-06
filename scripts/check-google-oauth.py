#!/usr/bin/env python3
"""Reject missing/deleted Android web OAuth clients before a release build."""
import json
from pathlib import Path
import sys
from urllib.error import HTTPError
from urllib.parse import urlencode, urlparse
from urllib.request import urlopen


def web_client(config):
    app = next(c for c in config['client'] if
               c['client_info']['android_client_info']['package_name'] == 'com.flixie.app')
    clients = [c['client_id'] for c in app.get('oauth_client', [])
               if c['client_type'] == 3]
    if len(clients) != 1:
        raise ValueError('Android needs exactly one web OAuth client (client_type 3).')
    return clients[0]


def validate_response(body, final_url):
    for code in ('deleted_client', 'invalid_client', 'redirect_uri_mismatch',
                 'unauthorized_client'):
        if code in body:
            raise ValueError(f'Google rejected the configured OAuth client: {code}.')
    location = urlparse(final_url)
    if (location.hostname != 'accounts.google.com' or '/signin' not in location.path
            or '/error' in location.path):
        raise ValueError('Google did not reach its sign-in page; verify OAuth configuration.')


def main():
    root = Path(__file__).resolve().parent.parent
    config = json.loads((root / 'android/app/google-services.json').read_text())
    client_id = web_client(config)
    project = config['project_info']['project_id']
    query = urlencode(dict(client_id=client_id,
                           redirect_uri=f'https://{project}.firebaseapp.com/__/auth/handler',
                           response_type='code', scope='openid email profile'))
    try:
        response = urlopen('https://accounts.google.com/o/oauth2/v2/auth?' + query, timeout=30)
    except HTTPError as error:
        response = error
    with response:
        validate_response(response.read().decode('utf-8'), response.geturl())
    print('Google OAuth client is active and accepts the Firebase callback.')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'Google OAuth preflight failed: {error}', file=sys.stderr)
        sys.exit(1)
