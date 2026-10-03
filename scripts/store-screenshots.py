#!/usr/bin/env python3
"""Capture real simulator/emulator PNGs through a test-to-host handshake."""
import argparse
import fcntl
import http.server
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import struct
import subprocess
import tempfile
import threading
import time
import zlib

ROOT = Path(__file__).resolve().parents[1]
ANDROID_TYPES = ('phoneScreenshots', 'sevenInchScreenshots', 'tenInchScreenshots')

def image_directory(platform, locale, screenshot_type='phoneScreenshots'):
    if screenshot_type not in ANDROID_TYPES:
        raise ValueError('Unknown Android screenshot type')
    return (ROOT / 'fastlane/screenshots' / locale if platform == 'ios'
            else ROOT / 'fastlane/metadata/android' / locale / 'images' / screenshot_type)

def manifest_directory(platform, screenshot_type='phoneScreenshots'):
    base = ROOT / 'fastlane/screenshot-manifests' / platform
    return base if screenshot_type == 'phoneScreenshots' else base / screenshot_type

SCENES = ('01-home', '02-profile', '03-watchlist', '04-watch-plan',
          '05-community', '06-interstellar', '07-the-newsroom', '08-rating')


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, capture_output=True,
                          timeout=kwargs.pop('timeout', 120), **kwargs).stdout.strip()


def cleanup(*args):
    try:
        run(*args, timeout=15)
    except (subprocess.SubprocessError, OSError) as error:
        print(f'Could not restore screenshot device: {error}', flush=True)


def png_size(path):
    header = path.read_bytes()[:24]
    if len(header) != 24 or header[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f'Invalid screenshot PNG: {path}')
    return struct.unpack('>II', header[16:24])


def opaque_rgb_png(path):
    """Losslessly remove the native capture's fully opaque alpha channel."""
    data = path.read_bytes()
    width, height = png_size(path)
    if data[24:29] == bytes([8, 2, 0, 0, 0]):
        return
    if data[24:29] != bytes([8, 6, 0, 0, 0]):
        raise ValueError('Expected an 8-bit non-interlaced RGB/RGBA native PNG')
    chunks = []
    offset = 8
    while offset < len(data):
        length = struct.unpack('>I', data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        chunks.append((kind, payload))
        offset += length + 12
    raw = zlib.decompress(b''.join(p for k, p in chunks if k == b'IDAT'))
    stride = width * 4
    if len(raw) != (stride + 1) * height:
        raise ValueError('Invalid native PNG scanline length')
    previous = bytearray(stride)
    output = bytearray()
    for y in range(height):
        start = y * (stride + 1)
        filter_type = raw[start]
        row = bytearray(raw[start + 1:start + 1 + stride])
        if filter_type == 1:
            for i in range(4, stride):
                row[i] = (row[i] + row[i - 4]) & 255
        elif filter_type == 2:
            row = bytearray((a + b) & 255 for a, b in zip(row, previous))
        elif filter_type in (3, 4):
            for i in range(stride):
                left = row[i - 4] if i >= 4 else 0
                above = previous[i]
                upper_left = previous[i - 4] if i >= 4 else 0
                if filter_type == 3:
                    predictor = (left + above) // 2
                else:
                    p = left + above - upper_left
                    a, b, c = abs(p - left), abs(p - above), abs(p - upper_left)
                    predictor = left if a <= b and a <= c else above if b <= c else upper_left
                row[i] = (row[i] + predictor) & 255
        elif filter_type != 0:
            raise ValueError(f'Unknown PNG filter: {filter_type}')
        if any(alpha != 255 for alpha in row[3::4]):
            raise ValueError('Native screenshot contains transparency; refusing to change its pixels')
        rgb = bytearray(width * 3)
        rgb[0::3], rgb[1::3], rgb[2::3] = row[0::4], row[1::4], row[2::4]
        output.append(0)
        output.extend(rgb)
        previous = row

    def chunk(kind, payload):
        return (struct.pack('>I', len(payload)) + kind + payload
                + struct.pack('>I', zlib.crc32(kind + payload)))
    header = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    # Retain the native colour profile to preserve how the pixels are displayed.
    profile = b''.join(chunk(k, p) for k, p in chunks if k in (b'iCCP', b'sRGB', b'gAMA', b'cHRM'))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + profile
                     + chunk(b'IDAT', zlib.compress(output)) + chunk(b'IEND', b''))


