import copy
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('insights_audit', Path(__file__).resolve().parents[1] / 'audit-insights-baseline.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)

def fixture():
    stages = {'all_time': ['all'], 'same_period': [], 'month': ['month'], 'refresh': ['month'], 'refresh_burst': ['month']}
    samples = []
    for cache in ('cold', 'warm'):
        for repetition in range(1, 6):
            total = 5
            samples.append({'scenario': 'group_insights', 'cache': cache, 'repetition': repetition,
                'requests_load': {audit.KEY: 1}, 'requests_total': {audit.KEY: total},
                'response_statuses': {audit.KEY: {'200': total}}, 'transport_errors': {},
                'insights_queries': [audit.PATH + '?timeWindow=' + p for p in ['month'] + [p for ps in stages.values() for p in ps]],
                'insights_stages': {name: {'requests': {audit.KEY: len(ps)} if ps else {}, 'queries': [audit.PATH + '?timeWindow=' + p for p in ps], 'settled_us': 1} for name, ps in stages.items()}})
    return {'method': {'complete': True}, 'samples': samples}

class InsightsCaptureTest(unittest.TestCase):
    def test_accepts_exact_budget_for_both_versions(self):
        result = audit.audit(fixture())
        self.assertTrue(result['complete']); self.assertEqual(result['tracked_requests'], 50)
    def test_rejects_wrong_period_even_with_correct_request_count(self):
        data = fixture(); data['samples'][0]['insights_stages']['all_time']['queries'] = [audit.PATH + '?timeWindow=month']
        self.assertFalse(audit.audit(data)['complete'])
    def test_rejects_extra_refresh(self):
        data = fixture(); data['samples'][0]['insights_stages']['refresh_burst']['requests'] = {audit.KEY: 2}
        self.assertFalse(audit.audit(data)['complete'])
    def test_rejects_missing_or_duplicate_samples(self):
        data = fixture(); data['samples'][1] = copy.deepcopy(data['samples'][0])
        self.assertFalse(audit.audit(data)['complete'])
    def test_rejects_unaccounted_or_failed_transport(self):
        for field, value in [('response_statuses', {}), ('response_statuses', {audit.KEY: {'500': 5}}), ('transport_errors', {audit.KEY: ['failed']})]:
            data = fixture(); data['samples'][0][field] = value
            self.assertFalse(audit.audit(data)['complete'])
    def test_rejects_missing_stage_and_incomplete_report(self):
        data = fixture(); del data['samples'][0]['insights_stages']['same_period']
        self.assertFalse(audit.audit(data)['complete'])
        data = fixture(); data['method']['complete'] = False
        self.assertFalse(audit.audit(data)['complete'])

if __name__ == '__main__': unittest.main()
