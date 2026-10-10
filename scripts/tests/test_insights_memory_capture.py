import copy
import gzip
import hashlib
import json
import importlib.util
from pathlib import Path
import sys
import re
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
spec = importlib.util.spec_from_file_location('insights_memory_capture', Path(__file__).resolve().parents[1] / 'capture-insights-memory.py')
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


def fixture():
    samples, rows = [], []
    tick = 1000
    for repetition in range(1, 6):
        for condition in capture.CONDITIONS:
            for version in capture.VERSIONS:
                budget = {'GET /groups/runtime-plan-group-0/insights': 5}
                samples.append({'version': version, 'condition': condition, 'repetition': repetition,
                    'periods': ['month', 'all', 'month', 'month', 'month'], 'requests': budget, 'responses': {k: {'200': v} for k, v in budget.items()}, 'transport_errors': {}})
                for phase in capture.PHASES:
                    tick += 1
                    images = condition == 'controlled_images' and phase not in ('baseline', 'cache_cleared')
                    rows.append({'version': version, 'condition': condition, 'repetition': repetition, 'phase': phase,
                        'date_last_gc': tick, 'image_cache_bytes': 1024 if images else 0,
                        'image_cache_live': 2 if images and phase == 'mounted' else 0,
                        'image_cache_pending': 0, 'rss_after_gc_bytes': 10000000,
                        'memory_usage': {'heapUsage': 2000000 if phase == 'mounted' else 1000000, 'externalUsage': 1000},
                        'owners': [], 'retaining_paths': [], 'actual_live_counts': {name: (1 if phase == 'mounted' and (name == ('_MemoryBeforeGroupInsightsTabState' if version == 'before' else '_GroupInsightsTabState') or (version == 'after' and name == 'GroupInsightsController')) else 0) for name in capture.OWNERS}})
    return {'complete': True, 'samples': samples, 'memory_samples': rows}


class InsightsMemoryAuditTest(unittest.TestCase):
    def test_before_reference_changes_class_names_only(self):
        root = Path(__file__).resolve().parents[2]
        archived = gzip.decompress((root / 'docs/performance/2026-10-09-group-insights-validation/insights_tab.before.dart.gz').read_bytes())
        sha = hashlib.sha256(archived).hexdigest()
        hashes = json.loads((root / 'docs/performance/2026-10-09-group-insights-before-3/harness-source.json').read_text())
        expected = next(value for name, value in hashes.items() if name.endswith('/widgets/insights_tab.dart'))
        self.assertEqual(sha, expected)
        source = archived.decode()
        names = re.findall(r'class\s+([A-Za-z_][A-Za-z_0-9]*)', source)
        for name in sorted(names, key=len, reverse=True):
            replacement = 'BeforeGroupInsightsTab' if name == 'GroupInsightsTab' else '_MemoryBefore' + name.lstrip('_')
            source = re.sub(r'\b' + re.escape(name) + r'\b', replacement, source)
        reference = '// Frozen test-only pre-cleanup reference. Original SHA-256: ' + sha + '\n' + source
        self.assertEqual((root / 'patrol_test/support/group_insights_memory_before.dart').read_text(), reference)

    def test_accepts_complete_matched_visits_and_gc_phases(self):
        result = capture.audit(fixture())
        self.assertTrue(result['complete'])
        self.assertEqual((result['visits'], result['gc_observations'], result['tracked_requests']), (20, 100, 100))

    def test_rejects_wrong_period_order(self):
        data = fixture()
        data['samples'][0]['periods'][1] = 'month'
        self.assertFalse(capture.audit(data)['complete'])

    def test_rejects_transport_error_even_with_http_success(self):
        data = fixture()
        data['samples'][0]['transport_errors'] = {'GET /groups/user/runtime-fixture-0': ['failed']}
        self.assertFalse(capture.audit(data)['complete'])

    def test_rejects_unaccounted_or_failed_response(self):
        for status in ('500', 'missing'):
            data = fixture()
            data['samples'][0]['responses'] = {} if status == 'missing' else {'GET /groups/user/runtime-fixture-0': {status: 1}}
            self.assertFalse(capture.audit(data)['complete'])

    def test_rejects_missing_or_duplicate_phase(self):
        data = fixture()
        data['memory_samples'][1] = copy.deepcopy(data['memory_samples'][0])
        self.assertFalse(capture.audit(data)['complete'])

    def test_rejects_reused_gc_timestamp(self):
        data = fixture()
        data['memory_samples'][1]['date_last_gc'] = data['memory_samples'][0]['date_last_gc']
        self.assertFalse(capture.audit(data)['complete'])

    def test_rejects_image_control_contamination(self):
        data = fixture()
        data['memory_samples'][0]['image_cache_bytes'] = 100
        self.assertFalse(capture.audit(data)['complete'])

    def test_rejects_missing_controlled_images_or_pending_decode(self):
        for field, value in [('image_cache_bytes', 0), ('image_cache_pending', 1)]:
            data = fixture()
            row = next(r for r in data['memory_samples'] if r['condition'] == 'controlled_images' and r['phase'] == 'mounted')
            row[field] = value
            self.assertFalse(capture.audit(data)['complete'])

    def test_rejects_missing_direct_counts_and_wrong_mounted_owner(self):
        for mode in ('missing', 'wrong_owner'):
            data = fixture()
            row = next(r for r in data['memory_samples'] if r['phase'] == 'mounted')
            row['actual_live_counts'] = {} if mode == 'missing' else {name: 0 for name in capture.OWNERS}
            self.assertFalse(capture.audit(data)['complete'])

    def test_summary_uses_each_visit_baseline_for_heap_delta(self):
        rows = capture.summarise(fixture())
        mounted = [r for r in rows if r['phase'] == 'mounted']
        self.assertEqual(len(mounted), 4)
        self.assertTrue(all(r['heap_delta_from_baseline_median_mib'] == round(1000000 / 1048576, 4) for r in mounted))


if __name__ == '__main__':
    unittest.main()
