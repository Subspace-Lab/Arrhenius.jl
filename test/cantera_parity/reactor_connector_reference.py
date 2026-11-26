"""Pinned heat-only wall cross-temperature Jacobian contract."""
import numpy as np
from reactor_reference import check_close


def reference_connector_heat(ct, provenance, mechanism):
    gases = []
    for temperature, composition in ((1200, "H2:2,O2:1,AR:8"),
                                     (800, "H2:1,O2:1,AR:8")):
        gas = ct.Solution(str(mechanism), "ohmech")
        gas.TPX = temperature, ct.one_atm, composition
        gas.set_multiplier(0.0)
        gases.append(gas)
    r1, r2 = [ct.IdealGasMoleReactor(gas) for gas in gases]
    wall = ct.Wall(r1, r2, A=2.0, U=50.0, K=0.0)
    net = ct.ReactorNet([r1, r2])
    assert (net.rtol, net.atol) == (provenance["integration_rtol"], provenance["integration_atol"])
    n1 = r1.n_vars
    J = net.jacobian
    J_fd = net.finite_difference_jacobian
    actual = [float(J[0,n1]), float(J[n1,0])]
    independent = [float(J_fd[0,n1]), float(J_fd[n1,0])]
    mass = [float(r.mass) for r in (r1,r2)]
    cv = [float(g.cv_mass) for g in gases]
    expected = [wall.heat_transfer_coeff*wall.area/(m*c) for m,c in zip(mass,cv)]
    failure = None
    try:
        check_close("J[T2,T1] vs FD",actual[1],independent[1],provenance,rtol=1e-3,atol=1e-10)
        check_close("J[T1,T2] vs FD",actual[0],independent[0],provenance,rtol=1e-3,atol=1e-10)
        for i in range(2):
            check_close(f"J cross entry {i} vs UA/(m cv)",actual[i],expected[i],provenance,rtol=1e-6,atol=1e-12)
    except AssertionError as error:
        failure = {"kind":"assertion_failed","exception":str(error)}
    return {"species_names":gases[0].species_names,"state":net.get_state().tolist(),
            "temperature_indices_0based":[0,n1],"mass":mass,"cv":cv,
            "jacobian":np.asarray(J).tolist(),"fd_jacobian":np.asarray(J_fd).tolist(),
            "actual_cross_entries":actual,"fd_cross_entries":independent,
            "analytic_cross_entries":expected,"rtol":net.rtol,"atol":net.atol,
            "volume":[r1.volume,r2.volume],"temperature":[r1.T,r2.T],
            "pressure":[r1.phase.P,r2.phase.P],"mass_fractions":[r1.Y.tolist(),r2.Y.tolist()],
            "area":wall.area,"U":wall.heat_transfer_coeff,"K":wall.expansion_rate_coeff,
            "transport_model":[g.transport_model for g in gases],
            "rate_multipliers":[[r.phase.multiplier(i) for i in range(r.phase.n_reactions)] for r in (r1,r2)],
            "solver_status":"not applicable: static Jacobian evaluation; no integration",
            "failure":failure,"reference_assertions_passed":failure is None}


def reference_connector_mfc_energy(ct, provenance, mechanism):
    compositions = ["H2:2,H:0.01,O:0.005,O2:1,OH:0.01,H2O:0.05,HO2:0.001,H2O2:0.001,AR:8,N2:0.1",
                    "H2:1,H:0.005,O:0.002,O2:0.5,OH:0.005,H2O:0.1,HO2:0.001,H2O2:0.001,AR:8,N2:0.1"]
    gases = []
    for T,P,X in zip((1200,900),(2*ct.one_atm,ct.one_atm),compositions):
        gas = ct.Solution(str(mechanism),"ohmech")
        gas.TPX = T,P,X
        gas.set_multiplier(0.0)
        gases.append(gas)
    r1,r2 = [ct.IdealGasMoleReactor(g) for g in gases]
    flow = ct.MassFlowController(r1,r2,mdot=0.02)
    net = ct.ReactorNet([r1,r2])
    assert (net.rtol,net.atol)==(provenance["integration_rtol"],provenance["integration_atol"])
    n1 = r1.n_vars
    J = np.asarray(net.jacobian)
    J_fd = np.asarray(net.finite_difference_jacobian)
    actual,independent = float(J[n1,0]),float(J_fd[n1,0])
    species,fd_species = J[n1+2:,2:n1],J_fd[n1+2:,2:n1]
    failure = None
    try:
        assert abs(actual)>1e-20
        check_close("MFC T-T",actual,independent,provenance,rtol=1e-2,atol=1e-10)
        for index in np.ndindex(species.shape):
            check_close(f"MFC species {index}",float(species[index]),float(fd_species[index]),provenance,rtol=1e-2,atol=1e-10)
    except AssertionError as error:
        failure = {"kind":"assertion_failed","exception":str(error)}
    return {"species_names":gases[0].species_names,"molecular_weights":gases[0].molecular_weights.tolist(),
            "state":net.get_state().tolist(),"jacobian":J.tolist(),"fd_jacobian":J_fd.tolist(),
            "actual_temperature_entry":actual,"fd_temperature_entry":independent,
            "actual_species_block":species.tolist(),"fd_species_block":fd_species.tolist(),
            "temperature_indices_0based":[0,n1],"rtol":net.rtol,"atol":net.atol,
            "composition_strings":compositions,"temperature":[r1.T,r2.T],
            "pressure":[r1.phase.P,r2.phase.P],"volume":[r1.volume,r2.volume],"mdot":flow.mass_flow_rate,
            "energy_enabled":[r1.energy_enabled,r2.energy_enabled],"chemistry_enabled":[r1.chemistry_enabled,r2.chemistry_enabled],
            "transport_model":[g.transport_model for g in gases],
            "rate_multipliers":[[r.phase.multiplier(i) for i in range(r.phase.n_reactions)] for r in (r1,r2)],
            "solver_status":"not applicable: static Jacobian evaluation; no integration",
            "failure":failure,"reference_assertions_passed":failure is None}
