import importlib.util
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
spec = importlib.util.spec_from_file_location('capture', Path(__file__).resolve().parents[1] / 'capture-lifecycle-baseline.py')
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)

class TransportAuditTest(unittest.TestCase):
    def sample(self, **changes):
        return dict(scenario='email_login', library_size=20, repetition=1,
                    requests={'GET /fixture': 1},
                    response_statuses={'GET /fixture': {'200': 1}},
                    transport_errors={}, **changes)

    def test_complete_success_is_clean(self):
        self.assertTrue(capture.transport_audit([self.sample()])['clean'])

    def test_missing_response_rejects_otherwise_successful_capture(self):
        sample = self.sample()
        sample['requests']['GET /optional'] = 1
        audit = capture.transport_audit([sample])
        self.assertFalse(audit['clean'])
        self.assertEqual(audit['request_response_gaps'][0]['requests_without_recorded_response'], {'GET /optional': 1})

    def test_http_error_is_not_clean(self):
        sample = self.sample()
        sample['response_statuses'] = {'GET /fixture': {'503': 1}}
        self.assertFalse(capture.transport_audit([sample])['clean'])

    def test_transport_error_rejects_even_with_matching_counts(self):
        sample = self.sample()
        sample['transport_errors'] = {'GET /fixture': ['connection reset']}
        self.assertFalse(capture.transport_audit([sample])['clean'])

    def test_extra_response_is_also_rejected(self):
        sample = self.sample()
        sample['response_statuses']['GET /fixture']['200'] = 2
        self.assertFalse(capture.transport_audit([sample])['clean'])

class MemoryAuditTest(unittest.TestCase):
    def rows(self):
        return [dict(phase=phase, library_size=size, repetition=repetition,
                     dateLastServiceGC=index + 1)
                for index, (phase, size, repetition) in enumerate(
                    (p, s, r) for r in range(1, 6) for s in [20, 400]
                    for p in ['signed_in', 'logged_out', 'switched', 'unmounted'])]

    def test_all_conditions_with_advancing_gc_are_valid(self):
        self.assertTrue(capture.memory_audit(self.rows()))

    def test_missing_condition_is_rejected(self):
        self.assertFalse(capture.memory_audit(self.rows()[:-1]))

    def test_stale_gc_is_rejected(self):
        rows = self.rows()
        rows[1]['dateLastServiceGC'] = rows[0]['dateLastServiceGC']
        self.assertFalse(capture.memory_audit(rows))

class RetainingAuditTest(unittest.TestCase):
    def rows(self):
        rows = [dict(phase=phase, library_size=size, repetition=repetition,
                     dateLastServiceGC=index + 1, owned_classes=[], retaining_paths=[], instance_lookup_count=0)
                for index, (phase, size, repetition) in enumerate(
                    (p, s, r) for r in range(1, 6) for s in [20, 400]
                    for p in ['signed_in', 'logged_out', 'switched', 'unmounted', 'post_cycle', 'post_input_replacement'])]
        return rows

    def test_no_remaining_instances_needs_no_path(self):
        self.assertTrue(capture.retaining_audit(self.rows()))

    def test_retained_instance_needs_complete_path(self):
        rows = self.rows()
        row = next(r for r in rows if r['phase'] == 'unmounted')
        row['owned_classes'] = [dict(name='_LifecycleAuth', instancesCurrent=1)]
        row['instance_lookup_count'] = 1
        self.assertFalse(capture.retaining_audit(rows))
        row['retaining_paths'] = [dict(type='RetainingPath', length=1,
                                      gcRootType='stack', elements=[dict(kind='PlainInstance')])]
        self.assertTrue(capture.retaining_audit(rows))

    def test_missing_post_cycle_control_is_rejected(self):
        rows = [row for row in self.rows() if row['phase'] != 'post_input_replacement']
        self.assertFalse(capture.retaining_audit(rows))

    def test_stale_gc_in_control_is_rejected(self):
        rows = self.rows()
        rows[-1]['dateLastServiceGC'] = rows[-2]['dateLastServiceGC']
        self.assertFalse(capture.retaining_audit(rows))

    def test_truncated_path_is_not_complete_evidence(self):
        rows = self.rows()
        row = next(r for r in rows if r['phase'] == 'unmounted')
        row['owned_classes'] = [dict(name='_LifecycleAuth', instancesCurrent=1)]
        row['instance_lookup_count'] = 1
        row['retaining_paths'] = [dict(type='RetainingPath', length=2,
                                      gcRootType='stack', elements=[{}])]
        self.assertFalse(capture.retaining_audit(rows))

if __name__ == '__main__':
    unittest.main()
