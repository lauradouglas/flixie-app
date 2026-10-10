import copy,importlib.util,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('search_audit',Path(__file__).resolve().parents[1]/'audit-search-baseline.py')
audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)
def fixture():
    stages={name:[{'path':'/search','value':'a','type':typ,'page':str(page)}] for name,typ,page in [('typing','all',1),('paging','all',2),('movies','movie',1),('shows','tv',1),('people','person',1)]}
    stages.update({name:[{'path':'/search/collection','value':q,'page':'1'}] for name,q in [('collections','a'),('refresh','a'),('empty','zzzz-no-runtime-match')]});stages['clear']=[]
    samples=[]
    for cache in ['cold','warm']:
        for n in range(1,6):
            load={'GET /trending/movie/day':1} if cache=='cold' else {}
            total={**load,'GET /search':5,'GET /search/collection':3}
            samples.append({'scenario':'search','cache':cache,'repetition':n,'requests_load':load,'requests_total':total,
                'response_statuses':{k:{'200':v} for k,v in total.items()},'transport_errors':{},
                'search_queries':[q for qs in stages.values() for q in qs],
                'search_stages':{name:{'queries':qs,'requests':{'GET '+qs[0]['path']:1} if qs else {},'settled_us':1} for name,qs in stages.items()}})
    return {'method':{'complete':True},'samples':samples}
class SearchCaptureTests(unittest.TestCase):
    def test_accepts_exact_accounting(self):
        r=audit.audit(fixture());self.assertTrue(r['complete']);self.assertEqual(r['tracked_requests'],85)
    def test_rejects_bad_paging_even_with_same_request_count(self):
        r=fixture();r['samples'][0]['search_stages']['paging']['queries'][0]['page']='1';self.assertFalse(audit.audit(r)['complete'])
    def test_rejects_extra_debounce_read(self):
        r=fixture();r['samples'][0]['search_stages']['typing']['requests']['GET /search']=2;self.assertFalse(audit.audit(r)['complete'])
    def test_rejects_missing_or_failed_responses(self):
        for field,value in [('response_statuses',{}),('transport_errors',{'GET /search':['closed']}),('response_statuses',{'GET /search':{'500':5}})]:
            r=fixture();r['samples'][0][field]=value;self.assertFalse(audit.audit(r)['complete'])
    def test_rejects_incomplete_or_duplicate_samples(self):
        r=fixture();r['samples'][1]=copy.deepcopy(r['samples'][0]);self.assertFalse(audit.audit(r)['complete'])
        r=fixture();r['method']['complete']=False;self.assertFalse(audit.audit(r)['complete'])
    def test_rejects_missing_stage_and_warm_trending_read(self):
        r=fixture();del r['samples'][0]['search_stages']['clear'];self.assertFalse(audit.audit(r)['complete'])
        r=fixture();r['samples'][-1]['requests_load']={'GET /trending/movie/day':1};self.assertFalse(audit.audit(r)['complete'])
if __name__=='__main__':unittest.main()
