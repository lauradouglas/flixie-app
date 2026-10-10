import importlib.util
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
spec=importlib.util.spec_from_file_location('poster',Path(__file__).resolve().parents[1]/'capture-poster-scroll.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class AuditTests(unittest.TestCase):
    def data(self):
        return {'complete':True,'method':{'capture_id':'fixture','variant':'before'},'samples':[{'scenario':s,'repetition':r,'frames':[{'build_us':1,'raster_us':1,'total_us':2}],'offsets':[500.0]*12,'mounted':{'image_bytes':10},'scrolled':{'pending_images':0},'cleared':{'image_bytes':0},'requests':{'GET /fixture':1},'responses':{'GET /fixture':{'200':1}}} for s in ['home','watchlist','search'] for r in range(6)]}
    def test_accepts_complete(self):
        self.assertEqual(module.audit(self.data(),'fixture','before'),[])
    def test_rejects_stale_incomplete_or_failed_transport(self):
        data=self.data(); data['method']['capture_id']='old'
        self.assertTrue(module.audit(data,'fixture','before'))
        data=self.data();data['samples'].pop()
        self.assertTrue(module.audit(data,'fixture','before'))
        data=self.data();data['samples'][0]['responses']['GET /fixture']={'503':1}
        self.assertTrue(module.audit(data,'fixture','before'))
    def test_rejects_other_suite_without_crashing(self):
        self.assertTrue(module.audit({'samples':[]},'fixture','before'))
    def test_rejects_no_images_or_no_movement(self):
        data=self.data();data['samples'][0]['mounted']['image_bytes']=0
        self.assertTrue(module.audit(data,'fixture','before'))
        data=self.data();data['samples'][0]['offsets']=[0.0]*12
        self.assertTrue(module.audit(data,'fixture','before'))
if __name__=='__main__':unittest.main()
