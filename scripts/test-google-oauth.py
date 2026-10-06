import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('oauth', Path(__file__).with_name('check-google-oauth.py'))
oauth = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oauth)


class GoogleOAuthTest(unittest.TestCase):
    def test_deleted_client_blocks_release(self):
        with self.assertRaisesRegex(ValueError, 'deleted_client'):
            oauth.validate_response('Error 401: deleted_client', 'https://accounts.google.com/signin/oauth/error')

    def test_unexpected_response_is_not_success(self):
        with self.assertRaises(ValueError):
            oauth.validate_response('Unknown failure', 'https://accounts.google.com/o/oauth2/v2/auth')

    def test_other_oauth_error_blocks_release(self):
        with self.assertRaises(ValueError):
            oauth.validate_response('Access denied', 'https://accounts.google.com/signin/oauth/error')

    def test_active_client_reaches_sign_in(self):
        oauth.validate_response('Sign in with Google', 'https://accounts.google.com/v3/signin/identifier')

    def test_android_client_is_not_web_client(self):
        config = {'client': [{'client_info': {'android_client_info': {'package_name': 'com.flixie.app'}},
                             'oauth_client': [{'client_id': 'android', 'client_type': 1}]}]}
        with self.assertRaises(ValueError):
            oauth.web_client(config)
        config['client'][0]['oauth_client'].append({'client_id': 'web', 'client_type': 3})
        self.assertEqual(oauth.web_client(config), 'web')


if __name__ == '__main__':
    unittest.main()
