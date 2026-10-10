import copy,importlib.util,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('comparison',Path(__file__).resolve().parents[1]/'compare-poster-scroll.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class ComparisonTests(unittest.TestCase):
    def data(self):
        return {'method':{'dpr':3},'samples':[{'scenario':s,'repetition':r,'requests':{'GET /fixture':1},'responses':{'GET /fixture':{'200':1}},'image_file_reads':{'poster':1},'scrolled':{'image_bytes':1000,'image_count':1},'frames':[{'build_us':100,'raster_us':200}],'offsets':[500]} for s in ['home','watchlist','search'] for r in range(1,6)]}
    def test_accepts_memory_difference_with_same_work(self):
        before=self.data();after=copy.deepcopy(before)
        for row in after['samples']:row['scrolled']['image_bytes']=500
        result=module.compare(before,after)
        self.assertTrue(result['matched']);self.assertEqual(result['rows'][0]['image_reduction_percent'],50)
    def test_rejects_changed_image_or_request_work(self):
        before=self.data();after=copy.deepcopy(before);after['samples'][0]['image_file_reads']={}
        self.assertFalse(module.compare(before,after)['matched'])
        after=copy.deepcopy(before);after['samples'][0]['requests']['GET /fixture']=2
        self.assertFalse(module.compare(before,after)['matched'])
    def test_rejects_density_change(self):
        before=self.data();after=copy.deepcopy(before);after['method']['dpr']=2
        self.assertFalse(module.compare(before,after)['matched'])
if __name__=='__main__':unittest.main()
