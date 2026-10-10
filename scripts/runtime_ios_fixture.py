"""Temporary demo-only native Firebase configuration for dedicated simulator builds.

Preserves the exact original bytes and restores them even if a build/test fails.
Never prints or copies the original configuration into performance artifacts.
"""
from contextlib import contextmanager
import plistlib


@contextmanager
def demo_firebase_plist(root):
    path = root / 'ios/Runner/GoogleService-Info.plist'
    original = path.read_bytes()
    fixture = plistlib.dumps({
        'API_KEY': 'AIzaSy000000000000000000000000000000000',
        'GOOGLE_APP_ID': '1:123456789:ios:0123456789abcdef',
        'GCM_SENDER_ID': '123456789',
        'PROJECT_ID': 'demo-flixie-review',
        'BUNDLE_ID': 'com.flixie.flixieApp',
        'STORAGE_BUCKET': 'demo-flixie-review.appspot.com',
        'PLIST_VERSION': '1',
        'IS_ADS_ENABLED': False,
        'IS_ANALYTICS_ENABLED': False,
        'IS_APPINVITE_ENABLED': False,
        'IS_GCM_ENABLED': False,
        'IS_SIGNIN_ENABLED': True,
    })
    info_path = root / 'ios/Runner/Info.plist'
    original_info = info_path.read_bytes()
    info = plistlib.loads(original_info)
    info['FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED'] = True
    info['FirebaseMessagingAutoInitEnabled'] = False
    fixture_info = plistlib.dumps(info)
    replacements = [(path, original, fixture), (info_path, original_info, fixture_info)]
    try:
        for target, _, temporary in replacements:
            target.write_bytes(temporary)
        yield
    finally:
        conflicts = []
        for target, saved, temporary in replacements:
            if target.read_bytes() != temporary:
                conflicts.append(target.name)
            else:
                target.write_bytes(saved)
        if conflicts:
            raise RuntimeError('Native config changed during capture; refusing to overwrite concurrent edits: ' + ', '.join(conflicts))
