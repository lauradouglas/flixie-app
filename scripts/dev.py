#!/usr/bin/env python3
"""Start the isolated local stack; Flutter keeps the foreground terminal."""
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import time
from urllib.request import build_opener, ProxyHandler

APP = Path(__file__).resolve().parents[1]
BACKEND = APP.parent / 'FlixieBE'
LOGS = APP / '.local/firebase/logs'
HTTP = build_opener(ProxyHandler({}))


def listening(port):
    try:
        with socket.create_connection(('127.0.0.1', port), timeout=0.3):
            return True
    except OSError:
        return False


def get_json(path, port):
    try:
        with HTTP.open(f'http://127.0.0.1:{port}{path}', timeout=1) as response:
            return json.load(response)
    except (OSError, ValueError):
        return None


def emulators_ready():
    data = get_json('/emulators', 4400)
    return isinstance(data, dict) and all(
        data.get(name, {}).get('port') == port
        for name, port in [('auth', 9099), ('firestore', 8185), ('storage', 9199)])


def backend_ready():
    return get_json('/healthcheck/local', 3000) == {
        'mode': 'local', 'firebaseProjectId': 'demo-flixie-local'}


class Stack:
    def __init__(self):
        self.children = []

    def start(self, name, command, cwd):
        LOGS.mkdir(parents=True, exist_ok=True)
        log = LOGS / f'{name}.log'
        with log.open('w') as output:
            child = subprocess.Popen(command, cwd=cwd, stdout=output,
                                     stderr=subprocess.STDOUT, start_new_session=True)
        self.children.append((name, child))
        print(f'Starting {name} (log: {log})', flush=True)
        return child

    def wait(self, name, ready, seconds=90):
        deadline = time.monotonic() + seconds
        while not ready():
            self.check()
            if time.monotonic() > deadline:
                raise RuntimeError(f'{name} did not become ready; see {LOGS}')
            time.sleep(0.4)

    def check(self):
        for name, child in self.children:
            if child.poll() is not None:
                raise RuntimeError(f'{name} exited; see {LOGS / (name + ".log")}')

    def close(self):
        # Stop only services started here. Firebase gets SIGINT to export data.
        for _name, child in reversed(self.children):
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGINT)
                try:
                    child.wait(timeout=25)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGTERM)
                    try:
                        child.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(child.pid, signal.SIGKILL)
                        child.wait()


def serve_services(stack):
    print('FLIXIE_LOCAL_READY', flush=True)
    print('Local services are ready for VS Code. Terminate this task to stop owned services.', flush=True)
    while True:
        stack.check()
        time.sleep(0.5)


def main(args):
    if '--help' in args or '-h' in args:
        print('Usage: scripts/dev.sh [-d <device>] [flutter run options]\n'
              'Starts local Firebase, PostgreSQL container if needed, backend, seed and app.\n'
              'Android: FLIXIE_ANDROID_EMULATOR=true scripts/dev.sh -d <device>\n'
              'Ctrl-C/q stops Flutter and services started here; existing services stay running.\n'
              'VS Code uses --services-only to keep services running for its debugger.\n'
              'Start Docker Desktop first. Logs: .local/firebase/logs/')
        return 0
    services_only = '--services-only' in args
    args = [a for a in args if a != '--services-only']
    if services_only:
        print('FLIXIE_LOCAL_STARTING', flush=True)
        if args:
            raise RuntimeError('--services-only does not accept Flutter options.')
    if any(a in ('--release', '--profile') or a.startswith('--dart-define') for a in args):
        raise RuntimeError('This launcher is debug/local only; use release tooling for other builds.')
    for tool in ('python3', 'firebase', 'npm', 'flutter'):
        if not shutil.which(tool):
            raise RuntimeError(f'Missing {tool}; install the existing development prerequisites first.')
    if not (BACKEND / '.env.local').is_file():
        raise RuntimeError('Backend .env.local is missing; follow docs/firebase-local-development.md.')
    stack = Stack()
    app = None
    try:
        if not listening(5432):
            if not shutil.which('docker'):
                raise RuntimeError('Start the local PostgreSQL database/Docker Desktop first.')
            subprocess.run(['docker', 'start', os.environ.get('FLIXIE_POSTGRES_CONTAINER', 'postgresql')],
                           check=True, stdout=subprocess.DEVNULL)
            stack.wait('PostgreSQL', lambda: listening(5432), seconds=30)
        if not emulators_ready():
            if any(listening(p) for p in (4400, 9099, 8185, 9199)):
                raise RuntimeError('Firebase ports are occupied by an incomplete/different stack; stop it first.')
            stack.start('firebase', [str(APP / 'scripts/start-firebase-local.sh')], APP)
            stack.wait('Firebase', emulators_ready)
        else:
            print('Reusing running local Firebase emulators.', flush=True)
        seed = stack.start('seed', ['npm', 'run', 'seed:firebase:local'], BACKEND)
        try:
            code = seed.wait(timeout=90)
        except subprocess.TimeoutExpired:
            raise RuntimeError(f'Local seed timed out; see {LOGS / "seed.log"}')
        # Successful one-shot seed is not a long-running stack dependency.
        stack.children.remove(('seed', seed))
        if code:
            raise RuntimeError(f'Local seed failed; see {LOGS / "seed.log"}')
        if not backend_ready():
            if listening(3000):
                raise RuntimeError('Port 3000 is occupied by an API without the local-stack marker; stop it first.')
            stack.start('backend', ['npm', 'run', 'dev'], BACKEND)
            stack.wait('Backend', backend_ready)
        else:
            print('Reusing running local backend.', flush=True)
        if services_only:
            serve_services(stack)
            return 0
        print('Local stack ready. Starting Flutter; q or Ctrl-C stops this session.', flush=True)
        app = subprocess.Popen([str(APP / 'scripts/run-local.sh'), *args], cwd=APP)
        while app.poll() is None:
            stack.check()
            time.sleep(0.5)
        return app.returncode
    finally:
        if app is not None and app.poll() is None:
            app.send_signal(signal.SIGINT)
            try:
                app.wait(timeout=10)
            except subprocess.TimeoutExpired:
                app.terminate()
                app.wait(timeout=5)
        stack.close()


if __name__ == '__main__':
    def terminate(_signal, _frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, terminate)
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        print('\nLocal session stopped.')
        sys.exit(130)
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(f'Local startup failed: {error}', file=sys.stderr)
        sys.exit(1)
