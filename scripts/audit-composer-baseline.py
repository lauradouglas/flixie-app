#!/usr/bin/env python3
"""Audit populated composer stages, fixed endpoint work and HTTP accounting."""
import argparse
from collections import Counter
import json
from pathlib import Path

def user(i): return f'GET /users/runtime-fixture-{i}/watch-providers'
def stages(before):
    def group(i, members):
        return {f'GET /groups/runtime-plan-group-{i}/members': 1, **{user(m): 1 for m in members}}
    return {'friend_first': {user(2): 1}, 'friend_second': {user(3): 1}, 'group_mode': {},
        'group_first': group(0, [0, 2, 3, 4] if before else [4]),
        'group_second': group(1, [0, 3, 4, 5] if before else [5]),
        'group_return': group(0, [0, 2, 3, 4] if before else []),
        'friend_mode': {}, 'friend_return': {user(2): 1} if before else {}}

def audit(report, *, before):
    samples=report.get('samples', []); errors=[]
    keys={(s['scenario'],s['cache'],s['repetition']) for s in samples}
    expected={('watch_composer',cache,i) for cache in ('cold','warm') for i in range(1,6)}
    if not report.get('method',{}).get('complete') or len(samples)!=10 or keys!=expected:
        errors.append('Incomplete or duplicate sample set')
    for sample in samples:
        load={'GET /friends/runtime-fixture-0':1,'GET /groups/user/runtime-fixture-0':1,user(0):1}
        if sample['cache']=='cold': load['GET /movies/348/GB/watch/providers']=1
        if sample.get('requests_load')!=load: errors.append('Initial endpoint budget differs')
        actual=sample.get('composer_stages',{}); expected_stages=stages(before)
        if set(actual)!=set(expected_stages):errors.append('Missing/unexpected stage')
        total=Counter(load)
        for name,budget in expected_stages.items():
            stage=actual.get(name,{})
            if stage.get('requests')!=budget or stage.get('settled_us',0)<=0:errors.append(f'Invalid stage {name}')
            total.update(budget)
        if sample.get('requests_total')!=dict(total):errors.append('Total endpoint budget differs')
        if sample.get('response_statuses')!={k:{'200':v} for k,v in total.items()} or sample.get('transport_errors'):
            errors.append('HTTP/transport accounting differs')
    return {'complete':not errors,'samples':len(samples),'tracked_requests':sum(sum(s.get('requests_total',{}).values()) for s in samples),'errors':errors}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('capture',type=Path);parser.add_argument('--before',action='store_true');args=parser.parse_args()
    result=audit(json.loads((args.capture/'runtime.json').read_text()),before=args.before)
    (args.capture/'composer-audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
    if not result['complete']:raise SystemExit(1)
if __name__=='__main__':main()
