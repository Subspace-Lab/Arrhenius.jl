@testset "Cantera parity: TestConnectorJacobians.test_wall_heat_transfer_cross_reactor_temperature" begin
    gas, provenance, digest = thermal_fixture()
    left = WellStirredReactor(gas; temperature=1200.0, pressure=one_atm,
        mole_fractions=Dict("H2"=>2.0,"O2"=>1.0,"AR"=>8.0), volume=1.0,
        energy=:adiabatic, chemistry=true, rate_multipliers=zeros(gas.n_reactions))
    right = WellStirredReactor(gas; temperature=800.0, pressure=one_atm,
        mole_fractions=Dict("H2"=>1.0,"O2"=>1.0,"AR"=>8.0), volume=1.0,
        energy=:adiabatic, chemistry=true, rate_multipliers=zeros(gas.n_reactions))
    wall = HeatTransferWall(:left,:right; area=2.0,U=50.0)
    model = ReactorNetwork((left=left,right=right); walls=(wall,))
    u = network_state(model)
    check_connector_layout(model,u,gas.species_names)
    before = copy(u)
    temperature_indices = [offset + gas.n_species for offset in model.offsets]
    J = zeros(length(u),length(u))
    network_jacobian!(J,u,network_rhs(model))

    # Independent oracle: pinned ReactorNet.cpp:481-508, only T columns.
    # Holding masses fixed is equivalent to holding moles fixed for these
    # partial derivatives. The native volume is fixed by the vessel model.
    fd_rhs = network_rhs(model)
    steps = provenance["integration_atol"] .+ abs.(u[temperature_indices]) .* provenance["integration_rtol"]
    plus, minus = Vector{Float64}[], Vector{Float64}[]
    for (j,h) in zip(temperature_indices,steps)
        perturbed = copy(before)
        perturbed[j] += h
        fplus = similar(u)
        fd_rhs(fplus,perturbed,nothing,0.0)
        perturbed[j] = before[j]-h
        fminus = similar(u)
        fd_rhs(fminus,perturbed,nothing,0.0)
        push!(plus,fplus)
        push!(minus,fminus)
    end
    fd = hcat([(a-b)/(2h) for (a,b,h) in zip(plus,minus,steps)]...)
    props = [reactor_properties(node.initial) for node in (left,right)]
    masses = [p.density*node.volume for (p,node) in zip(props,(left,right))]
    cv = [p.cv for p in props]
    i1,i2 = temperature_indices
    actual = [J[i1,i2],J[i2,i1]]
    independent = [fd[i1,2],fd[i2,1]]
    expected = wall.U*wall.area ./ (masses .* cv)
    record = Dict("species_names"=>gas.species_names,"state"=>before,
        "temperature_indices_1based"=>temperature_indices,"mass"=>masses,"cv"=>cv,
        "jacobian"=>[collect(row) for row in eachrow(J)],
        "fd_temperature_columns"=>[collect(row) for row in eachrow(fd)],
        "fd_steps"=>steps,"fd_plus"=>plus,"fd_minus"=>minus,
        "actual_cross_entries"=>actual,"fd_cross_entries"=>independent,
        "analytic_cross_entries"=>expected,"mechanism_sha256_lf"=>digest,
        "rtol"=>provenance["integration_rtol"],"atol"=>provenance["integration_atol"],
        "volume"=>[left.volume,right.volume],"area"=>wall.area,"U"=>wall.U,
        "solver_status"=>"not applicable: static Jacobian evaluation; no integration")
    output = get(ENV,"CANTERA_PARITY_RESULTS",nothing)
    if output !== nothing
        mkpath(output)
        path = joinpath(output,"connector_heat_jacobian.native.toml")
        isfile(path) && error("Select a fresh results directory to preserve evidence")
        open(io -> TOML.print(io,record),path,"w")
    end
    @info "Connector heat Jacobian" actual independent expected temperature_indices steps mechanism_sha256_lf=digest
    @test u == before
    @test all(isfinite,J) && all(isfinite,fd)
    # Original four assertions, preserving the expected-side approx scaling.
    @test thermal_approx(actual[2],independent[2],provenance;rtol=1e-3,atol=1e-10)
    @test thermal_approx(actual[1],independent[1],provenance;rtol=1e-3,atol=1e-10)
    @test thermal_approx(actual[1],expected[1],provenance;rtol=1e-6,atol=1e-12)
    @test thermal_approx(actual[2],expected[2],provenance;rtol=1e-6,atol=1e-12)
end
