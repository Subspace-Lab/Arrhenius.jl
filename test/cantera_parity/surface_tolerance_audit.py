"""Independent pytest predicates and input/state corruption controls."""
import argparse,copy,json
from pathlib import Path
import tomllib
import numpy as np
from pytest import approx


def validate(data,reference):
    names=reference['species'];assert data['species']==names and len(names)==11
    assert data['surface_T']==data['gas_T']==900. and data['surface_P']==101325.
    assert data['equilibrium_T']==approx(reference['equilibrium']['T'])
    assert data['equilibrium_X']==approx(reference['equilibrium']['X'])
    assert data['assertion_rtol']==1e-6 and data['assertion_atol']==1e-12
    assert len(data['runs'])==2
    initial=[.5 if n=='PT(S)' else .4 if n=='H(S)' else .1 if n=='O(S)' else 0. for n in names]
    for run,(rtol,atol) in zip(data['runs'],[(1e-5,1e-12),(1e-7,1e-14)]):
        assert run['rtol']==rtol and run['atol']==atol
        assert run['retcode']=='Success' and run['time']==1.
        assert len(run['initial_coverages'])==len(run['coverages'])==11
        assert run['initial_coverages']==approx(initial)
        assert np.isfinite(run['coverages']).all()
    a=np.array(data['runs'][0]['coverages']);b=np.array(data['runs'][1]['coverages'])
    assert a==approx(b)
    assert any(a!=b)
    return float(np.max(np.abs(a-b)/np.maximum(1e-12,1e-6*np.abs(b))))


def audit(native,reference):
    ratio=validate(native,reference)
    mutations={
        'identical_results':lambda d:d['runs'][0].update(coverages=list(d['runs'][1]['coverages'])),
        'major_species_excess':lambda d:d['runs'][0]['coverages'].__setitem__(0,1.),
        'trace_absolute_excess':lambda d:d['runs'][0]['coverages'].__setitem__(6,1e-10),
        'missing_species':lambda d:d['runs'][1]['coverages'].pop(),
        'species_order':lambda d:d['species'].reverse(),
        'changed_tolerance':lambda d:d['runs'][0].update(rtol=1e-4),
        'initial_state_not_reset':lambda d:d['runs'][1].update(initial_coverages=list(d['runs'][0]['coverages'])),
        'unfinished_time':lambda d:d['runs'][1].update(time=.9),
        'gas_temperature_not_reset':lambda d:d.update(gas_T=d['equilibrium_T']),
        'nonfinite':lambda d:d['runs'][0]['coverages'].__setitem__(0,float('nan'))}
    rejected={}
    for name,mutate in mutations.items():
        bad=copy.deepcopy(native);mutate(bad)
        try:validate(bad,reference)
        except AssertionError:rejected[name]=True
        else:rejected[name]=False
    assert all(rejected.values()),rejected
    cross=[float(np.max(np.abs(np.array(n['coverages'])-np.array(r['coverages'])))) for n,r in zip(native['runs'],reference['runs'])]
    return {'passed':True,'maximum_error_over_bound':ratio,'negative_controls':rejected,
            'observed_cross_solver_max_abs_by_run':cross,
            'scope':'Original within-solver tolerance predicates; cross-solver differences are observations, not added acceptance limits.'}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('native',type=Path);p.add_argument('reference',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
    result=audit(tomllib.loads(a.native.read_text()),json.loads(a.reference.read_text()))
    a.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
