#!/usr/bin/env python3
"""Compare audited captures; image/request mismatches block a matched claim."""
import argparse,json,statistics
from pathlib import Path


def compare(before,after):
    errors=[]
    for field in ('manifest','dpr','physical_size','images','scope','mode'):
        if before['method'].get(field)!=after['method'].get(field): errors.append('method differs: '+field)
    index=lambda data:{(r['scenario'],r['repetition']):r for r in data['samples'] if r['repetition']>0}
    b,a=index(before),index(after)
    if b.keys()!=a.keys(): return {'matched':False,'errors':['sample keys differ']}
    for key in b:
        for field in ('requests','responses','image_file_reads'):
            if b[key][field]!=a[key][field]: errors.append(f'{key}: {field} differs')
    rows=[]
    for scenario in ('home','watchlist','search'):
        sides=[]
        for data in (b,a):
            samples=[r for k,r in data.items() if k[0]==scenario]
            frames=[f for r in samples for f in r['frames']]
            p95=lambda key:sorted(f[key] for f in frames)[int(.95*(len(frames)-1))]/1000
            sides.append({'image_bytes':statistics.median(r['scrolled']['image_bytes'] for r in samples),'image_count':statistics.median(r['scrolled']['image_count'] for r in samples),'build_p95_ms':p95('build_us'),'raster_p95_ms':p95('raster_us'),'frame_count':len(frames),'build_over_16_67_percent':100*sum(f['build_us']>16667 for f in frames)/len(frames),'raster_over_16_67_percent':100*sum(f['raster_us']>16667 for f in frames)/len(frames),'scroll_extent_range':[min(max(r['offsets']) for r in samples),max(max(r['offsets']) for r in samples)]})
        rows.append({'scenario':scenario,'before':sides[0],'after':sides[1],'image_reduction_percent':100*(1-sides[1]['image_bytes']/sides[0]['image_bytes'])})
    return {'matched':not errors,'errors':errors,'rows':rows,'limits':'Sequential debug simulator runs with five repetitions. P95s are pooled diagnostic frame times, not a physical-device FPS claim or causal speed estimate. RSS is not a heap/leak measure.'}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('before',type=Path);parser.add_argument('after',type=Path);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    for folder in (args.before,args.after):
        if not json.loads((folder/'audit.json').read_text())['complete']: raise SystemExit('Capture not audited: '+str(folder))
    result=compare(json.loads((args.before/'runtime.json').read_text()),json.loads((args.after/'runtime.json').read_text()))
    sources=[json.loads((folder/'source.json').read_text()) for folder in (args.before,args.after)]
    changed=[name for name in sources[0].keys() | sources[1].keys() if sources[0].get(name)!=sources[1].get(name)]
    expected={'lib/core/storage/library_image_warmup.dart','lib/features/watchlist/presentation/widgets/watchlist_movie_row.dart','lib/features/home/presentation/pages/home_screen.dart'}
    result['changed_sources']=sorted(changed)
    if set(changed)!=expected:
        result['matched']=False;result['errors'].append('Unexpected measured source changes')
    args.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
    if not result['matched']: raise SystemExit('Comparison mismatch; investigate before claiming matched results')
if __name__=='__main__':main()
