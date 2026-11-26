"""Audit saved CP mole-coordinate mapping and every original matrix entry."""
import copy
import json
from pathlib import Path
import sys
import tomllib

import numpy as np
from pytest import approx


def check(record, reference):
    ref = reference['result']
    assert ref['original_method_passed'] and ref['reference_assertions_passed']
    assert record['constraint'] == 'constant_pressure' and record['energy'] == 'adiabatic'
    assert ref['energy_enabled']
    assert record['species_names'] == ref['species_names']
    assert record['rate_multipliers'] == ref['rate_multipliers']
    assert record['rtol'] == ref['rtol'] == 1e-9
    assert record['atol'] == ref['atol'] == 1e-15
    assert record['assertion_rtol'] == 1e-3 and record['assertion_atol'] == 1e-4
    assert record['initial_volume'] == 2 and record['initial_temperature'] == ref['initial_temperature'] == 1000
    assert record['initial_pressure'] == ref['initial_pressure'] == 101325
    assert record['composition'] == {'H2':1., 'H':2., 'H2O':2.}
    W = np.array(record['molecular_weights'])
    assert W.tolist() == ref['molecular_weights']
    q = np.array(record['physical_state']); n = q[1:]; M = W @ n; Y = W*n/M
    u = np.r_[Y, q[0]]
    assert u == approx(record['mapped_native_state'], rel=1e-14, abs=1e-30)
    raw = np.array(record['advanced_native_state'])
    assert q == approx(np.r_[raw[-1], record['initial_mass']*raw[:-1]/W], rel=1e-14, abs=1e-30)
    assert M == approx(record['state_mass'], rel=1e-14)
    J = np.array(record['native_jacobian']); f = np.array(record['native_rhs'])
    mapped = np.array(record['mapped_jacobian'], dtype=float)
    assert J.shape == mapped.shape == (11,11) and np.isfinite(mapped).all()
    expected = np.empty((11,11)); expected[0,0] = J[10,10]
    expected[1:,0] = M/W*J[:10,10]
    for j in range(10):
        dY = -Y*W[j]/M; dY[j] += W[j]/M
        assert dY == approx(np.array(record['mass_fraction_derivatives'])[:,j], rel=1e-12, abs=1e-20)
        expected[0,j+1] = sum(J[10,k]*dY[k] for k in range(10))
        for k in range(10):
            expected[k+1,j+1] = (W[j]*f[k] + M*sum(J[k,l]*dY[l] for l in range(10)))/W[k]
    # Algebraic reconstruction roundoff only; not an upstream physics criterion.
    assert mapped == approx(expected, rel=1e-12, abs=1e-20)
    steps = np.maximum(abs(q),1000*record['atol'])*np.sqrt(np.finfo(float).eps)
    assert np.array_equal(steps,record['fd_steps'])
    baseline = np.r_[f[-1],M*f[:-1]/W]
    assert baseline == approx(record['baseline_physical_rhs'], rel=1e-14, abs=1e-30)
    assert len(record['probes']) == 11
    oracle = np.empty((11,11))
    # Ideal-gas volume-per-(T*total_moles), from the independent reference state.
    ref_q = np.array(ref['state']); volume_scale = ref['volume']/(ref_q[0]*sum(ref_q[1:]))
    # Closed-reactor total mass is conserved; this also checks the initial 2 m3 scale.
    assert record['initial_mass'] == approx(W @ ref_q[1:],rel=1e-12,abs=1e-15)
    for j, probe in enumerate(record['probes']):
        z = q.copy(); z[j] += steps[j]
        assert z[j] != q[j] and np.array_equal(z,probe['physical_state'])
        mz = W @ z[1:]; uz = np.r_[W*z[1:]/mz,z[0]]
        assert uz == approx(probe['native_state'], rel=1e-14, abs=1e-30)
        assert mz == approx(probe['mass'], rel=1e-14)
        assert probe['pressure'] == 101325
        assert probe['volume'] == approx(volume_scale*z[0]*sum(z[1:]),rel=1e-12,abs=0)
        fz = np.array(probe['native_rhs']); gz = np.r_[fz[-1],mz*fz[:-1]/W]
        assert gz == approx(probe['physical_rhs'],rel=1e-14,abs=1e-30)
        oracle[:,j] = (np.array(probe['physical_rhs'])-np.array(record['baseline_physical_rhs']))/steps[j]
    assert np.array_equal(oracle,record['mapped_fd'])
    assert mapped == approx(oracle,rel=1e-3,abs=1e-4) # All121 original entries.
    assert record['time'] > 0 and record['solver_stats']['naccept'] == 1


if __name__ == '__main__':
    record=tomllib.loads(Path(sys.argv[1]).read_text())
    reference=json.loads(Path(sys.argv[2]).read_text())
    check(record,reference)
    rejected=[]
    for label in ('tt_over_limit','species_over_limit','missing_temperature_entry',
                  'omitted_mass_term','fixed_mass_scaling','fabricated_probe','altered_fd_step'):
        changed=copy.deepcopy(record)
        J=np.array(changed['mapped_jacobian']); W=np.array(changed['molecular_weights'])
        if label in ('tt_over_limit','species_over_limit'):
            k=0 if label=='tt_over_limit' else 1
            value=changed['mapped_fd'][k][k];J[k,k]=value+2*max(1e-4,1e-3*abs(value))
            assert not (J == approx(np.array(changed['mapped_fd']),rel=1e-3,abs=1e-4))
        elif label=='missing_temperature_entry':
            J[0,0]=np.nan
        elif label=='omitted_mass_term':
            J[1:,1:]-=np.outer(np.array(changed['native_rhs'])[:-1]/W,W)
        elif label=='fixed_mass_scaling':
            order=[10,*range(10)];scales=np.r_[1.,W/changed['state_mass']]
            raw=np.array(changed['native_jacobian'])[np.ix_(order,order)]
            J=raw*scales[None,:]/scales[:,None]
        elif label=='fabricated_probe':
            changed['probes'][1]['physical_state']=changed['physical_state'].copy()
        else:
            changed['fd_steps'][1]*=2
        changed['mapped_jacobian']=J.tolist()
        try:check(changed,reference)
        except AssertionError:rejected.append(label)
        else:raise AssertionError(f'Accepted corrupted evidence: {label}')
    print(json.dumps({'status':'passed','matrix_entries':121,'negative_checks_rejected':rejected,
        'scope':'Full upstream predicate plus independent mapping/probe reconstruction; algebraic roundoff checks do not replace upstream tolerances.'},indent=2))
