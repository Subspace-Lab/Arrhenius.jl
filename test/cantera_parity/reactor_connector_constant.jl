@testset "Cantera parity: TestConnectorJacobians.test_mfc_const_flow_cross_reactor_species" begin
    gas,provenance,digest=thermal_fixture()
    X1=Dict("H2"=>2.0,"H"=>0.01,"O"=>0.005,"O2"=>1.0,"OH"=>0.01,"H2O"=>0.05,"HO2"=>0.001,"H2O2"=>0.001,"AR"=>8.0,"N2"=>0.1)
    X2=Dict("H2"=>1.0,"H"=>0.005,"O"=>0.002,"O2"=>0.5,"OH"=>0.005,"H2O"=>0.1,"HO2"=>0.001,"H2O2"=>0.001,"AR"=>8.0,"N2"=>0.1)
    left=WellStirredReactor(gas;temperature=1000.0,pressure=2one_atm,mole_fractions=X1,volume=1.0,energy=:isothermal,rate_multipliers=zeros(gas.n_reactions))
    right=WellStirredReactor(gas;temperature=900.0,pressure=one_atm,mole_fractions=X2,volume=1.0,energy=:isothermal,rate_multipliers=zeros(gas.n_reactions))
    base=ReactorNetwork((left=left,right=right);flows=(MassFlowController(:left,:right;mdot=0.02),))
    model=MovingWallNetwork(base;walls=())
    u=moving_wall_state(model);before=copy(u)
    length(u)==27 && model.volume_indices==[23,24] && model.ledger_offset==25 && isempty(model.walls) || error("Constant-MFC volume/ledger layout changed")
    check_connector_layout(base,u[1:22],gas.species_names)
    u[23:27]==[1,1,0,0,0] || error("Constant-MFC initial volumes/ledgers changed")
    coordinates=vcat(11,23,collect(1:10),22,24,collect(12:21))
    scales=vcat(1.0,1.0,gas.MW,1.0,1.0,gas.MW)
    J=zeros(27,27);moving_wall_jacobian!(J,u,moving_wall_rhs(model))
    mapped=[J[i,j]*scales[b]/scales[a] for (a,i) in enumerate(coordinates),(b,j) in enumerate(coordinates)]
    rtol,atol=provenance["integration_rtol"],provenance["integration_atol"]
    moles=[before[1:10]./gas.MW,before[12:21]./gas.MW]
    totals=sum.(moles)
    steps=vcat(atol.+abs.(before[[11,23]]).*rtol,atol*totals[1].+abs.(moles[1]).*rtol,
        atol.+abs.(before[[22,24]]).*rtol,atol*totals[2].+abs.(moles[2]).*rtol)
    independent=moving_wall_rhs(model)
    plus,minus,states_plus,states_minus=Vector{Float64}[],Vector{Float64}[],Vector{Float64}[],Vector{Float64}[]
    volumes,pressures=Vector{Float64}[],Vector{Float64}[]
    for (j,h,scale) in zip(coordinates,steps,scales)
        a=copy(before);b=copy(before);a[j]+=scale*h;b[j]-=scale*h
        fa=similar(u);fb=similar(u)
        independent(fa,a,nothing,0.0);pa=moving_wall_diagnostics(independent,a).nodes
        independent(fb,b,nothing,0.0);pb=moving_wall_diagnostics(independent,b).nodes
        push!(plus,fa);push!(minus,fb);push!(states_plus,a);push!(states_minus,b)
        push!(volumes,[pa.left.volume,pb.left.volume,pa.right.volume,pb.right.volume])
        push!(pressures,[pa.left.pressure,pb.left.pressure,pa.right.pressure,pb.right.pressure])
    end
    fd=hcat([(a-b)/(2h) for (a,b,h) in zip(plus,minus,steps)]...)
    mapped_fd=[fd[i,j]/scales[k] for (k,i) in enumerate(coordinates),j in 1:24]
    record=Dict("state"=>before,"species_names"=>gas.species_names,"molecular_weights"=>gas.MW,
        "jacobian"=>[collect(r) for r in eachrow(J)],"mapped_jacobian"=>[collect(r) for r in eachrow(mapped)],
        "mapped_fd"=>[collect(r) for r in eachrow(mapped_fd)],"coordinates_1based"=>coordinates,"scales"=>scales,
        "moles"=>moles,"total_moles"=>totals,"fd_steps"=>steps,"states_plus"=>states_plus,"states_minus"=>states_minus,
        "fd_plus"=>plus,"fd_minus"=>minus,"observed_volumes"=>volumes,"observed_pressures"=>pressures,
        "rtol"=>rtol,"atol"=>atol,"temperature"=>[1000.0,900.0],"pressure"=>[2one_atm,one_atm],
        "volume"=>[1.0,1.0],"mole_amounts"=>[X1,X2],"mdot"=>0.02,"energy"=>"isothermal",
        "rate_multipliers"=>zeros(gas.n_reactions),"mechanism_sha256_lf"=>digest,
        "solver_status"=>"not applicable: static Jacobian evaluation; no integration")
    output=get(ENV,"CANTERA_PARITY_RESULTS",nothing)
    if output!==nothing
        mkpath(output);path=joinpath(output,"connector_mfc_constant.native.toml")
        isfile(path) && error("Choose a fresh results directory")
        open(io->TOML.print(io,record),path,"w")
    end
    @test u==before
    @test all(isfinite,J) && all(isfinite,fd)
    @test all(volumes[col][pair:pair+1]==[states_plus[col][idx],states_minus[col][idx]] &&
        volumes[col][pair]!=volumes[col][pair+1] && pressures[col][pair]!=pressures[col][pair+1]
        for (col,pair,idx) in ((2,1,23),(14,3,24)))
    @test all(thermal_approx(a,b,provenance;rtol=5e-3,atol=1e-10) for (a,b) in zip(mapped[15:24,1:12],mapped_fd[15:24,1:12]))
    @test all(thermal_approx(a,0.0,provenance;rtol=1e-6,atol=1e-15) for a in mapped[1:12,13:24])
    @test all(thermal_approx(a,0.0,provenance;rtol=1e-6,atol=1e-10) for a in mapped_fd[1:12,13:24])
end
