"""Run the original energy-disabled diamond regression against the pinned inputs."""
import argparse
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import tomllib
import numpy as np
from pytest import approx
from reactor_reference import environment


def run(source, output):
    ct, _, _, env = environment(source)
    env.pop('upstream_test', None)
    folder = Path(__file__).parent / 'fixtures/cantera-726522be/diamond'
    config = tomllib.loads((folder/'fixture.toml').read_text())
    for name, digest in config['sha256'].items():
        assert hashlib.sha256((folder/name).read_bytes()).hexdigest() == digest, name
    for raw, name in [('data/diamond.yaml','diamond.yaml'),
                      ('test/data/WallKinetics-coverages-regression1.csv','reference.csv')]:
        assert (source/raw).read_bytes() == (folder/name).read_bytes()
    ct.add_data_directory(str(source/'data'))
    spec=importlib.util.spec_from_file_location('pinned_utils',source/'test/python/utilities.py')
    util=importlib.util.module_from_spec(spec); spec.loader.exec_module(util)
    cls=next(n for n in ast.parse((source/'test/python/test_reactor.py').read_text()).body
             if isinstance(n,ast.ClassDef) and n.name=='TestSurfaceKinetics')
    cls.body=[n for n in cls.body if isinstance(n,ast.FunctionDef) and
              n.name in ('make_reactors','test_coverages_regression1')]
    ns={'ct':ct,'np':np,'approx':approx,'compareProfiles':util.compareProfiles}
    exec(compile(ast.Module(body=[cls],type_ignores=[]),'pinned-original','exec'),ns)
    obj=ns['TestSurfaceKinetics'](); obj.test_work_path=output
    obj.test_coverages_regression1(source/'test/data')
    original=ct.Interface(str(folder/'diamond.yaml'),'diamond_100')
    reloaded=ct.Interface(str(folder/'diamond.source.yaml'),'diamond_100')
    gas=ct.Solution(str(folder/'diamond.gas.yaml'),'gas')
    assert original.species_names == reloaded.species_names
    assert original.reaction_equations() == reloaded.reaction_equations()
    assert original.adjacent['gas'].species_names == gas.species_names
    assert gas.n_reactions == original.adjacent['gas'].n_reactions == 0
    deviations=[]
    for temperature, pressure, composition, cov in [
        (1200.,1e3,'H:0.002,H2:1,CH4:0.01,CH3:0.0002',[.3,0,0,0,.7,0,0,0]),
        (900.,1e5,'H:1,H2:1,CH4:1,CH3:1',[.125]*8),
        (1500.,2e3,'H:1,H2:10,CH4:2,CH3:1',[.1,.2,.1,.1,.1,.1,.1,.2])]:
        for surf in (original,reloaded):
            surf.TP=temperature,pressure;surf.coverages=cov
            surf.adjacent['gas'].TPX=temperature,pressure,composition
        gas.TPX=temperature,pressure,composition
        pairs=[(reloaded.forward_rate_constants,original.forward_rate_constants),
               (reloaded.reverse_rate_constants,original.reverse_rate_constants),
               (reloaded.net_rates_of_progress,original.net_rates_of_progress),
               (gas.partial_molar_enthalpies,original.adjacent['gas'].partial_molar_enthalpies)]
        for actual, expected in pairs:
            assert np.all(np.abs(actual-expected)<=np.maximum(1e-12,1e-6*np.abs(expected)))
        deviations.append({'T':temperature,'P':pressure,'composition':composition,'coverages':cov,
                           'maximum_absolute_by_quantity':[float(np.max(np.abs(a-b))) for a,b in pairs]})
    record={'upstream_test':'TestSurfaceKinetics.test_coverages_regression1','environment':env,
            'original_method_passed':True,'roundtrip_states':deviations,
            'roundtrip_quantities':['forward rates','reverse rates','net progress','gas partial molar enthalpies'],
            'comparison':{'rtol':1e-5,'atol':1e-9,'xtol':1e-12},'integration':{'rtol':1e-9,'atol':1e-15},
            'original_profile_shape':list(np.loadtxt(output/'test_coverages_regression1.csv',delimiter=',').shape)}
    (output/'reference.json').write_text(json.dumps(record,indent=2)+'\n')
    print('Original method and three roundtrip input states passed')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--source-dir',type=Path,required=True)
    parser.add_argument('--output-dir',type=Path,required=True);args=parser.parse_args()
    args.output_dir.mkdir(parents=True,exist_ok=False)
    run(args.source_dir,args.output_dir)