def ios_device(spec, explicit=None):
    devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '-j'))['devices']
    available = [device for group in devices.values() for device in group]
    if explicit:
        matches = [d for d in available if d['udid'] == explicit]
    else:
        matches = [d for d in devices.get(spec['runtime'], []) if d['name'] == spec['name']]
        if not matches:
            uid = run('xcrun', 'simctl', 'create', spec['name'],
                      spec['device_type'], spec['runtime'])
            matches = [{'udid': uid, 'name': spec['name'], 'state': 'Shutdown'}]
    if len(matches) != 1:
        raise ValueError('Select one available dedicated iOS simulator')
    device = matches[0]
    if not device['name'].startswith(('Flixie Screenshots', 'Flixie Patrol')):
        raise ValueError('Use a dedicated simulator named Flixie Screenshots… or Flixie Patrol')
    if device['state'] != 'Booted':
        run('xcrun', 'simctl', 'boot', device['udid'])
    run('xcrun', 'simctl', 'bootstatus', device['udid'], '-b', timeout=180)
    run('xcrun', 'simctl', 'status_bar', device['udid'], 'override',
        '--time', '9:41', '--dataNetwork', 'wifi', '--wifiMode', 'active',
        '--wifiBars', '3', '--batteryState', 'charged', '--batteryLevel', '100')
    return device['udid'], device.get('deviceTypeIdentifier', spec['device_type']).split('.')[-1]


def android_device(spec, explicit=None):
    adb = shutil.which('adb')
    if not adb:
        raise ValueError('Install Android SDK platform-tools and put adb on PATH')
    devices = [line.split()[0] for line in run(adb, 'devices').splitlines()[1:]
               if line.endswith('\tdevice')]
    matches = []
    for serial in devices:
        if not serial.startswith('emulator-'):
            continue
        avd = run(adb, '-s', serial, 'emu', 'avd', 'name').splitlines()[0]
        if (explicit and serial == explicit) or (not explicit and avd == spec['avd']):
            if not avd.startswith(('Flixie_Screenshots', 'Flixie_Patrol')):
                raise ValueError('Use a dedicated AVD named Flixie_Screenshots… or Flixie_Patrol…')
            matches.append((serial, avd))
    if len(matches) != 1:
        raise ValueError(f'Boot the dedicated Android AVD {spec["avd"]} in Android Studio, then retry')
    return matches[0]


def reject_android_system_dialog(window_state):
    # WindowManager reports native dialogs that Flutter's widget tree cannot see.
    focused = [line for line in window_state.splitlines()
               if 'mCurrentFocus=' in line or 'mFocusedWindow=' in line]
    if any(re.search(r'Application (?:Not Responding|Error)', line, re.I)
           for line in focused):
        raise ValueError('Android system error dialog is covering the app; restart the emulator and recapture')


def capture(platform, device, path):
    if platform == 'ios':
        run('xcrun', 'simctl', 'io', device, 'screenshot', '--type=png', str(path))
    else:
        reject_android_system_dialog(run('adb', '-s', device, 'shell', 'dumpsys', 'window'))
        with path.open('wb') as output:
            subprocess.run(['adb', '-s', device, 'exec-out', 'screencap', '-p'],
                           stdout=output, check=True, timeout=30)
        reject_android_system_dialog(run('adb', '-s', device, 'shell', 'dumpsys', 'window'))
    width, height = png_size(path)
    if width <= 0 or height <= width:
        raise ValueError('Expected a portrait device screenshot')
    if platform == 'android' and not (320 <= width < height <= 3840 and height <= 2 * width):
        raise ValueError('Android screenshots must be 320–3840px with a maximum 2:1 aspect ratio')
    opaque_rgb_png(path)
    return width, height


