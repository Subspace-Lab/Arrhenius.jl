# Existing #59 physical case; independent optional regression, not a new
# upstream coverage/lifecycle claim. Use --project=example/reactors.
using Arrhenius, SciMLBase, OrdinaryDiffEqBDF, LinearAlgebra, SHA, TOML, Test
BLAS.set_num_threads(1)
include(joinpath(pkgdir(Arrhenius),"example/reactors/ode_solver.jl"))

function initialization_energy_result(; temperature_control=false, linear_solver=:auto)
    folder = joinpath(@__DIR__,"fixtures/cantera-726522be")
    ref = TOML.parsefile(joinpath(folder,"initialization_uv.toml"))
    mechanism = joinpath(folder,"h2o2.yaml")
    @assert bytes2hex(sha256(replace(read(mechanism,String),"\r\n"=>"\n"))) == ref["mechanism_sha256_lf"]
    @assert Base.pkgversion(SciMLBase) == v"2.155.2"
    @assert Base.pkgversion(OrdinaryDiffEqBDF) == v"1.26.0"
    gas = CreateSolution(mechanism;phase=ref["phase"])
    @assert gas.species_names == ref["component_names"][4:end]
    thermal = IdealGasReactor(gas;temperature=ref["initial_temperature"],
        pressure=ref["initial_pressure_atm"]*one_atm,
        mole_fractions=mole_fractions(gas,ref["initial_mole_fractions"]),constraint=:constant_volume)
    reactor = temperature_control ? thermal : InternalEnergyReactor(thermal)
    initial = reactor_properties(thermal)
    start = time_ns()
    solution = solve_reactor(reactor,(0.0,ref["final_time"]);integrator=native_bdf,linear_solver,
        reltol=ref["integration_rtol"],abstol=ref["integration_atol"])
    elapsed = (time_ns()-start)/1e9
    # Properties independently reconstruct energy from T,Y; stored e is separate.
    properties = [reactor_properties(reactor,u) for u in solution.u]
    final = last(properties)
    mass = initial.density*ref["volume"]
    mapped = vcat(mass,ref["volume"],mass*final.internal_energy,final.mass_fractions)
    equilibrium = equilibrate(gas;T=ref["initial_temperature"],
        P=ref["initial_pressure_atm"]*one_atm,X=ref["initial_mole_fractions"],mode=:UV)
    eq_thermal = IdealGasReactor(gas;temperature=equilibrium.T,pressure=equilibrium.P,
        mass_fractions=equilibrium.Y,constraint=:constant_volume)
    eq_props = reactor_properties(eq_thermal)
    eq_mass = eq_props.density*ref["volume"]
    native_expected = vcat(eq_mass,ref["volume"],eq_mass*eq_props.internal_energy,equilibrium.Y)
    stats = Dict(string(k)=>getproperty(solution.stats,k) for k in
        (:nf,:njacs,:nw,:nsolve,:nnonliniter,:nnonlinconvfail,:naccept,:nreject))
    report = Dict("retcode"=>string(solution.retcode),"time"=>last(solution.t),
        "temperature_control"=>temperature_control,"elapsed_seconds_including_JIT"=>elapsed,
        "actual"=>mapped,"expected_cantera_uv"=>ref["expected_uv_state"],
        "expected_native_uv"=>native_expected,
        "errors_cantera_uv"=>abs.(mapped-ref["expected_uv_state"]),
        "errors_native_uv"=>abs.(mapped-native_expected),"stats"=>stats,
        "initial_U_J"=>mass*initial.internal_energy,
        "stored_energy_bit_identical"=>all(u->u[end]==first(solution.u)[end],solution.u),
        "max_stored_energy_drift_J"=>temperature_control ? NaN : maximum(abs(mass*(u[end]-first(solution.u)[end])) for u in solution.u),
        "final_T_K"=>final.temperature,"final_P_Pa"=>final.pressure,
        "max_U_drift_J"=>maximum(abs(mass*(p.internal_energy-initial.internal_energy)) for p in properties),
        "max_mass_fraction_sum_drift"=>maximum(abs(p.mass_fraction_sum-initial.mass_fraction_sum) for p in properties),
        "max_element_inventory_drift_kmol_per_kg"=>maximum(norm(p.elemental_inventory-initial.elemental_inventory,Inf) for p in properties),
        "minimum_Y"=>minimum(minimum(p.mass_fractions) for p in properties),
        "times"=>solution.t,"states"=>solution.u,
        "reconstructed_T_K"=>[p.temperature for p in properties],
        "reconstructed_U_J"=>[mass*p.internal_energy for p in properties],
        "state_absolute_tolerance"=>ref["state_absolute_tolerance"],
        "source_case"=>ref["upstream_test"],"source_root"=>pkgdir(Arrhenius),
        "julia_version"=>string(VERSION),"threads"=>Threads.nthreads(),
        "blas_threads"=>BLAS.get_num_threads(),"grid_size"=>"not applicable")
    return report,solution,ref
end

function check_internal_energy_initialization(report,solution,ref)
    @testset "Internal energy: original initialization state bound" begin
        @test SciMLBase.successful_retcode(solution)
        @test report["time"] == ref["final_time"]
        @test all(u->all(isfinite,u),solution.u)
        for error in report["errors_cantera_uv"]
            @test error <= ref["state_absolute_tolerance"]
        end
        for error in report["errors_native_uv"]
            @test error <= ref["state_absolute_tolerance"]
        end
        @test report["max_stored_energy_drift_J"] <= ref["state_absolute_tolerance"]
        @test report["max_U_drift_J"] <= ref["state_absolute_tolerance"]
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    report,solution,ref = initialization_energy_result()
    if !isempty(ARGS)
        ispath(only(ARGS)) && error("Preserve existing evidence; select a new result file")
        open(only(ARGS),"w") do io; TOML.print(io,report); end
    end
    println("INITIALIZATION_ENERGY ",report["errors_cantera_uv"]," ",report["stats"])
    check_internal_energy_initialization(report,solution,ref)
end