"""Independent pinned-comparator acceptance and destructive-data negative controls."""
import argparse, hashlib, importlib.util, json
from pathlib import Path
import numpy as np


def audit(source, fixture, trajectory):
    spec=importlib.util.spec_from_file_location('upstream_comparator',source/'test/python/utilities.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    reference=np.loadtxt(fixture/'reference.csv',delimiter=',')
    sample=np.loadtxt(trajectory,delimiter=',')
    def accepts(data):
        if data.shape!=(50,16) or not np.isfinite(data).all():return False
        if not np.all(np.diff(data[:,0])>0) or data[-1,0]!=1e-3:return False
        if not np.allclose(data[:,0],np.linspace(1e-6,1e-3,50),rtol=0,atol=1e-18):return False
        return module.compareProfiles(reference,data,rtol=1e-5,atol=1e-9,xtol=1e-12) is None
    assert accepts(sample), 'Actual complete trajectory fails original comparator'
    corruptions={}
    for name,column in [('temperature',1),('pressure',2),('gas_mass',3),
                        ('gas_composition',4+int(np.argmax(sample[20,4:8]))),
                        ('surface_coverage',8+int(np.argmax(sample[20,8:16])))]:
        bad=sample.copy();bad[20,column]*=2
        corruptions[name]=not accepts(bad)
    corruptions['omitted_column']=not accepts(sample[:,:-1])
    bad=sample.copy();bad[20,0]=bad[19,0];corruptions['duplicate_time']=not accepts(bad)
    bad=sample.copy();bad[20,8]=np.nan;corruptions['nonfinite']=not accepts(bad)
    assert all(corruptions.values()),corruptions
    return {'passed':True,'shape':list(sample.shape),'negative_controls':corruptions,
            'trajectory_sha256':hashlib.sha256(trajectory.read_bytes()).hexdigest(),
            'maximum_absolute_by_column':np.max(np.abs(sample-reference),axis=0).tolist(),
            'limits':{'rtol':1e-5,'atol':1e-9,'xtol':1e-12}}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('fixture',type=Path)
    p.add_argument('trajectory',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
    result=audit(a.source,a.fixture,a.trajectory)
    a.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
