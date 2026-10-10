#!/usr/bin/env python3
"""Run isolated native group journeys and a paired Group Detail memory check."""
import argparse, hashlib, json, re, subprocess, uuid
from pathlib import Path
from urllib.request import urlopen
from runtime_ios_fixture import demo_firebase_plist

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device',required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();root=Path(__file__).resolve().parents[1]
    devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json']))
    device=next(d for rows in devices['devices'].values() for d in rows if d['udid']==args.device)
    assert any(word in device['name'].lower() for word in ['patrol','memory'])
    manifest=json.load(urlopen('http://127.0.0.1:3007/benchmark/manifest',timeout=5))
    assert manifest['database']=='flixie_runtime_fixture'
    args.output.mkdir(parents=True,exist_ok=False)
    capture=str(uuid.uuid4())
    paths=list((root/'lib').rglob('*.dart'))+list((root/'test/features/social/group_detail').glob('*.dart'))+[root/p for p in ['test/features/social/group_members/widget_test.dart','patrol_test/group_detail_members_test.dart','patrol_test/group_detail_memory_test.dart','patrol_test/support/group_detail_before.dart']]
    hashes={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    (args.output/'sources.json').write_text(json.dumps(hashes,indent=2)+'\n')
    (args.output/'device.json').write_text(json.dumps(device,indent=2)+'\n')
    with demo_firebase_plist(root), (args.output/'native.log').open('w') as log:
        result=subprocess.run([str(root/'scripts/test-patrol.sh'),'-d',args.device,'-t','patrol_test/group_detail_members_test.dart','--dart-define=API_BASE_URL=http://127.0.0.1:3007','--dart-define=GROUP_MEMORY_CAPTURE='+capture],cwd=root,stdout=log,stderr=subprocess.STDOUT)
    log=re.sub(r'\x1b\[[0-9;]*m','',(args.output/'native.log').read_text())
    if result.returncode or not re.search(r'Successful:\s*11\b',log) or not re.search(r'Failed:\s*0\b',log):
        raise SystemExit('Native suite did not pass all 11 tests; preserve evidence.')
    data=json.load(urlopen('http://127.0.0.1:3007/benchmark/results',timeout=10))
    (args.output/'runtime.json').write_text(json.dumps(data,indent=2)+'\n')
    assert data['complete'] and data['method']['capture_id']==capture
    expected={(v,n) for v in ['before','after','chat'] for n in range(1,6)}
    assert len(data['samples'])==15 and {(r['version'],r['repetition']) for r in data['samples']}==expected
    phases=['baseline','mounted','unmounted','neutral_input','cache_cleared']
    assert len(data['memory_samples'])==75 and {(r['version'],r['repetition'],r['phase']) for r in data['memory_samples']}=={(v,n,p) for v,n in expected for p in phases}
    dates=[int(r['date_last_gc']) for r in data['memory_samples']]
    assert all(b>a for a,b in zip(dates,dates[1:]))
    assert all(hashlib.sha256((root/name).read_bytes()).hexdigest()==sha for name,sha in hashes.items())
    for r in data['samples']:
        assert r['responses']=={k:{'200':v} for k,v in r['requests'].items()}
        assert r['conversation_attempts']==(1 if r['version']=='before' else 0)
    (args.output/'audit.json').write_text(json.dumps({'complete':True,'native_tests':11,'visits':15,'gc_samples':75,'source_hashes_match':True,'transport_clean':True},indent=2)+'\n')
    print('PASS: 11 native tests, 15 visits, 75 GC observations; inspect live counts before making retention claims.')
if __name__=='__main__':main()
