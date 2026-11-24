"""Prepare diamond parameters with the existing exporter; output must be new."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys
from reactor_reference import environment


def prepare(source, output):
    root=Path(__file__).resolve().parents[2]
    ct,_,_,_=environment(source)
    output.mkdir(parents=True,exist_ok=False)
    ct.add_data_directory(str(source/'data'))
    sys.path.insert(0,str(root/'mechanism'))
    from export_surface import export_surface
    export_surface('diamond.yaml','diamond_100',output/'diamond.npz')
    for src,dst in [('data/diamond.yaml','diamond.yaml'),
                    ('test/data/WallKinetics-coverages-regression1.csv','reference.csv')]:
        shutil.copyfile(source/src,output/dst)
    files=['diamond.yaml','diamond.gas.yaml','diamond.source.yaml','diamond.npz','reference.csv']
    manifest='cantera_commit = "726522be4e2a13454d8415b7ef799d621f665cf3"\n'
    manifest+='integration_rtol = 1e-9\nintegration_atol = 1e-15\n'
    manifest+='profile_rtol = 1e-5\nprofile_atol = 1e-9\nprofile_xtol = 1e-12\n\n[sha256]\n'
    for name in files:
        manifest+=json.dumps(name)+' = "'+hashlib.sha256((output/name).read_bytes()).hexdigest()+'"\n'
    (output/'fixture.toml').write_text(manifest)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--source-dir',type=Path,required=True)
    parser.add_argument('--output-dir',type=Path,required=True);args=parser.parse_args()
    prepare(args.source_dir,args.output_dir)
