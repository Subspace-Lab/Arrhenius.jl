"""Pinned constant-MFC forward and full reverse Jacobian contract."""
import ast,textwrap,hashlib
import numpy as np
from pytest import approx

METHOD='test_mfc_const_flow_cross_reactor_species'

def reference_constant(ct,provenance,mechanism,source):
    text=(source/'test/python/test_reactor.py').read_text()
    cls=next(n for n in ast.parse(text).body if isinstance(n,ast.ClassDef) and n.name=='TestConnectorJacobians')
    method=next(n for n in cls.body if isinstance(n,ast.FunctionDef) and n.name==METHOD)
    code=textwrap.dedent(ast.get_source_segment(text,cls))
    namespace={'ct':ct,'np':np,'approx':approx};ct.add_data_directory(str(source/'data'))
    exec(code,namespace);original=namespace['TestConnectorJacobians']();getattr(original,METHOD)()
    compositions=[original._X1,original._X2]
    gases=[]
    for T,P,X in zip((1000,900),(2*ct.one_atm,ct.one_atm),compositions):
        gas=ct.Solution(str(mechanism),'ohmech');gas.TPX=T,P,X;gas.set_multiplier(0);gases.append(gas)
    r1,r2=[ct.IdealGasMoleReactor(g,energy='off') for g in gases]
    flow=ct.MassFlowController(r1,r2,mdot=.02);net=ct.ReactorNet([r1,r2])
    assert r1.n_vars==r2.n_vars==12 and (net.rtol,net.atol)==(provenance['integration_rtol'],provenance['integration_atol'])
    J=np.asarray(net.jacobian);fd=np.asarray(net.finite_difference_jacobian)
    failure=None
    try:
        assert J[14:,:12]==approx(fd[14:,:12],rel=5e-3,abs=1e-10)
        assert J[:12,12:]==approx(np.zeros((12,12)),abs=1e-15)
        assert fd[:12,12:]==approx(np.zeros((12,12)),abs=1e-10)
    except AssertionError as error:failure={'kind':'assertion_failed','exception':str(error)}
    return {'original_method_passed':True,'original_method_sha256_lf':hashlib.sha256(ast.get_source_segment(text,method).encode()).hexdigest(),
        'jacobian':J.tolist(),'fd_jacobian':fd.tolist(),'state':net.get_state().tolist(),
        'species_names':gases[0].species_names,'molecular_weights':gases[0].molecular_weights.tolist(),
        'temperature':[r1.T,r2.T],'pressure':[r1.phase.P,r2.phase.P],'volume':[r1.volume,r2.volume],
        'energy_enabled':[r1.energy_enabled,r2.energy_enabled],'composition_strings':compositions,
        'rate_multipliers':[[g.multiplier(i) for i in range(g.n_reactions)] for g in gases],
        'transport_model':[g.transport_model for g in gases],'mdot':flow.mass_flow_rate,
        'rtol':net.rtol,'atol':net.atol,'solver_status':'not applicable: static Jacobian test; no integration',
        'failure':failure,'reference_assertions_passed':failure is None}
