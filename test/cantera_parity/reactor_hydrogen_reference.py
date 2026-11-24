"""Pinned single-reaction hydrogen Jacobian contracts."""
import ast
import hashlib
import textwrap

import numpy as np
from pytest import approx

METHOD = 'test_const_volume_hydrogen_single'


def reference_hydrogen(ct, provenance, mechanism, source, *, constant_pressure=False):
    text = (source / 'test/python/test_reactor.py').read_text()
    cls = next(n for n in ast.parse(text).body
               if isinstance(n, ast.ClassDef) and n.name == 'TestReactorJacobians')
    name = 'test_const_pressure_hydrogen_single' if constant_pressure else METHOD
    method = next(n for n in cls.body if isinstance(n, ast.FunctionDef) and n.name == name)
    namespace = {'ct': ct, 'np': np, 'approx': approx}
    ct.add_data_directory(str(source / 'data'))
    exec(textwrap.dedent(ast.get_source_segment(text, method)), namespace)
    namespace[name](None)  # Unmodified original method; it does not use self.

    gas = ct.Solution(str(mechanism), 'ohmech')
    gas.TPX = 1000, ct.one_atm, 'H2:1.0, H:2.0, H2O:2.0'
    gas.set_multiplier(0)
    gas.set_multiplier(1, 14)
    assert gas.reaction_equations()[14] == 'H + OH + M <=> H2O + M'
    reactor_class = ct.IdealGasConstPressureMoleReactor if constant_pressure else ct.IdealGasMoleReactor
    reactor = reactor_class(gas)
    reactor.volume = 2
    net = ct.ReactorNet([reactor])
    assert (net.rtol, net.atol) == (provenance['integration_rtol'], provenance['integration_atol'])
    net.step()
    state = net.get_state().copy()
    jac, fd = np.asarray(reactor.jacobian), np.asarray(reactor.finite_difference_jacobian)
    blocks = [('temperature_species', slice(0, 1), slice(2, 12), 1e-2, 1e-3),
              ('species_temperature', slice(2, 12), slice(0, 1), 1e-3, 1e-4),
              ('species_species', slice(2, 12), slice(2, 12), 1e-3, 1e-4)]
    if constant_pressure:
        blocks = [('complete_matrix', slice(0,11), slice(0,11), 1e-3, 1e-4)]
    size = 11 if constant_pressure else 12
    failure = None
    try:
        assert jac.shape == fd.shape == (size, size)
        assert net.time > 0 and net.solver_stats['steps'] == 1
        assert np.isfinite(jac).all() and np.isfinite(fd).all()
        for _, rows, cols, rel, absolute in blocks:
            assert jac[rows, cols] == approx(fd[rows, cols], rel=rel, abs=absolute)
    except AssertionError as error:
        failure = {'kind': 'assertion_failed', 'exception': str(error)}
    return {
        'original_method_passed': True,
        'original_method_sha256_lf': hashlib.sha256(ast.get_source_segment(text, method).encode()).hexdigest(),
        'reactor_cpp_sha256': hashlib.sha256((source / 'src/zeroD/Reactor.cpp').read_bytes()).hexdigest(),
        'state': state.tolist(), 'time': net.time, 'temperature': reactor.T,
        'pressure': reactor.phase.P, 'volume': reactor.volume, 'mass_fractions': reactor.phase.Y.tolist(),
        'initial_temperature': 1000., 'initial_pressure': ct.one_atm,
        'composition': 'H2:1.0, H:2.0, H2O:2.0', 'energy_enabled': reactor.energy_enabled,
        'rate_multipliers': [gas.multiplier(i) for i in range(gas.n_reactions)],
        'species_names': gas.species_names, 'molecular_weights': gas.molecular_weights.tolist(),
        'reaction_index_zero_based': 14, 'reaction_equation': gas.reaction_equations()[14],
        'transport_model': gas.transport_model, 'rtol': net.rtol, 'atol': net.atol,
        'jacobian': jac.tolist(), 'fd_jacobian': fd.tolist(),
        'fd_steps': (np.maximum(np.abs(state), 1000*net.atol)*np.sqrt(np.finfo(float).eps)).tolist(),
        'blocks': [{'block': name, 'entries': jac[rows, cols].size, 'rtol': rel, 'atol': absolute,
                    'maximum_error_over_bound': float(np.max(np.abs(jac[rows,cols]-fd[rows,cols]) /
                        np.maximum(absolute, rel*np.abs(fd[rows,cols]))))}
                   for name, rows, cols, rel, absolute in blocks],
        'solver_stats': net.solver_stats, 'retcode': 'not exposed by Python ReactorNet',
        'termination': 'caller stopped after one accepted step',
        'failure': failure, 'reference_assertions_passed': failure is None}
