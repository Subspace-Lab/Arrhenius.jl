@testset "Cantera parity: nonideal constant-volume ignition energy (Y,T)" begin
    gas, provenance, _ = thermal_fixture()
    path = joinpath(@__DIR__, "fixtures", "cantera-726522be", "h2o2.yaml")
    model = RedlichKwongThermo(path; phase="ohmech-RK", molecular_weights=gas.MW)
    T0 = 1050.0
    volume = 1.0
    reactor = RedlichKwongReactor(gas, model; temperature=T0, pressure=20one_atm,
        mole_fractions=Dict("H2"=>2.0, "O2"=>1.0, "N2"=>3.76))
    initial = reactor_properties(reactor)
    mass = initial.density * volume
    U0 = mass * initial.internal_energy
    # The pinned Cantera state provides an independent check on phase selection.
    @test thermal_approx(U0, 3304270.8661327716, provenance)
    @test thermal_approx(initial.pressure, 20one_atm, provenance)
    problem = reactor_problem(reactor, (0.0, 1.0))
    f = ODEFunction(problem.f; jac=problem.jac, tgrad=problem.tgrad)
    integrator = init(ODEProblem(f, problem.u0, problem.tspan, problem.p), QNDF();
        reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"],
        save_everystep=false)
    rows = [(0.0, T0, U0)]
    bound = max(1e-12, 1e-8 * abs(U0))
    while integrator.t < 0.1
        previous = integrator.t
        step!(integrator)
        integrator.t > previous || error("RK ignition failed to advance: $(integrator.sol.retcode)")
        SciMLBase.check_error(integrator) == SciMLBase.ReturnCode.Success ||
            error("RK ignition step failed at $(integrator.t) s")
        state = reactor_properties(reactor, integrator.u)
        energy = mass * state.internal_energy
        @test abs(energy - U0) <= bound
        push!(rows, (integrator.t, state.temperature, energy))
    end
    @test integrator.t >= 0.1
    @test length(rows) == integrator.stats.naccept + 1
    @test last(rows)[2] - T0 > 500
    output = get(ENV, "CANTERA_PARITY_RESULTS", nothing)
    if output !== nothing
        mkpath(output)
        file = joinpath(output, "rk_cv_ignition.native.csv")
        isfile(file) && error("Choose a fresh results directory")
        open(file, "w") do io
            println(io, "time_s,temperature_K,total_internal_energy_J")
            for row in rows
                println(io, join(row, ','))
            end
        end
    end
    @info "RK constant-volume ignition" time=integrator.t temperature=last(rows)[2] max_error_J=maximum(row->abs(row[3]-U0),rows) bound_J=bound stats=integrator.stats
end
