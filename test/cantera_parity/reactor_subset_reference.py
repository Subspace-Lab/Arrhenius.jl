"""Full five-column species-subset connector reference, with pinned inputs."""
import ast,json,textwrap,tomllib
from pathlib import Path
import numpy as np
from export_subset_fixture import METHOD,definition,digest
from reactor_reference import check_close

FOLDER=Path(__file__).resolve().parent/'fixtures/cantera-726522be/mfc_subset3'
def subset_inputs(source,provenance):
    inputs=tomllib.loads((FOLDER/'fixture.toml').read_text())
    assert inputs['cantera_commit']==provenance['cantera_commit']
    assert digest(definition(source))==inputs['definition_sha256_lf']
    assert digest((source/'data/h2o2.yaml').read_bytes())==inputs['source_h2o2_sha256_lf']
    for file,key in ((inputs['raw_file'],'raw_sha256_lf'),(inputs['normalized_file'],'normalized_sha256_lf'),('equivalence.json','equivalence_sha256_lf')):
        assert digest((FOLDER/file).read_bytes())==inputs[key]
    assert json.loads((FOLDER/'equivalence.json').read_text())['input_equivalence_passed']
    return inputs

def reference_subset(ct,provenance,mechanism,source):
    inputs=subset_inputs(source,provenance)
    # Run the original unmodified method as well as the shared-input version.
    from pytest import approx
    ct.add_data_directory(str(source/'data'))
    text=(source/'test/python/test_reactor.py').read_text()
    cls=next(n for n in ast.parse(text).body if isinstance(n,ast.ClassDef) and n.name=='TestConnectorJacobians')
    method=next(n for n in cls.body if isinstance(n,ast.FunctionDef) and n.name==METHOD)
    code=textwrap.dedent(ast.get_source_segment(text,method));namespace={'ct':ct,'np':np,'approx':approx}
    exec(code,namespace);namespace[METHOD](None)
    up=ct.Solution(str(FOLDER/inputs['normalized_file']),inputs['phase'])
    down=ct.Solution(str(mechanism),'ohmech')
    up.TPX=1000,2*ct.one_atm,'H2:2,O2:1,AR:8'
    down.TPX=900,ct.one_atm,'H2:1,O2:0.5,AR:8';down.set_multiplier(0)
    r1=ct.IdealGasMoleReactor(up,energy='off');r2=ct.IdealGasMoleReactor(down,energy='off')
    flow=ct.MassFlowController(r1,r2,mdot=0.02);net=ct.ReactorNet([r1,r2])
    assert r1.n_vars==5 and (net.rtol,net.atol)==(1e-9,1e-15)
    J=np.asarray(net.jacobian);fd=np.asarray(net.finite_difference_jacobian)
    rows=[r1.n_vars+r2.component_index(sp) for sp in down.species_names]
    shared=[down.species_index(sp) for sp in up.species_names]
    block=J[rows,:5];oracle=fd[rows,:5]
    failure=None
    try:
        for row in shared:assert np.any(block[row,:]!=0)
        for row in range(10):
            if row not in shared:assert block[row,:]==approx(np.zeros(5),abs=1e-15)
        for row in shared:assert block[row,:]==approx(oracle[row,:],rel=1e-4,abs=1e-10)
    except AssertionError as error:failure={'kind':'assertion_failed','exception':str(error)}
    return {'inputs':inputs,'original_method_passed':True,'original_method_sha256_lf':digest(code),
        'species_up':up.species_names,'species_down':down.species_names,
        'mw_up':up.molecular_weights.tolist(),'mw_down':down.molecular_weights.tolist(),
        'state':net.get_state().tolist(),'jacobian':J.tolist(),'fd_jacobian':fd.tolist(),
        'species_block':block.tolist(),'fd_species_block':oracle.tolist(),'shared_rows_0based':shared,
        'rtol':net.rtol,'atol':net.atol,'temperature':[r1.T,r2.T],'pressure':[r1.phase.P,r2.phase.P],
        'volume':[r1.volume,r2.volume],'energy_enabled':[r1.energy_enabled,r2.energy_enabled],
        'transport_model':[up.transport_model,down.transport_model],'mdot':flow.mass_flow_rate,
        'downstream_multipliers':[down.multiplier(i) for i in range(down.n_reactions)],
        'solver_status':'not applicable: static Jacobian test; no integration',
        'failure':failure,'reference_assertions_passed':failure is None}
