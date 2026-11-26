@testset "Cantera parity: TestConnectorJacobians.test_mfc_energy_enabled_cross_reactor" begin
    gas, provenance, digest = thermal_fixture()
    X1 = Dict("H2"=>2.0,"H"=>0.01,"O"=>0.005,"O2"=>1.0,"OH"=>0.01,
        "H2O"=>0.05,"HO2"=>0.001,"H2O2"=>0.001,"AR"=>8.0,"N2"=>0.1)
    X2 = Dict("H2"=>1.0,"H"=>0.005,"O"=>0.002,"O2"=>0.5,"OH"=>0.005,
        "H2O"=>0.1,"HO2"=>0.001,"H2O2"=>0.001,"AR"=>8.0,"N2"=>0.1)
    left = WellStirredReactor(gas; temperature=1200.0,pressure=2one_atm,
        mole_fractions=X1,volume=1.0,energy=:adiabatic,chemistry=true,
        rate_multipliers=zeros(gas.n_reactions))
    right = WellStirredReactor(gas; temperature=900.0,pressure=one_atm,
        mole_fractions=X2,volume=1.0,energy=:adiabatic,chemistry=true,
        rate_multipliers=zeros(gas.n_reactions))
    model = ReactorNetwork((left=left,right=right);
        flows=(MassFlowController(:left,:right;mdot=0.02),))
    u = network_state(model)
    check_connector_layout(model,u,gas.species_names)
    before = copy(u)
    ns = gas.n_species
    up = model.offsets[1]:model.offsets[1]+ns-1
    down = model.offsets[2]:model.offsets[2]+ns-1
    t1,t2 = last(up)+1,last(down)+1
    J = zeros(length(u),length(u))
    network_jacobian!(J,u,network_rhs(model))
    # Constant linear coordinate transform: d(n_dot[k])/dn[j] =
    # d(m_dot[k])/dm[j] * W[j]/W[k]. Only asserted blocks are mapped.
    species = [J[i,j]*gas.MW[b]/gas.MW[a] for (a,i) in enumerate(down), (b,j) in enumerate(up)]
    moles = before[up] ./ gas.MW
    steps = vcat(provenance["integration_atol"]+abs(before[t1])*provenance["integration_rtol"],
        provenance["integration_atol"]*sum(moles) .+ abs.(moles).*provenance["integration_rtol"])
    columns = vcat(t1,collect(up))
    scales = vcat(1.0,gas.MW)
    plus,minus = Vector{Float64}[],Vector{Float64}[]
    independent_rhs = network_rhs(model)
    for (j,h,scale) in zip(columns,steps,scales)
        perturbed = copy(before)
        perturbed[j] += scale*h
        fplus = similar(u)
        independent_rhs(fplus,perturbed,nothing,0.0)
        perturbed[j] = before[j]-scale*h
        fminus = similar(u)
        independent_rhs(fminus,perturbed,nothing,0.0)
        push!(plus,fplus)
        push!(minus,fminus)
    end
    # Denominator is the source mole/T step, not the mass perturbation.
    fd = hcat([(a-b)/(2h) for (a,b,h) in zip(plus,minus,steps)]...)
    fd_species = [fd[i,j+1]/gas.MW[k] for (k,i) in enumerate(down), j in 1:ns]
    record = Dict("species_names"=>gas.species_names,"molecular_weights"=>gas.MW,
        "state"=>before,"jacobian"=>[collect(row) for row in eachrow(J)],
        "temperature_indices_1based"=>[t1,t2],"upstream_species_indices_1based"=>collect(up),
        "downstream_species_indices_1based"=>collect(down),"upstream_moles"=>moles,
        "upstream_total_moles"=>sum(moles),"fd_steps"=>steps,"fd_plus"=>plus,"fd_minus"=>minus,
        "actual_temperature_entry"=>J[t2,t1],"fd_temperature_entry"=>fd[t2,1],
        "actual_species_block"=>[collect(row) for row in eachrow(species)],
        "fd_species_block"=>[collect(row) for row in eachrow(fd_species)],
        "rtol"=>provenance["integration_rtol"],"atol"=>provenance["integration_atol"],
        "mole_amounts"=>[X1,X2],"temperature"=>[1200.0,900.0],"pressure"=>[2one_atm,one_atm],
        "volume"=>[1.0,1.0],"mdot"=>0.02,"energy_enabled"=>true,"chemistry_enabled"=>true,
        "rate_multipliers"=>zeros(gas.n_reactions),"mechanism_sha256_lf"=>digest,
        "solver_status"=>"not applicable: static Jacobian evaluation; no integration")
    output = get(ENV,"CANTERA_PARITY_RESULTS",nothing)
    if output !== nothing
        mkpath(output)
        path = joinpath(output,"connector_mfc_energy.native.toml")
        isfile(path) && error("Select a fresh results directory to preserve evidence")
        open(io -> TOML.print(io,record),path,"w")
    end
    @info "MFC energy Jacobian" temperature_entry=J[t2,t1] fd_temperature_entry=fd[t2,1] maximum_species_absolute_error=maximum(abs.(species-fd_species)) mechanism_sha256_lf=digest
    @test u == before
    @test all(isfinite,J) && all(isfinite,fd)
    @test abs(J[t2,t1]) > 1e-20
    @test thermal_approx(J[t2,t1],fd[t2,1],provenance;rtol=1e-2,atol=1e-10)
    @test all(thermal_approx(a,b,provenance;rtol=1e-2,atol=1e-10) for (a,b) in zip(species,fd_species))
end
