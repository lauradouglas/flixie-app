import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('runtime_audit', Path(__file__).resolve().parents[1] / 'audit-runtime-baseline.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class RuntimeCaptureAuditTest(unittest.TestCase):
    def sample(self):
        return {'scenario': 'social', 'cache': 'cold', 'repetition': 1,
                'requests_total': {'GET /community/activity': 1},
                'response_statuses': {'GET /community/activity': {'200': 1}},
                'transport_errors': {}}

    def run_audit(self, sample, actual=None, paths=None):
        source = {'files': [{'path': 'lib/page.dart', 'sha256': 'frozen'}]}
        return module.audit({'samples': [sample]}, actual or source, source, paths)

    def test_clean_complete_accounting(self):
        result = self.run_audit(self.sample())
        self.assertTrue(result['transport_clean'])
        self.assertTrue(result['http_clean'])
        self.assertTrue(result['source_hashes_match'])
        self.assertEqual(result['tracked_requests'], 1)

    def test_missing_or_extra_response_is_not_clean(self):
        for responses in (0, 2):
            sample = self.sample()
            sample['response_statuses']['GET /community/activity']['200'] = responses
            self.assertFalse(self.run_audit(sample)['transport_clean'])

    def test_http_and_transport_errors_are_retained(self):
        sample = self.sample()
        sample['response_statuses']['GET /community/activity'] = {'503': 1}
        sample['transport_errors'] = {'GET /community/settings': ['SocketException']}
        result = self.run_audit(sample)
        self.assertFalse(result['http_clean'])
        self.assertFalse(result['transport_clean'])
        self.assertTrue(result['response_failures'])
        self.assertTrue(result['transport_errors'])

    def test_changed_source_is_not_verified(self):
        result = self.run_audit(self.sample(), {'files': [{'path': 'lib/page.dart', 'sha256': 'changed'}]})
        self.assertFalse(result['source_hashes_match'])

    def test_a_requested_missing_source_cannot_pass(self):
        self.assertFalse(self.run_audit(self.sample(), paths=['lib/missing.dart'])['source_hashes_match'])

if __name__ == '__main__':
    unittest.main()