def capture_set(platform, device, label, locale, staging, scenes=SCENES):
    token = secrets.token_urlsafe(32)
    captured = []
    failures = []

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            name = self.path.removeprefix('/capture/')
            if (self.headers.get('X-Flixie-Capture-Token') != token
                    or not self.path.startswith('/capture/') or name not in scenes):
                self.send_error(403)
                return
            try:
                if name != scenes[len(captured)]:
                    raise ValueError(f'Unexpected capture order: {name}')
                path = staging / f'{label}-{name}.png'
                width, height = capture(platform, device, path)
                captured.append({'scene': name, 'file': path.name,
                                 'width': width, 'height': height})
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'Captured')
                print(f'Saved {path.name} ({width} x {height})', flush=True)
            except Exception as error:
                failures.append(str(error))
                self.send_error(500, str(error))

        def log_message(self, *_):
            pass

    server = http.server.HTTPServer(('127.0.0.1', 0), Handler)
    port = server.server_port
    threading.Thread(target=server.serve_forever, daemon=True).start()
    command = [str(ROOT / 'scripts/test-patrol.sh'), '-d', device,
               '-t', 'patrol_test/store_screenshots_test.dart',
               '--no-label',
               f'--dart-define=SCREENSHOT_HOST=http://127.0.0.1:{port}',
               f'--dart-define=SCREENSHOT_TOKEN={token}',
               f'--dart-define=SCREENSHOT_SCENES={"|".join(scenes)}']
    try:
        if platform == 'android':
            run('adb', '-s', device, 'reverse', f'tcp:{port}', f'tcp:{port}')
        # Run output goes to a local log (the Dart defines include a transient
        # handshake token). Print its tail only when capture fails.
        log_path = staging / 'patrol.log'
        with log_path.open('w') as log:
            process = subprocess.Popen(command, cwd=ROOT, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            try:
                deadline = time.monotonic() + 1800
                while process.poll() is None:
                    if time.monotonic() > deadline:
                        raise TimeoutError('Screenshot build/test exceeded 30 minutes')
                    if any(marker in log_path.read_text() for marker in (
                            'EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK',
                            'Gradle test execution failed with code',
                            'Failed to execute tests')):
                        failures.append('The native screenshot test failed')
                        import signal
                        os.killpg(process.pid, signal.SIGTERM)
                        process.wait(timeout=30)
                        break
                    time.sleep(1)
            except BaseException:
                import signal
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    process.wait(timeout=30)
                raise
        if process.returncode or failures or len(captured) != len(scenes):
            safe_log = log_path.read_text().replace(token, '<capture-token>')
            log_dir = ROOT / 'build/store-screenshots'
            log_dir.mkdir(parents=True, exist_ok=True)
            saved_log = log_dir / f'{platform}-{label}.log'
            saved_log.write_text(safe_log)
            raise RuntimeError(f'Capture failed ({process.returncode}): {failures}\n{safe_log[-10000:]}\nFull log: {saved_log}')
        return {'platform': platform, 'device': label, 'locale': locale,
                'screenshots': captured}
    finally:
        server.shutdown()
        server.server_close()
        if platform == 'android':
            cleanup('adb', '-s', device, 'reverse', '--remove', f'tcp:{port}')


def publish(staging, destination, manifest):
    destination.mkdir(parents=True, exist_ok=True)
    label = manifest['device']
    # Replace only this device's complete set, after all eight captures pass.
    for old in destination.glob(f'{label}-*.png'):
        old.unlink()
    for entry in manifest['screenshots']:
        shutil.copy2(staging / entry['file'], destination / entry['file'])
    manifest_dir = manifest_directory(manifest['platform'], manifest.get('screenshot_type', 'phoneScreenshots'))
    manifest_dir.mkdir(parents=True, exist_ok=True)
    (manifest_dir / f'{label}.json').write_text(json.dumps(manifest, indent=2) + '\n')


def publish_selected(staging, destination, manifest):
    # Require a valid existing set before replacing only requested images.
    validate(manifest['platform'], manifest['locale'])
    manifest_path = manifest_directory(manifest['platform'], manifest.get('screenshot_type', 'phoneScreenshots')) / f"{manifest['device']}.json"
    existing = json.loads(manifest_path.read_text())
    replacements = {entry['scene']: entry for entry in manifest['screenshots']}
    for entry in manifest['screenshots']:
        shutil.copy2(staging / entry['file'], destination / entry['file'])
    existing['screenshots'] = [replacements.get(entry['scene'], entry)
                               for entry in existing['screenshots']]
    manifest_path.write_text(json.dumps(existing, indent=2) + '\n')


def validate(platform, locale):
    manifests = list((ROOT / 'fastlane/screenshot-manifests' / platform).rglob('*.json'))
    if not manifests:
        raise ValueError(f'Capture screenshots first: bundle exec fastlane {platform} screenshots')
    expected_by_type = {}
    for path in manifests:
        manifest = json.loads(path.read_text())
        screenshot_type = manifest.get('screenshot_type', 'phoneScreenshots')
        destination = image_directory(platform, locale, screenshot_type)
        expected_files = expected_by_type.setdefault(screenshot_type, set())
        if manifest.get('review_failure'):
            raise ValueError(f'Screenshot visual review failed: {manifest["review_failure"]}; recapture before uploading')
        if manifest['locale'] != locale or manifest['platform'] != platform:
            raise ValueError(f'Unexpected manifest locale or platform: {path}')
        if [entry['scene'] for entry in manifest['screenshots']] != list(SCENES):
            raise ValueError(f'Incomplete eight-screen set: {path}')
        for entry in manifest['screenshots']:
            name = entry['file']
            if Path(name).name != name or not name.endswith('.png'):
                raise ValueError(f'Invalid screenshot filename in {path}')
            size = png_size(destination / name)
            if list(size) != [entry['width'], entry['height']]:
                raise ValueError(f'Screenshot dimensions changed: {name}')
            if (destination / name).read_bytes()[24:29] != bytes([8, 2, 0, 0, 0]):
                raise ValueError(f'Screenshot must be 24-bit RGB without alpha: {name}')
            if platform == 'android' and not (320 <= size[0] < size[1] <= 3840 and size[1] <= 2 * size[0]):
                raise ValueError(f'Android screenshot dimensions are not Play-compatible: {name}')
            expected_files.add(name)
    for screenshot_type, expected_files in expected_by_type.items():
        destination = image_directory(platform, locale, screenshot_type)
        actual_files = {p.name for p in destination.glob('*.png')}
        if actual_files != expected_files:
            raise ValueError('Screenshot folder contains missing or unreviewed PNGs; recapture or remove stale sets')
        if platform == 'android' and len(actual_files) > 8:
            raise ValueError(f'Google Play {screenshot_type} supports at most eight screenshots; keep one device set')
        print(f'Validated {len(actual_files)} {platform} screenshots in {destination}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=('ios', 'android'))
    parser.add_argument('--android-type', choices=ANDROID_TYPES, default='phoneScreenshots')
    parser.add_argument('--device', help='Dedicated simulator UDID or emulator serial')
    parser.add_argument('--config', type=Path, default=ROOT / 'fastlane/ScreenshotConfig.json')
    parser.add_argument('--validate', action='store_true', help='Check the complete set without a device or upload')
    parser.add_argument('--scenes', nargs='+', choices=SCENES, help='Replace only selected scenes in an existing complete set')
    args = parser.parse_args()
    scenes = tuple(scene for scene in SCENES if not args.scenes or scene in args.scenes)
    config = json.loads(args.config.read_text())
    locale = config['locale']
    if locale != 'en-GB':
        raise ValueError('The initial fixture copy is English; locale must be en-GB')
    if args.validate:
        validate(args.platform, locale)
        return
    if args.scenes:
        validate(args.platform, locale)
    lock_dir = ROOT / 'build/store-screenshots'
    lock_dir.mkdir(parents=True, exist_ok=True)
    with (lock_dir / 'capture.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print('Waiting for the other screenshot run to finish…', flush=True)
            fcntl.flock(lock, fcntl.LOCK_EX)
        specs = config['ios'] if args.platform == 'ios' else [config['android'] if args.android_type == 'phoneScreenshots' else config['android_tablets'][args.android_type]]
        if args.device:
            specs = specs[:1]
        for spec in specs:
            prepare = ios_device if args.platform == 'ios' else android_device
            device, label = prepare(spec, args.device)
            if not re.fullmatch(r'[A-Za-z0-9_-]+', label):
                raise ValueError('Device label must contain only letters, numbers, underscores or hyphens')
            destination = image_directory(args.platform, locale, args.android_type)
            print(f'Capturing {len(scenes)} screens on {label}; first build can take several minutes.', flush=True)
            display = None
            density = None
            try:
                if args.platform == 'android':
                    previous = run('adb', '-s', device, 'shell', 'wm', 'size')
                    display = re.search(r'Override size: (\d+x\d+)', previous)
                    display = display.group(1) if display else 'reset'
                    previous_density = run('adb', '-s', device, 'shell', 'wm', 'density')
                    density = re.search(r'Override density: (\d+)', previous_density)
                    density = density.group(1) if density else 'reset'
                    run('adb', '-s', device, 'shell', 'wm', 'size', spec.get('size', '1080x1920'))
                    run('adb', '-s', device, 'shell', 'wm', 'density', str(spec.get('density', 420)))
                with tempfile.TemporaryDirectory(prefix='flixie-screenshots-') as temporary:
                    staging = Path(temporary)
                    manifest = capture_set(args.platform, device, label, locale, staging, scenes)
                    manifest['screenshot_type'] = args.android_type
                    (publish_selected if args.scenes else publish)(staging, destination, manifest)
            finally:
                if args.platform == 'ios':
                    cleanup('xcrun', 'simctl', 'status_bar', device, 'clear')
                elif display is not None:
                    cleanup('adb', '-s', device, 'shell', 'wm', 'size', display)
                    if density is not None:
                        cleanup('adb', '-s', device, 'shell', 'wm', 'density', density)
            print(f'Screenshot set ready: {destination}', flush=True)


if __name__ == '__main__':
    main()
