#!/usr/bin/env python3
"""Copy current Flutter sources into a separate physical-benchmark workspace."""
import argparse,shutil,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--team',required=True)
    args=parser.parse_args()
    target=Path(tempfile.mkdtemp(prefix='flixie-physical-',dir='/private/tmp'))
    for name in ['lib','assets','ios','patrol_test','test','tool','scripts','third_party']:
        shutil.copytree(ROOT/name,target/name,symlinks=True,ignore=shutil.ignore_patterns('.symlinks','ephemeral','*.xcuserstate'))
    for name in ['pubspec.yaml','pubspec.lock','analysis_options.yaml','.metadata']:
        shutil.copyfile(ROOT/name,target/name)
    subprocess.run(['swift',str(ROOT/'scripts/physical_runtime/configure.swift'),str(target),args.team],check=True)
    subprocess.run(['flutter','pub','get','--offline'],cwd=target,check=True)
    print(target)
if __name__=='__main__':main()
