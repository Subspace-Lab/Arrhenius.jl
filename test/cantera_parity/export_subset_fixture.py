"""Export the pinned inert upstream phase; only reactions: none -> [] is allowed."""
import argparse,ast,hashlib,io,json
from copy import deepcopy
from pathlib import Path
import numpy as np
from ruamel.yaml import YAML
from reactor_reference import environment

METHOD='test_species_subset_mfc_cross_reactor'
SPECIES=['H2','O2','AR']
def digest(data):
    if isinstance(data,str):data=data.encode()
    return hashlib.sha256(data.replace(b'\r\n',b'\n')).hexdigest()

def definition(source):
    text=(source/'test/python/test_reactor.py').read_text()
    cls=next(n for n in ast.parse(text).body if isinstance(n,ast.ClassDef) and n.name=='TestConnectorJacobians')
    method=next(n for n in cls.body if isinstance(n,ast.FunctionDef) and n.name==METHOD)
    assignment=next(n for n in method.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='upstream_yaml' for t in n.targets))
    return ast.literal_eval(assignment.value)

def check_conversion(raw,normalized):
    assert raw['phases'][0]['reactions']=='none'
    expected=deepcopy(raw);expected['phases'][0]['reactions']=[]
    assert normalized==expected,'Only phase reactions: none -> [] may change'

def snapshot(gas):
    return {k:np.atleast_1d(getattr(gas,k)).astype(float).tolist() for k in
        ('T','P','X','Y','density','molecular_weights','partial_molar_enthalpies',
         'partial_molar_int_energies','partial_molar_cp','partial_molar_entropies',
         'net_production_rates','forward_rate_constants','reverse_rate_constants')}

def compare(before,after):
    result={}
    for key in before:
        b=np.asarray(before[key]);a=np.asarray(after[key]);assert a.shape==b.shape
        assert np.isfinite(a).all() and np.isfinite(b).all()
        delta=np.abs(a-b);assert np.all(delta<=np.maximum(1e-12,1e-6*np.abs(b))),key
        nonzero=b!=0
        result[key]={'entries':int(b.size),'max_absolute_error':float(delta.max(initial=0)),
                    'max_relative_error_nonzero_reference':float((delta[nonzero]/np.abs(b[nonzero])).max(initial=0))}
    return result

def export(source,out):
    ct,p,mechanism,env=environment(source)
    gasdef=definition(source);ct.add_data_directory(str(source/'data'))
    original=ct.Solution(yaml=gasdef)
    assert original.species_names==SPECIES and original.n_reactions==0
    raw=original.write_yaml(precision=17);yaml=YAML(typ='safe')
    data=yaml.load(raw);normalized=deepcopy(data);normalized['phases'][0]['reactions']=[]
    check_conversion(data,normalized)
    stream=io.StringIO();yaml.dump(normalized,stream);converted=stream.getvalue()
    phases={'source':original,'raw_reloaded':ct.Solution(yaml=raw),'normalized':ct.Solution(yaml=converted)}
    assert all(g.species_names==SPECIES and g.n_reactions==0 for g in phases.values())
    assert all([dict(s.input_data) for s in g.species()]==[dict(s.input_data) for s in original.species()] for g in phases.values())
    states=[]
    for T,P,X in [(1000,202650,'H2:2,O2:1,AR:8'),(900,101325,'H2:1,O2:0.5,AR:8'),
                  (300,101325,'H2:1,O2:1,AR:1'),(2500,202650,'H2:1,O2:1,AR:1')]:
        saved={}
        for label,g in phases.items():g.TPX=T,P,X;saved[label]=snapshot(g)
        states.append({'input':{'T':T,'P':P,'X':X},'snapshots':saved,
            'metrics':{label:compare(saved['source'],saved[label]) for label in ('raw_reloaded','normalized')}})
    out.mkdir(parents=True,exist_ok=False)
    (out/'upstream.raw.yaml').write_text(raw)
    (out/'upstream.normalized.yaml').write_text(converted)
    record={'environment':env,'gas_def':gasdef,'gas_def_sha256_lf':digest(gasdef),
        'write_yaml_precision':17,'only_change':'phases[0].reactions: none -> []',
        'species':SPECIES,'reaction_count':0,'duplicate_count':0,'states':states,
        'rtol':1e-6,'atol':1e-12,'tolerance_source':'test_composite.py TestSolutionSerialization.test_yaml_simple',
        'input_equivalence_passed':True,'raw_sha256_lf':digest(raw),'normalized_sha256_lf':digest(converted)}
    (out/'equivalence.json').write_text(json.dumps(record,indent=2,allow_nan=False)+'\n')
    manifest={'cantera_commit':p['cantera_commit'],'upstream_test':'test/python/test_reactor.py::TestConnectorJacobians::'+METHOD,
        'phase':'upstream_gas','species_names':SPECIES,'species_count':3,'reaction_count':0,
        'definition_sha256_lf':digest(gasdef),'source_h2o2_sha256_lf':digest((source/'data/h2o2.yaml').read_bytes()),
        'raw_file':'upstream.raw.yaml','raw_sha256_lf':digest(raw),'normalized_file':'upstream.normalized.yaml',
        'normalized_sha256_lf':digest(converted),'equivalence_sha256_lf':digest((out/'equivalence.json').read_bytes()),
        'integration_rtol':1e-9,'integration_atol':1e-15}
    (out/'fixture.toml').write_text(''.join(f'{k} = {json.dumps(v)}\n' for k,v in manifest.items()))
    return manifest

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir',type=Path,required=True);parser.add_argument('--output-dir',type=Path,required=True)
    args=parser.parse_args();print(json.dumps(export(args.source_dir,args.output_dir),indent=2))
