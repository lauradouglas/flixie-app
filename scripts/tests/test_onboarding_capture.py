import copy
import importlib.util
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
spec = importlib.util.spec_from_file_location('onboarding_capture', ROOT / 'scripts/capture-onboarding-baseline.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class OnboardingAuditTest(unittest.TestCase):
    def setUp(self):
        self.data = json.loads((ROOT / 'docs/performance/2026-10-09-onboarding-before-4/runtime.json').read_text())

    def test_accepts_both_real_captures(self):
        self.assertTrue(module.validate_capture(self.data)['complete'])
        after = json.loads((ROOT / 'docs/performance/2026-10-09-onboarding-after/runtime.json').read_text())
        self.assertTrue(module.validate_capture(after)['complete'])

    def test_rejects_wrong_database(self):
        self.data['method']['manifest']['database'] = 'not-the-fixture'
        with self.assertRaises(ValueError): module.validate_capture(self.data)

    def test_rejects_incomplete(self):
        self.data['complete'] = False
        with self.assertRaises(ValueError): module.validate_capture(self.data)

    def test_rejects_duplicate_visit(self):
        self.data['samples'][1] = copy.deepcopy(self.data['samples'][0])
        with self.assertRaises(ValueError): module.validate_capture(self.data)

    def test_rejects_extra_request(self):
        self.data['samples'][0]['requests']['GET /search'] = 5
        with self.assertRaises(ValueError): module.validate_capture(self.data)

    def test_rejects_failed_response(self):
        self.data['samples'][0]['responses']['GET /search'] = {'200': 3, '500': 1}
        with self.assertRaises(ValueError): module.validate_capture(self.data)

    def test_rejects_missing_save(self):
        self.data['samples'][0]['watchlist_adds'] = 0
        with self.assertRaises(ValueError): module.validate_capture(self.data)

    def test_rejects_missing_frames(self):
        self.data['samples'][0]['frame_raster_us'] = []
        with self.assertRaises(ValueError): module.validate_capture(self.data)


if __name__ == '__main__':
    unittest.main()
