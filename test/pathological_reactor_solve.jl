using Arrhenius, LinearAlgebra, SciMLBase, OrdinaryDiffEqBDF
function _pathomech_dense_bdf(problem; kwargs...)
    f = SciMLBase.ODEFunction(problem.f; jac=problem.jac, tgrad=problem.tgrad)
    ode = SciMLBase.ODEProblem(f, problem.u0, problem.tspan, problem.p)
    SciMLBase.solve(ode, OrdinaryDiffEqBDF.QNDF(); kwargs...)
end

const PATHOMECH_GROUPS = Dict(
    "small" => ("clean", "nasa7_small"),
    "large" => ("nasa7_large", "extreme_Ea", "collision_limit"),
)
length(ARGS) == 1 && haskey(PATHOMECH_GROUPS, ARGS[1]) ||
    error("pass one group: small or large")
fixture_dir = joinpath(@__DIR__, "data", "pathological_mechanisms")
mixture = Dict("H2" => 2.0, "O2" => 1.0, "AR" => 4.0)
for name in PATHOMECH_GROUPS[ARGS[1]]
    gas = CreateSolution(joinpath(fixture_dir, name * ".yaml"))
    reactor = IdealGasReactor(gas; temperature=1001.0, pressure=3one_atm,
        mole_fractions=mixture, constraint=:constant_pressure, energy=:adiabatic)
    initial = reactor_properties(reactor)
    try
        solution = solve_reactor(reactor, (0.0, 0.02); integrator=_pathomech_dense_bdf,
            reltol=1e-8, abstol=1e-14)
        states = [reactor_properties(reactor, u) for u in solution.u]
        max_element_drift = maximum(norm(p.elemental_inventory - initial.elemental_inventory, Inf)
            for p in states)
        max_sumY_error = maximum(abs(p.mass_fraction_sum - 1) for p in states)
        ignition_idx = findfirst(p -> p.temperature >= 1600, states)
        ignition_time = isnothing(ignition_idx) ? nothing : solution.t[ignition_idx]
        @info "pathological zero-D report" fixture=name retcode=solution.retcode final_time=solution.t[end] final_temperature_K=states[end].temperature max_temperature_K=maximum(p.temperature for p in states) ignited=!isnothing(ignition_time) ignition_time_s=ignition_time accepted_steps=solution.destats.naccept rejected_steps=solution.destats.nreject rhs_evals=solution.destats.nf jacobian_evals=solution.destats.njacs max_sumY_error max_element_drift
    catch err
        @info "pathological zero-D report" fixture=name outcome="failed" message=sprint(showerror, err)
    end
end
