#!/usr/bin/env python3
"""Run the controlled poster/scroll journey on the dedicated Patrol simulator."""
import argparse, hashlib, json, statistics, subprocess, uuid
from pathlib import Path
from urllib.request import urlopen
from runtime_ios_fixture import demo_firebase_plist


def audit(data, capture, variant):
    errors=[]
    rows=data.get('samples',[])
    expected={(s,r) for s in ('home','watchlist','search') for r in range(6)}
    if not data.get('complete') or len(rows)!=18 or {(r['scenario'],r['repetition']) for r in rows}!=expected: errors.append('incomplete/duplicate samples')
    if data.get('method',{}).get('capture_id')!=capture or data.get('method',{}).get('variant')!=variant: errors.append('stale capture')
    if errors: return errors
    for r in rows:
        if not all(key in r for key in ('frames','offsets','mounted','scrolled','cleared','requests','responses')):
            errors.append('invalid sample schema'); continue
        if not r['frames'] or len(r['offsets'])!=12 or max(r['offsets'])<300: errors.append('missing scroll frames/movement')
        if r['mounted']['image_bytes']<=0 or r['scrolled']['pending_images'] or r['cleared']['image_bytes']: errors.append('invalid image state')
        for key,count in r['requests'].items():
            status=r['responses'].get(key,{})
            if sum(status.values())!=count or any(int(s)>=400 for s in status): errors.append('transport mismatch')
    return errors


def summarize(data):
    result=[]
    for name in ('home','watchlist','search'):
        rows=[r for r in data['samples'] if r['scenario']==name and r['repetition']>0]
        frames=[f for r in rows for f in r['frames']]
        percentile=lambda values,p: sorted(values)[min(len(values)-1, int((len(values)-1)*p))]
        result.append({'scenario':name,'samples':len(rows),'mounted_image_bytes_median':statistics.median(r['mounted']['image_bytes'] for r in rows),'scrolled_image_bytes_median':statistics.median(r['scrolled']['image_bytes'] for r in rows),'peak_image_bytes_median':statistics.median(r['peak_image_bytes'] for r in rows),'frames':len(frames),'build_p95_us':percentile([f['build_us'] for f in frames],.95),'raster_p95_us':percentile([f['raster_us'] for f in frames],.95),'build_over_16667':sum(f['build_us']>16667 for f in frames),'raster_over_16667':sum(f['raster_us']>16667 for f in frames),'build_over_8333':sum(f['build_us']>8333 for f in frames),'raster_over_8333':sum(f['raster_us']>8333 for f in frames)})
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--variant',choices=['before','after'],required=True)
    args=parser.parse_args()
    root=Path(__file__).resolve().parents[1]
    args.output.mkdir(parents=True,exist_ok=False)
    capture=str(uuid.uuid4())
    files=list((root/'lib').rglob('*.dart'))+[root/'patrol_test/poster_scroll_test.dart',root/'patrol_test/support/controlled_poster_cache.dart',Path(__file__).resolve()]
    hashes={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    (args.output/'source.json').write_text(json.dumps(hashes,indent=2)+'\n')
    (args.output/'capture-id.txt').write_text(capture+'\n')
    with demo_firebase_plist(root), (args.output/'patrol.log').open('w') as log:
        result=subprocess.run([str(root/'scripts/test-patrol.sh'),'-d','D4255A47-A9F1-4BFB-A770-557608119574','-t','patrol_test/poster_scroll_test.dart','--dart-define=API_BASE_URL=http://127.0.0.1:3007','--dart-define=POSTER_CAPTURE_ID='+capture,'--dart-define=POSTER_VARIANT='+args.variant],cwd=root,stdout=log,stderr=subprocess.STDOUT)
    data=json.load(urlopen('http://127.0.0.1:3007/benchmark/results',timeout=10))
    (args.output/'runtime.json').write_text(json.dumps(data,indent=2)+'\n')
    errors=audit(data,capture,args.variant)
    if result.returncode: errors.append('native runner failure')
    if any(hashlib.sha256((root/p).read_bytes()).hexdigest()!=h for p,h in hashes.items()): errors.append('source changed during capture')
    (args.output/'audit.json').write_text(json.dumps({'complete':not errors,'errors':errors},indent=2)+'\n')
    if errors: raise SystemExit(str(errors))
    summary=summarize(data)
    (args.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary,indent=2))
if __name__=='__main__': main()
