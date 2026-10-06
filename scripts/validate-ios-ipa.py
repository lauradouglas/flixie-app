#!/usr/bin/env python3
"""Reject a release IPA whose signed app lost required capabilities."""
import plistlib
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path


def validate(ipa):
    with tempfile.TemporaryDirectory(prefix='flixie-ipa-check-') as directory:
        with zipfile.ZipFile(ipa) as archive:
            archive.extractall(directory)
        apps = list(Path(directory).glob('Payload/*.app'))
        if len(apps) != 1:
            raise ValueError('Expected exactly one application in IPA')
        result = subprocess.run(
            ['codesign', '-d', '--entitlements', '-', '--xml', str(apps[0])],
            check=True, capture_output=True,
        )
        entitlements = plistlib.loads(result.stdout)
        required = {
            'application-identifier': '4T69VPQXW6.com.flixie.flixieApp',
            'com.apple.developer.applesignin': ['Default'],
            'aps-environment': 'production',
            'com.apple.developer.associated-domains': ['applinks:www.flixie.co.uk'],
            'get-task-allow': False,
        }
        for key, expected in required.items():
            if entitlements.get(key) != expected:
                raise ValueError(f'Signed IPA has missing or incorrect entitlement: {key}')
        info = plistlib.loads((apps[0] / 'Info.plist').read_bytes())
        print(f"Verified signed release entitlements: {info['CFBundleShortVersionString']} ({info['CFBundleVersion']})")


if __name__ == '__main__':
    validate(sys.argv[1])
