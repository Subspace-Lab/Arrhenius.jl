# Zero-dimensional reactors

IdealGasReactor defines a homogeneous closed reactor at constant pressure or volume, with adiabatic or isothermal energy treatment. It provides the state equations and Jacobian independently of any ODE package. Pass the problem to an integrator through solve_reactor.

## Constant-pressure ignition

From the repository root, activate example/reactors and run this example. The optional environment includes SciMLBase and OrdinaryDiffEqBDF; the helper selects QNDF and connects the Arrhenius Jacobian to the integrator.

~~~julia
using Arrhenius
include("example/reactors/ode_solver.jl")

gas = CreateSolution("mechanism/h2o2.yaml")
reactor = IdealGasReactor(gas; temperature=1001.0, pressure=one_atm,
    mole_fractions=Dict("H2" => 2, "O2" => 1, "AR" => 4))
solution = solve_reactor(reactor, (0.0, 0.001); integrator=native_bdf,
    reltol=1e-8, abstol=1e-14)
final = reactor_properties(reactor, solution.u[end])
println((temperature_K=final.temperature, pressure_Pa=final.pressure))
~~~

reactor_properties reports thermodynamic state and conserved quantities so callers can inspect integration drift. Arrhenius.jl does not select a mandatory integrator. See the [reactor examples](examples.md#reactors).

## Closed constant-volume internal-energy state

`InternalEnergyReactor` is an opt-in closed, rigid, adiabatic ideal-gas model.
Its state is `[Y; e]`, where `e` is specific internal energy (J/kg), including
formation energy, and can be negative. The existing `IdealGasReactor` keeps
its temperature state and defaults. Flows, walls, surfaces, constant pressure,
and nonideal thermodynamics are outside the new type's scope.

~~~julia
using Arrhenius
include("example/reactors/ode_solver.jl")
gas = CreateSolution("test/cantera_parity/fixtures/cantera-726522be/h2o2.yaml";
                     phase="ohmech")
r = InternalEnergyReactor(gas; temperature=1100.0, pressure=10one_atm,
    mole_fractions=Dict("H2"=>1.0, "O2"=>0.5, "AR"=>8.0))
sol = solve_reactor(r, (0.0,1.0); integrator=native_bdf,
                    reltol=1e-9, abstol=1e-15)
p = reactor_properties(r, sol.u[end])
~~~

Temperature is recovered from the fixed-composition energy equation before
calling the existing chemistry RHS. The species Jacobian is transformed from
temperature to energy coordinates; the last derivative and Jacobian row are
zero. No mass-fraction normalization or output projection is applied. As with
other mutable RHS workspaces, create independent problems for concurrent solves.

`p.internal_energy` is independently reconstructed from temperature and
composition; `p.integrated_internal_energy` is the stored state coordinate.
Compare them to check inversion error. Zero energy derivative does not promise
bitwise conservation under floating-point BDF arithmetic. For total energy in
joules, multiply specific energy by the initial mass (initial density times
volume). The reactor's equation uses specific quantities and does not introduce
a volume API.

The inversion follows Cantera `726522be` `Reactor.cpp:92–131`'s expansion factor
1.2, 48-bit temperature-bracket target and 100-step bound. A safeguarded
Newton/bisection implementation replaces Boost's root finder; its convergence
and cost are measured separately in ForgeKinetic #90. It requires positive
finite heat capacity and throws on failed bracketing or convergence. The
optional adapter retains QNDF defaults and the existing `-1e-13` trial mass
fraction floor; it tests recovered temperature positivity rather than energy
positivity. No existing solver branch is changed.

Run the existing #59 initialization physical-state regression separately:

~~~sh
julia --project=example/reactors test/cantera_parity/internal_energy_initialization.jl
~~~

It compares mass, volume, reconstructed total energy and all species fractions
after one second to pinned Cantera UV equilibrium and native UV equilibrium,
using the original per-component absolute `1e-7` bound. It does not establish
upstream object-lifecycle API equivalence or full-trajectory accuracy. The
existing 44-scenario optional suite and coverage inventory are unchanged.

Configuration ownership: construction copies the source reactor's mass-fraction
and reaction-multiplier arrays without renormalizing or recomputing density.
Later mutation of those source arrays does not affect the new reactor. Mechanism
data remain shared and read-only. Direct mutation through `r.thermal` is unsupported;
construct a new reactor to change its configuration.

For this model, `native_bdf` accepts `linear_solver=:auto` and `:dense`; both use
the supplied dense Jacobian and ordinary QNDF. Only known physical-domain and
temperature-inversion failures are classified as domain rejections; unrelated
programming exceptions propagate with their original message.

In the fixed #59 benchmark, warm solve samples increased from about 9 ms for the
temperature model to 19–23 ms for the energy model (median ratio 2.12), primarily
paying for temperature recovery. These single-host samples are not a universal
performance guarantee. Stored energy drifted 254 Float64 ULPs (2.91e-8 J total);
independently reconstructed energy drifted 2.94e-8 J, within the original 1e-7 J
physical bound. This is bounded physical error, not exact floating conservation.
The custom root inverse does not implement Cantera's separate full-temperature-
range fallback; failed bracketing/convergence throws.

ForgeKinetic's dedicated internal-energy CI job rebuilds the pinned public patch
chain and runs the original physical-state regression plus ownership/adapter
guards on every PR. The ODE dependencies remain in the separate locked reactor
environment; the default package test entry retains the lightweight API guards.
