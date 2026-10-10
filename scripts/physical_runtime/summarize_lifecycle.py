#!/usr/bin/env python3
"""Validate and summarize a completed physical-device lifecycle fixture capture."""
import argparse,importlib.util,json,statistics,math,sys
from pathlib import Path
from urllib.request import urlopen
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
spec=importlib.util.spec_from_file_location('lifecycle',ROOT/'scripts/capture-lifecycle-baseline.py')
lifecycle=importlib.util.module_from_spec(spec);spec.loader.exec_module(lifecycle)
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture-id',required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    native=json.load(urlopen('http://127.0.0.1:3007/benchmark/results?suite=lifecycle',timeout=10))
    (args.output/'native.json').write_text(json.dumps(native,indent=2)+'\n')
    assert native['complete'] and native['method']['capture_id']==args.capture_id
    assert native['method']['mode']=='release'
    samples=native['samples']
    expected={(scenario,size,repetition) for scenario in lifecycle.SCENARIOS for size in [20,400] for repetition in range(1,6)}
    assert len(samples)==len(expected) and {(r['scenario'],r['library_size'],r['repetition']) for r in samples}==expected
    audit=lifecycle.transport_audit(samples)
    (args.output/'transport-audit.json').write_text(json.dumps(audit,indent=2)+'\n')
    assert audit['clean'],'Transport failures: keep evidence, do not label this a reliable baseline'
    summary=[]
    for scenario in lifecycle.SCENARIOS:
        for size in [20,400]:
            rows=[r for r in samples if r['scenario']==scenario and r['library_size']==size]
            summary.append({'scenario':scenario,'library_size':size,'samples':len(rows),'useful_median_ms':statistics.median(r['useful_content_us'] for r in rows)/1000,'useful_p95_ms':max(r['useful_content_us'] for r in rows)/1000,'settled_median_ms':statistics.median(r['settled_us'] for r in rows)/1000,'requests':[sum(r['requests'].values()) for r in rows],'profile_reads':[r['phases_us'].get('profile_calls',0) for r in rows],'rss_peak_median_mib':statistics.median(r['rss_peak_bytes'] for r in rows)/1048576})
    (args.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary,indent=2))
if __name__=='__main__':main()
