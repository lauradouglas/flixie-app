import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch, Mock

spec = importlib.util.spec_from_file_location('dev', Path(__file__).with_name('dev.py'))
dev = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dev)


class LauncherTest(unittest.TestCase):
    def test_readiness_requires_expected_local_services(self):
        with patch.object(dev, 'get_json', return_value={'mode':'production'}):
            self.assertFalse(dev.backend_ready())
        with patch.object(dev, 'get_json', return_value={'mode':'local','firebaseProjectId':'demo-flixie-local'}):
            self.assertTrue(dev.backend_ready())
        with patch.object(dev, 'get_json', return_value={'auth':{'port':9099}}):
            self.assertFalse(dev.emulators_ready())

    def test_release_overrides_rejected_before_startup(self):
        for flag in ['--release','--profile','--dart-define=USE_FIREBASE_EMULATORS=false']:
            with self.assertRaisesRegex(RuntimeError, 'debug/local'):
                dev.main([flag])

    def test_ready_services_reused_and_flutter_gets_device(self):
        seed = Mock()
        seed.wait.return_value = 0
        app = Mock(returncode=0)
        app.poll.return_value = 0
        starts = []
        def start(stack, name, command, cwd):
            starts.append(name)
            stack.children.append((name,seed))
            return seed
        with patch.object(dev.shutil,'which',return_value='/tool'), \
             patch.object(dev.Path,'is_file',return_value=True), \
             patch.object(dev,'listening',return_value=True), \
             patch.object(dev,'emulators_ready',return_value=True), \
             patch.object(dev,'backend_ready',return_value=True), \
             patch.object(dev.Stack,'start',start), \
             patch.object(dev.subprocess,'Popen',return_value=app) as popen:
            self.assertEqual(dev.main(['-d','simulator']),0)
            self.assertEqual(starts,['seed'])
            self.assertEqual(popen.call_args.args[0][-2:],['-d','simulator'])

    def test_stopped_services_start_in_order_before_flutter(self):
        events = []
        seed = Mock()
        seed.wait.return_value = 0
        app = Mock(returncode=0)
        app.poll.return_value = 0
        def start(stack, name, command, cwd):
            events.append(name)
            if name == 'seed':
                stack.children.append((name,seed))
            return seed
        def wait(stack, name, ready, seconds=90):
            events.append('ready:' + name)
        with patch.object(dev.shutil,'which',return_value='/tool'), \
             patch.object(dev.Path,'is_file',return_value=True), \
             patch.object(dev,'listening',side_effect=lambda p: p == 5432), \
             patch.object(dev,'emulators_ready',return_value=False), \
             patch.object(dev,'backend_ready',return_value=False), \
             patch.object(dev.Stack,'start',start), \
             patch.object(dev.Stack,'wait',wait), \
             patch.object(dev.subprocess,'Popen',side_effect=lambda *a,**kw: events.append('flutter') or app):
            self.assertEqual(dev.main([]),0)
            self.assertEqual(events,['firebase','ready:Firebase','seed','backend','ready:Backend','flutter'])

    def test_vscode_services_mode_waits_without_starting_flutter(self):
        seed = Mock()
        seed.wait.return_value = 0
        def start(stack, name, command, cwd):
            stack.children.append((name, seed))
            return seed
        with patch.object(dev.shutil,'which',return_value='/tool'), \
             patch.object(dev.Path,'is_file',return_value=True), \
             patch.object(dev,'listening',return_value=True), \
             patch.object(dev,'emulators_ready',return_value=True), \
             patch.object(dev,'backend_ready',return_value=True), \
             patch.object(dev.Stack,'start',start), \
             patch.object(dev,'serve_services') as serve, \
             patch.object(dev.subprocess,'Popen') as popen:
            self.assertEqual(dev.main(['--services-only']),0)
            serve.assert_called_once()
            popen.assert_not_called()

    def test_vscode_local_configs_wait_for_service_readiness(self):
        root = Path(__file__).resolve().parents[1]
        launches = dev.json.loads((root / '.vscode/launch.json').read_text())['configurations']
        tasks = dev.json.loads((root / '.vscode/tasks.json').read_text())['tasks']
        task = next(t for t in tasks if t['label'] == 'Flixie: start local services')
        self.assertEqual(task['args'], ['--services-only'])
        self.assertTrue(task['isBackground'])
        self.assertEqual(task['problemMatcher']['background']['endsPattern'], '^FLIXIE_LOCAL_READY$')
        for launch in launches:
            if '.firebase.local.json' in launch.get('toolArgs', []):
                self.assertEqual(launch['preLaunchTask'], task['label'])
            else:
                self.assertNotIn('preLaunchTask', launch)

    def test_cleanup_interrupts_only_owned_services(self):
        stack = dev.Stack()
        child = Mock(pid=123)
        child.poll.return_value = None
        stack.children = [('firebase',child)]
        with patch.object(dev.os,'killpg') as kill:
            stack.close()
            kill.assert_called_once_with(123,dev.signal.SIGINT)
            child.wait.assert_called_once_with(timeout=25)


if __name__ == '__main__':
    unittest.main()
