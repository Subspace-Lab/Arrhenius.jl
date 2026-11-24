"""Independent evidence audit; usage: python FILE native.toml reference.json."""
import copy
import json
from pathlib import Path
import sys
import tomllib

import numpy as np
from pytest import approx


def check(native, reference):
    expected = reference['result']
    assert expected['reference_assertions_passed'] and expected['original_method_passed']
    assert native['species_names'] == expected['species_names']
    assert native['rate_multipliers'] == expected['rate_multipliers']
    assert native['rtol'] == expected['rtol'] == 1e-9
    assert native['atol'] == expected['atol'] == 1e-15
    assert native['volume'] == expected['volume'] == 2
    assert native['initial_temperature'] == expected['initial_temperature'] == 1000
    assert native['initial_pressure'] == expected['initial_pressure'] == 101325
    assert native['coordinates_1based'] == [11, *range(1, 11)]
    scales = np.array(native['scales'])
    assert scales.tolist() == [1., *expected['molecular_weights']]
    u = np.array(native['native_state'])
    coords = np.array(native['coordinates_1based']) - 1
    steps = np.maximum(np.abs(u[coords]/scales), 1000*native['atol'])*np.sqrt(np.finfo(float).eps)
    assert np.array_equal(steps, native['fd_steps'])
    assert len(native['perturbed_states']) == len(native['perturbed_rhs']) == 11
    for col, index in enumerate(coords):
        predicted = u.copy()
        predicted[index] += scales[col]*steps[col]
        assert predicted[index] != u[index]
        assert np.array_equal(predicted, native['perturbed_states'][col])
    rhs = np.array(native['perturbed_rhs'])
    f0 = np.array(native['baseline_rhs'])
    reconstructed = np.stack([(row[coords]-f0[coords])/(h*scales) for row, h in zip(rhs, steps)], axis=1)
    assert np.array_equal(reconstructed, native['mapped_fd'])
    jac, fd = np.array(native['mapped_jacobian']), reconstructed
    assert jac.shape == fd.shape == (11, 11)
    assert np.isfinite(jac).all() and np.isfinite(fd).all()
    assert native['time'] > 0 and native['solver_stats']['naccept'] == 1
    assert jac[0, 1:] == approx(fd[0, 1:], rel=1e-2, abs=1e-3)
    assert jac[1:, 0] == approx(fd[1:, 0], rel=1e-3, abs=1e-4)
    assert jac[1:, 1:] == approx(fd[1:, 1:], rel=1e-3, abs=1e-4)


if __name__ == '__main__':
    native = tomllib.loads(Path(sys.argv[1]).read_text())
    reference = json.loads(Path(sys.argv[2]).read_text())
    check(native, reference)
    rejected = []
    for label, row, col, rel, absolute in [
        ('temperature_species_over_limit', 0, 1, 1e-2, 1e-3),
        ('species_temperature_over_limit', 1, 0, 1e-3, 1e-4),
        ('species_species_over_limit', 1, 1, 1e-3, 1e-4),
    ]:
        changed = copy.deepcopy(native)
        expected = changed['mapped_fd'][row][col]
        changed['mapped_jacobian'][row][col] = expected + 2*max(absolute, rel*abs(expected))
        try:
            check(changed, reference)
        except AssertionError:
            rejected.append(label)
        else:
            raise AssertionError(f'Accepted deliberate corruption: {label}')
    for label in ('missing_column', 'omitted_molecular_weight_scaling', 'fabricated_perturbation'):
        changed = copy.deepcopy(native)
        if label == 'missing_column':
            changed['mapped_jacobian'] = [row[:-1] for row in changed['mapped_jacobian']]
        elif label == 'omitted_molecular_weight_scaling':
            changed['scales'] = [1.] * 11
        else:
            changed['perturbed_states'][5] = changed['native_state'].copy()
        try:
            check(changed, reference)
        except AssertionError:
            rejected.append(label)
        else:
            raise AssertionError(f'Accepted deliberate corruption: {label}')
    print(json.dumps({'status': 'passed', 'asserted_matrix_entries': 120,
                      'negative_checks_rejected': rejected}, indent=2))
