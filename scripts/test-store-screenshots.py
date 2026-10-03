#!/usr/bin/env python3
"""Host runner checks without SDKs, device reinstalls, credentials or uploads."""
import contextlib
import importlib.util
import io
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

spec = importlib.util.spec_from_file_location('screenshots', Path(__file__).with_name('store-screenshots.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


def png(width=2, height=3):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress((b'\0' + b'\0' * width * 3) * height))
            + chunk(b'IEND', b''))


def rgba_png(filter_type, alpha=255):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    rows = [bytes([10 + y, 30, 80, alpha, 90, 20 + y, 5, alpha]) for y in range(3)]
    encoded = bytearray()
    previous = bytes(8)
    for row in rows:
        encoded.append(filter_type)
        for i, value in enumerate(row):
            a, b, c = row[i - 4] if i >= 4 else 0, previous[i], previous[i - 4] if i >= 4 else 0
            if filter_type == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                predictor = a if pa <= pb and pa <= pc else b if pb <= pc else c
            else:
                predictor = [0, a, b, (a + b) // 2][filter_type]
            encoded.append((value - predictor) & 255)
        previous = row
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 2, 3, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(encoded)) + chunk(b'IEND', b'')), rows


class ScreenshotRunnerTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.previous_root = runner.ROOT
        runner.ROOT = Path(self.temporary.name)
        self.destination = runner.ROOT / 'fastlane/screenshots/en-GB'
        self.staging = runner.ROOT / 'staging'
        self.staging.mkdir()
        self.manifest = {'platform': 'ios', 'locale': 'en-GB', 'device': 'iPhone-test', 'screenshots': []}
        for scene in runner.SCENES:
            name = f'iPhone-test-{scene}.png'
            (self.staging / name).write_bytes(png())
            self.manifest['screenshots'].append({'scene': scene, 'file': name, 'width': 2, 'height': 3})

    def tearDown(self):
        runner.ROOT = self.previous_root
        self.temporary.cleanup()

    def validate(self):
        with contextlib.redirect_stdout(io.StringIO()):
            runner.validate('ios', 'en-GB')

    def test_complete_capture_publishes_only_images_and_validates(self):
        runner.publish(self.staging, self.destination, self.manifest)
        self.assertEqual(len(list(self.destination.iterdir())), len(runner.SCENES))
        self.validate()

    def test_selected_capture_preserves_other_images(self):
        runner.publish(self.staging, self.destination, self.manifest)
        before = {p.name: p.read_bytes() for p in self.destination.iterdir()}
        selected = self.manifest['screenshots'][-1]
        (self.staging / selected['file']).write_bytes(png(3, 4))
        partial = dict(self.manifest, screenshots=[dict(selected, width=3, height=4)])
        runner.publish_selected(self.staging, self.destination, partial)
        self.validate()
        for name, data in before.items():
            if name != selected['file']:
                self.assertEqual((self.destination / name).read_bytes(), data)
        self.assertNotEqual((self.destination / selected['file']).read_bytes(), before[selected['file']])

    def test_native_android_dialogs_are_rejected_but_stale_windows_are_ignored(self):
        for title in ['Application Not Responding: com.android.systemui',
                      'Application Error: com.flixie.app']:
            with self.assertRaisesRegex(ValueError, 'system error dialog'):
                runner.reject_android_system_dialog('mCurrentFocus=Window{abc u0 ' + title + '}')
        runner.reject_android_system_dialog(
            'Window #2 Application Not Responding: com.android.systemui\n'
            'mCurrentFocus=Window{abc u0 com.flixie.app/MainActivity}')

    def test_upload_rejects_a_complete_set_that_failed_visual_review(self):
        self.manifest['review_failure'] = 'Native system dialog covers the page'
        runner.publish(self.staging, self.destination, self.manifest)
        with self.assertRaisesRegex(ValueError, 'visual review failed'):
            self.validate()

    def test_upload_rejects_absent_capture(self):
        with self.assertRaisesRegex(ValueError, 'Capture screenshots first'):
            self.validate()

    def test_upload_rejects_missing_or_invalid_png(self):
        runner.publish(self.staging, self.destination, self.manifest)
        image = next(self.destination.glob('*.png'))
        image.write_bytes(b'not an image')
        with self.assertRaisesRegex(ValueError, 'Invalid screenshot PNG'):
            self.validate()
        image.unlink()
        with self.assertRaises(FileNotFoundError):
            self.validate()

    def test_upload_rejects_stale_extra_images(self):
        runner.publish(self.staging, self.destination, self.manifest)
        (self.destination / 'old.png').write_bytes(png())
        with self.assertRaisesRegex(ValueError, 'unreviewed PNGs'):
            self.validate()

    def test_upload_rejects_partial_manifest(self):
        self.manifest['screenshots'].pop()
        runner.publish(self.staging, self.destination, self.manifest)
        with self.assertRaisesRegex(ValueError, 'Incomplete eight-screen set'):
            self.validate()

    def test_android_tablet_and_phone_sets_validate_independently(self):
        for category in runner.ANDROID_TYPES:
            manifest = dict(self.manifest, platform='android', screenshot_type=category)
            manifest['screenshots'] = [dict(entry, width=320, height=480) for entry in self.manifest['screenshots']]
            for entry in manifest['screenshots']:
                (self.staging / entry['file']).write_bytes(png(320, 480))
            runner.publish(self.staging, runner.image_directory('android', 'en-GB', category), manifest)
        with contextlib.redirect_stdout(io.StringIO()):
            runner.validate('android', 'en-GB')
        (runner.image_directory('android', 'en-GB', 'sevenInchScreenshots') / 'stale.png').write_bytes(png(320, 480))
        with self.assertRaisesRegex(ValueError, 'unreviewed PNGs'):
            runner.validate('android', 'en-GB')

    def test_alpha_removal_preserves_every_rgb_pixel_for_all_png_filters(self):
        image = self.staging / 'rgba.png'
        for filter_type in range(5):
            source, rows = rgba_png(filter_type)
            image.write_bytes(source)
            runner.opaque_rgb_png(image)
            result = image.read_bytes()
            self.assertEqual(result[25], 2)
            offset, compressed = 8, bytearray()
            while offset < len(result):
                length = struct.unpack('>I', result[offset:offset + 4])[0]
                if result[offset + 4:offset + 8] == b'IDAT':
                    compressed.extend(result[offset + 8:offset + 8 + length])
                offset += length + 12
            expected = b''.join(b'\0' + bytes(v for i, v in enumerate(row) if i % 4 != 3) for row in rows)
            self.assertEqual(zlib.decompress(compressed), expected)

    def test_transparent_capture_is_rejected_instead_of_changing_its_pixels(self):
        image = self.staging / 'transparent.png'
        source, _ = rgba_png(0, alpha=120)
        image.write_bytes(source)
        with self.assertRaisesRegex(ValueError, 'contains transparency'):
            runner.opaque_rgb_png(image)
        self.assertEqual(image.read_bytes(), source)


if __name__ == '__main__':
    unittest.main()
