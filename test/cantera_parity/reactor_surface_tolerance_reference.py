"""Pinned TestAdvanceCoverages original method and captured duplicate reference."""
import argparse,ast,hashlib,json
from pathlib import Path
from types import SimpleNamespace
import tomllib
import numpy as np
from pytest import approx
from reactor_reference import environment


def reference(source,output):
    ct,_,_,env=environment(source)
    folder=Path(__file__).parent/'fixtures/cantera-726522be/pt_coverages'
    meta=tomllib.loads((folder/'fixture.toml').read_text())
    for name,digest in meta['sha256'].items():
        assert hashlib.sha256((folder/name).read_bytes()).hexdigest()==digest,name
    assert (source/'data/ptcombust.yaml').read_bytes()==(folder/'ptcombust.yaml').read_bytes()
    assert hashlib.sha256((source/'data/gri30.yaml').read_bytes()).hexdigest()==meta['gri30_sha256']
    ct.add_data_directory(str(source/'data'))
    tree=ast.parse((source/'test/python/test_reactor.py').read_text())
    fixture=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='setup_advance_converages_data')
    fixture.decorator_list=[]  # execute the original body without pytest registration
    cls=next(n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='TestAdvanceCoverages')
    method=next(n for n in cls.body if isinstance(n,ast.FunctionDef) and n.name=='test_different_tolerances')
    ns={'ct':ct,'approx':approx}
    exec(compile(ast.Module(body=[fixture,method],type_ignores=[]),'pinned-original','exec'),ns)
    obj=SimpleNamespace();ns[fixture.name](SimpleNamespace(cls=obj));ns[method.name](obj)
    obj=SimpleNamespace();ns[fixture.name](SimpleNamespace(cls=obj))
    equilibrium={'T':obj.gas.T,'P':obj.gas.P,'X':obj.gas.X.tolist()}
    assert equilibrium['T']==approx(meta['equilibrium_T'])
    assert equilibrium['X']==approx(meta['equilibrium_X'])
    runs=[]
    for rtol,atol in [(1e-5,1e-12),(1e-7,1e-14)]:
        obj.surf.coverages='O(S):0.1, PT(S):0.5, H(S):0.4';obj.gas.TP=obj.surf.TP
        initial=obj.surf.coverages.copy()
        obj.surf.advance_coverages(dt=1.,rtol=rtol,atol=atol)
        runs.append({'rtol':rtol,'atol':atol,'time':1.,'initial_coverages':initial.tolist(),'coverages':obj.surf.coverages.tolist()})
    loose=np.array(runs[0]['coverages']);tight=np.array(runs[1]['coverages'])
    assert loose==approx(tight) and any(loose!=tight)
    raw=ct.Interface(str(folder/'ptcombust.yaml'),'Pt_surf')
    reloaded=ct.Interface(str(folder/'pt.source.yaml'),'Pt_surf')
    assert raw.species_names==reloaded.species_names==meta['surface_species']
    assert raw.reaction_equations()==reloaded.reaction_equations()
    deviations=[]
    for T,P,theta in [(900.,ct.one_atm,runs[0]['initial_coverages']),(1200.,2*ct.one_atm,[1/11]*11)]:
        for s in (raw,reloaded):
            s.TP=T,P;s.coverages=theta;s.adjacent['gas'].TPX=T,P,equilibrium['X']
        pairs=[(reloaded.forward_rate_constants,raw.forward_rate_constants),
               (reloaded.reverse_rate_constants,raw.reverse_rate_constants),
               (reloaded.net_rates_of_progress,raw.net_rates_of_progress)]
        for a,b in pairs:assert np.all(np.abs(a-b)<=np.maximum(1e-12,1e-6*np.abs(b)))
        deviations.append({'T':T,'P':P,'coverages':theta,'maximum_absolute_by_quantity':[float(np.max(np.abs(a-b))) for a,b in pairs]})
    env.pop('upstream_test',None)
    record={'upstream_test':'TestAdvanceCoverages.test_different_tolerances','environment_gate':env,
        'original_fixture_and_method_passed':True,'equilibrium':equilibrium,'species':meta['surface_species'],
        'surface_T':obj.surf.T,'surface_P':obj.surf.P,'gas_T':obj.gas.T,'runs':runs,
        'assertion_rtol':1e-6,'assertion_atol':1e-12,'roundtrip_states':deviations,
        'maximum_error_over_bound':float(np.max(np.abs(loose-tight)/np.maximum(1e-12,1e-6*np.abs(tight)))),
        'solver_stats':'not provided by this Interface API','retcode':'not provided; calls returned normally'}
    (output/'reference.json').write_text(json.dumps(record,indent=2)+'\n')
    print('Original fixture/method, captured reference and input roundtrips passed')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source-dir',type=Path,required=True)
    p.add_argument('--output-dir',type=Path,required=True);a=p.parse_args()
    a.output_dir.mkdir(parents=True,exist_ok=False);reference(a.source_dir,a.output_dir)
