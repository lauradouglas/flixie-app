#!/usr/bin/env python3
"""Capture fresh release processes of the separately installed Flixie Benchmark app.

Build/install tool/runtime_startup.dart in an isolated workspace first. Requires
bridge.py and the existing isolated PostgreSQL/API + demo Auth services.
"""
import argparse,datetime,json,math,statistics,subprocess,time,uuid
from pathlib import Path
from urllib.request import Request,urlopen
from urllib.error import HTTPError

BASE='http://127.0.0.1:3007'
BUNDLE='com.flixie.flixieBenchmark'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device',required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--home-trace',action='store_true',help='Capture only populated Home and require Home trace markers')
    args=parser.parse_args()
    conditions=[('signed_in',20)] if args.home_trace else [('signed_out',20),('signed_in',20),('signed_in',400)]
    assert json.load(urlopen(BASE+'/benchmark/manifest',timeout=5))['database']=='flixie_runtime_fixture'
    args.output.mkdir(parents=True,exist_ok=False)
    samples=[]
    def launch(mode,size):
        nonce=str(uuid.uuid4())
        request=Request(BASE+'/benchmark/startup-config',data=json.dumps({'capture_id':nonce,'mode':mode,'library_size':size}).encode(),headers={'content-type':'application/json','authorization':'Bearer runtime-fixture-0'})
        with urlopen(request,timeout=5) as response:
            assert response.status==200
        start=time.monotonic_ns()
        result=subprocess.run(['xcrun','devicectl','device','process','launch','--device',args.device,'--terminate-existing','--json-output',str(args.output/'last-launch.json'),BUNDLE],capture_output=True,text=True,timeout=30)
        with (args.output/'launch.log').open('a') as log:log.write(result.stdout+result.stderr)
        result.check_returncode()
        launch_us=(time.monotonic_ns()-start)//1000
        deadline=time.monotonic()+60
        while time.monotonic()<deadline:
            try:
                record=json.load(urlopen(BASE+'/benchmark/results',timeout=3))
                if record.get('method',{}).get('capture_id')==nonce:
                    assert record['complete'] and len(record['samples'])==1
                    return dict(record['samples'][0],capture_id=nonce,host_launch_to_content_observed_us=(time.monotonic_ns()-start)//1000,devicectl_return_us=launch_us)
            except HTTPError as error:
                if error.code!=404:raise
            time.sleep(.05)
        raise RuntimeError('No fresh-process result before timeout; partial evidence retained')
    for mode,size in conditions:
        assert launch('prepare_'+mode,size)['prepared']
        for repetition in range(1,6):
            sample=launch(mode,size)
            assert sample['scenario']==mode and sample['library_size']==size
            if args.home_trace:
                events=sample.get('home_trace',[])
                assert any(e['phase']=='home.plans.first-frame' for e in events), 'Missing populated Home frame'
                for source in ['direct','group']:
                    assert any(e['phase']==f'api.home-plans-{source}.response' and e.get('status')==200 and 'dataMs' in e for e in events), f'Missing server timing for {source}'
            samples.append(dict(sample,repetition=repetition))
            (args.output/'partial.json').write_text(json.dumps(samples,indent=2)+'\n')
            bad_statuses={path:statuses for path,statuses in sample['response_statuses'].items() if any(int(status)>=400 for status in statuses)}
            assert not bad_statuses, f'HTTP failure before content marker; evidence retained: {bad_statuses}'
            print(f'{mode} {size} repetition {repetition}: {sample["dart_entry_to_content_us"]/1000:.1f} ms Dart-to-content',flush=True)
    summary=[]
    for mode,size in conditions:
        rows=[r for r in samples if r['scenario']==mode and r['library_size']==size]
        summary.append({'scenario':mode,'library_size':size,'samples':len(rows),'dart_entry_to_content_median_ms':statistics.median(r['dart_entry_to_content_us'] for r in rows)/1000,'host_launch_to_content_median_ms':statistics.median(r['host_launch_to_content_observed_us'] for r in rows)/1000,'host_launch_to_content_p95_ms':max(r['host_launch_to_content_observed_us'] for r in rows)/1000})
    report={'captured_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'complete':True,'mode':'release','bundle':BUNDLE,'samples':samples,'summary':summary,'boundary':'Physical iPhone, isolated fixture entrypoint. Host timing includes devicectl termination/launch and polling. Dart timing excludes native bootstrap. Not production-service performance.'}
    (args.output/'results.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
