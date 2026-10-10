#!/usr/bin/env python3
"""Validate populated Search queries, paging and exact HTTP accounting."""
import argparse,json
from pathlib import Path

def audit(report):
    samples=report.get('samples',[])
    expected={('search',c,n) for c in ('cold','warm') for n in range(1,6)}
    errors=[]
    if not report.get('method',{}).get('complete') or len(samples)!=10 or {(s['scenario'],s['cache'],s['repetition']) for s in samples}!=expected:
        errors.append('Incomplete/duplicate sample set')
    queries={name: [{'path':'/search','value':'a','type':typ,'page':str(page)}] for name,typ,page in [('typing','all',1),('paging','all',2),('movies','movie',1),('shows','tv',1),('people','person',1)]}
    queries.update({name:[{'path':'/search/collection','value':value,'page':'1'}] for name,value in [('collections','a'),('refresh','a'),('empty','zzzz-no-runtime-match')]})
    queries['clear']=[]
    for s in samples:
        load={'GET /trending/movie/day':1} if s['cache']=='cold' else {}
        total={**load,'GET /search':5,'GET /search/collection':3}
        if s.get('requests_load')!=load or s.get('requests_total')!=total:
            errors.append('Incorrect load/total HTTP budget')
        if s.get('response_statuses')!={k:{'200':v} for k,v in total.items()} or s.get('transport_errors'):
            errors.append('Failed/missing HTTP responses')
        stages=s.get('search_stages',{})
        if set(stages)!=set(queries): errors.append('Missing/unexpected search stage')
        for name,q in queries.items():
            stage=stages.get(name,{})
            budget={'GET '+q[0]['path']:1} if q else {}
            if stage.get('queries')!=q or stage.get('requests')!=budget or stage.get('settled_us',0)<=0:
                errors.append('Wrong query/request/timing: '+name)
        if s.get('search_queries')!=[q for qs in queries.values() for q in qs]: errors.append('Incorrect full query sequence')
    return {'complete':not errors,'samples':len(samples),'tracked_requests':sum(sum(s.get('requests_total',{}).values()) for s in samples),'errors':errors}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('capture',type=Path);args=parser.parse_args()
    result=audit(json.loads((args.capture/'runtime.json').read_text()))
    (args.capture/'search-audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
    if not result['complete']:raise SystemExit(1)
