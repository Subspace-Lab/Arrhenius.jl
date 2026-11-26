@testset "Cantera parity: TestReactorJacobians.test_const_volume_hydrogen_single" begin
    gas, provenance, digest = thermal_fixture()
    multipliers = zeros(gas.n_reactions)
    multipliers[15] = 1.0 # Cantera zero-based reaction 14: H + OH + M <=> H2O + M
    vessel = WellStirredReactor(gas; temperature=1000.0, pressure=one_atm,
        mole_fractions=Dict("H2"=>1.0, "H"=>2.0, "H2O"=>2.0), volume=2.0,
        rate_multipliers=multipliers)
    model = ReactorNetwork((vessel=vessel,))
    rtol, atol = provenance["integration_rtol"], provenance["integration_atol"]
    integrator = control_integrator(model, (0.0, 1.0); reltol=rtol, abstol=atol)
    SciMLBase.step!(integrator) # Exactly one accepted step, not advance to a fixed time.
    u = copy(integrator.u)
    length(u) == 11 && model.offsets == [1] && gas.n_species == 10 ||
        error("Single-reactor species-mass / temperature layout changed")
    @test integrator.t > 0.0
    @test integrator.sol.stats.naccept == 1
    @test all(isfinite, u)
    rhs = network_rhs(model)
    J = zeros(11, 11)
    network_jacobian!(J, u, rhs, integrator.t)
    # Upstream [T,V,n...] -> native [m...,T]. Constant V is not an asserted
    # coordinate in this upstream test; every entry in its three blocks remains.
    coordinates = vcat(11, collect(1:10))
    scales = vcat(1.0, gas.MW)
    mapped = [J[i,j]*scales[b]/scales[a]
        for (a,i) in enumerate(coordinates), (b,j) in enumerate(coordinates)]
    independent = network_rhs(model)
    f0 = similar(u)
    independent(f0, u, nothing, integrator.t)
    fd = zeros(11, 11)
    steps = zeros(11)
    perturbed_states, perturbed_rhs = Vector{Float64}[], Vector{Float64}[]
    for (col,j) in enumerate(coordinates)
        # Reactor::finiteDifferenceJacobian (not ReactorNet's centered rule).
        h = max(abs(u[j]/scales[col]), 1000*atol)*sqrt(eps(Float64))
        steps[col] = h
        z = copy(u)
        z[j] += scales[col]*h
        f = similar(u)
        independent(f, z, nothing, integrator.t)
        fd[:,col] = (f[coordinates] .- f0[coordinates]) ./ (h .* scales)
        push!(perturbed_states, z)
        push!(perturbed_rhs, f)
    end
    @test u == integrator.u
    @test all(isfinite, mapped) && all(isfinite, fd)
    blocks = (("temperature_species", 1:1, 2:11, 1e-2, 1e-3),
              ("species_temperature", 2:11, 1:1, 1e-3, 1e-4),
              ("species_species", 2:11, 2:11, 1e-3, 1e-4))
    reports = Dict{String,Any}[]
    for (name, rows, cols, rel, absolute) in blocks
        err = abs.(mapped[rows,cols]-fd[rows,cols])
        push!(reports, Dict("block"=>name, "entries"=>length(rows)*length(cols),
            "rtol"=>rel, "atol"=>absolute,
            "maximum_error_over_bound"=>maximum(err ./ max.(absolute,rel.*abs.(fd[rows,cols])))))
    end
    state = network_diagnostics(rhs, u, integrator.t).nodes.vessel
    record = Dict("time"=>integrator.t, "native_state"=>u,
        "mapped_state"=>u[coordinates]./scales, "coordinates_1based"=>coordinates,
        "scales"=>scales, "species_names"=>gas.species_names,
        "mechanism_sha256_lf"=>digest, "rtol"=>rtol, "atol"=>atol,
        "rate_multipliers"=>multipliers, "reaction_index_zero_based"=>14,
        "initial_temperature"=>1000.0, "initial_pressure"=>one_atm, "volume"=>2.0,
        "composition"=>Dict("H2"=>1.0,"H"=>2.0,"H2O"=>2.0),
        "energy"=>"adiabatic", "chemistry"=>true,
        "temperature"=>state.temperature, "pressure"=>state.pressure,
        "mass_fractions"=>state.mass_fractions,
        "mapped_jacobian"=>[collect(r) for r in eachrow(mapped)],
        "mapped_fd"=>[collect(r) for r in eachrow(fd)], "fd_steps"=>steps,
        "baseline_rhs"=>f0, "perturbed_states"=>perturbed_states,
        "perturbed_rhs"=>perturbed_rhs, "blocks"=>reports,
        "retcode"=>string(integrator.sol.retcode),
        "termination"=>"caller stopped after one accepted step; nominal endpoint not requested",
        "solver_stats"=>Dict(string(k)=>getproperty(integrator.sol.stats,k)
            for k in propertynames(integrator.sol.stats) if getproperty(integrator.sol.stats,k) isa Number))
    output = get(ENV,"CANTERA_PARITY_RESULTS",nothing)
    if output !== nothing
        mkpath(output)
        path = joinpath(output,"hydrogen_single_jacobian.native.toml")
        isfile(path) && error("Choose a fresh results directory")
        open(io->TOML.print(io,record),path,"w")
    end
    for (_, rows, cols, rel, absolute) in blocks, col in cols, row in rows
        @test thermal_approx(mapped[row,col], fd[row,col], provenance; rtol=rel, atol=absolute)
    end
end
