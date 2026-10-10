import copy
import importlib.util
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location('group_audit', Path(__file__).resolve().parents[1] / 'audit-group-plan-baseline.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


def fixture(before=False):
    stages = {'past': {}, 'active': {}, 'refresh': audit.budget(), 'refresh_burst': audit.budget(2 if before else 1), 'open_detail': audit.budget(), 'back': {}}
    total = audit.Counter(audit.budget())
    for value in stages.values(): total.update(value)
    sample = {'scenario': 'group_watch_plan', 'requests_load': audit.budget(),
              'group_stages': {k: {'requests': v, 'settled_us': 100} for k, v in stages.items()},
              'requests_total': dict(total), 'response_statuses': {k: {'200': v} for k,v in total.items()}, 'transport_errors': {}}
    return {'method': {'complete': True}, 'samples': [dict(copy.deepcopy(sample), cache=cache, repetition=i) for cache in ('cold','warm') for i in range(1,6)]}


class GroupCaptureAuditTest(unittest.TestCase):
    def test_expected_before_and_after_endpoint_accounting(self):
        for before, total, burst in [(True, 400, 13),(False,360,9)]:
            result=audit.audit(fixture(before),before=before)
            self.assertTrue(result['complete'])
            self.assertEqual(result['tracked_requests'],total)
            self.assertEqual(result['refresh_burst_reads'],burst)

    def test_missing_or_duplicate_samples_rejected(self):
        data=fixture();data['samples'][-1]=data['samples'][0]
        self.assertFalse(audit.audit(data,before=False)['complete'])

    def test_missing_navigation_stage_rejected(self):
        data=fixture();del data['samples'][0]['group_stages']['back']
        self.assertFalse(audit.audit(data,before=False)['complete'])

    def test_failed_or_missing_responses_rejected(self):
        for response in [{}, {'GET /groups/user/runtime-fixture-0': {'503': 4}}]:
            data=fixture();data['samples'][0]['response_statuses']=response
            self.assertFalse(audit.audit(data,before=False)['complete'])

    def test_transport_exception_even_with_http_counts_rejected(self):
        data=fixture();data['samples'][0]['transport_errors']={'GET /groups/user/runtime-fixture-0':['offline']}
        self.assertFalse(audit.audit(data,before=False)['complete'])

    def test_duplicate_refresh_work_cannot_pass_after_budget(self):
        self.assertFalse(audit.audit(fixture(True),before=False)['complete'])


if __name__ == '__main__': unittest.main()
