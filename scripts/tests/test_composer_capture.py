import copy
from collections import Counter
import importlib.util
from pathlib import Path
import unittest
spec=importlib.util.spec_from_file_location('composer_audit',Path(__file__).resolve().parents[1]/'audit-composer-baseline.py')
audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)

def report(before=False):
    samples=[]
    for cache in ['cold','warm']:
        for run in range(1,6):
            load={'GET /friends/runtime-fixture-0':1,'GET /groups/user/runtime-fixture-0':1,audit.user(0):1}
            if cache=='cold':load['GET /movies/348/GB/watch/providers']=1
            stages={k:{'requests':v,'settled_us':100} for k,v in audit.stages(before).items()}
            total=Counter(load)
            for stage in stages.values():total.update(stage['requests'])
            samples.append({'scenario':'watch_composer','cache':cache,'repetition':run,'requests_load':load,'composer_stages':stages,'requests_total':dict(total),'response_statuses':{k:{'200':v} for k,v in total.items()},'transport_errors':{}})
    return {'method':{'complete':True},'samples':samples}
class ComposerAuditTest(unittest.TestCase):
    def test_both_budgets(self):
        for before,total in [(True,215),(False,105)]:
            result=audit.audit(report(before),before=before)
            self.assertTrue(result['complete']);self.assertEqual(result['tracked_requests'],total)
    def test_old_duplicate_reads_are_rejected_for_current(self):self.assertFalse(audit.audit(report(True),before=False)['complete'])
    def test_missing_or_duplicate_sample(self):
        for change in ['missing','duplicate']:
            r=report()
            if change=='missing':r['samples'].pop()
            else:r['samples'][-1]=copy.deepcopy(r['samples'][0])
            self.assertFalse(audit.audit(r,before=False)['complete'])
    def test_missing_stage(self):
        r=report();del r['samples'][0]['composer_stages']['friend_return'];self.assertFalse(audit.audit(r,before=False)['complete'])
    def test_untracked_response_and_http_error(self):
        for status in ['201','500']:
            r=report();key=next(iter(r['samples'][0]['response_statuses']));r['samples'][0]['response_statuses'][key]={status:1}
            self.assertFalse(audit.audit(r,before=False)['complete'])
    def test_transport_failure(self):
        r=report();r['samples'][0]['transport_errors']={'GET /friends/runtime-fixture-0':['closed']};self.assertFalse(audit.audit(r,before=False)['complete'])
if __name__=='__main__':unittest.main()
