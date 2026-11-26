@testset "Cantera parity: TestConnectorJacobians.test_species_subset_mfc_cross_reactor" begin
    down,provenance,digest=thermal_fixture()
    folder=joinpath(@__DIR__,"fixtures","cantera-726522be","mfc_subset3")
    inputs=TOML.parsefile(joinpath(folder,"fixture.toml"))
    for (file,key) in ((inputs["raw_file"],"raw_sha256_lf"),(inputs["normalized_file"],"normalized_sha256_lf"),("equivalence.json","equivalence_sha256_lf"))
        bytes2hex(sha256(replace(read(joinpath(folder,file),String),"\r\n"=>"\n")))==inputs[key] || error("Subset fixture digest mismatch")
    end
    inputs["cantera_commit"]==provenance["cantera_commit"] && inputs["source_h2o2_sha256_lf"]==digest || error("Subset source mismatch")
    up=CreateSolution(joinpath(folder,inputs["normalized_file"]);phase=inputs["phase"])
    up.species_names==["H2","O2","AR"] && up.n_reactions==0 || error("Subset input counts/order mismatch")
    left=WellStirredReactor(up;temperature=1000.0,pressure=2one_atm,volume=1.0,
        mole_fractions=Dict("H2"=>2.0,"O2"=>1.0,"AR"=>8.0),energy=:isothermal)
    right=WellStirredReactor(down;temperature=900.0,pressure=one_atm,volume=1.0,
        mole_fractions=Dict("H2"=>1.0,"O2"=>0.5,"AR"=>8.0),energy=:isothermal,rate_multipliers=zeros(down.n_reactions))
    base=ReactorNetwork((left=left,right=right);flows=(MassFlowController(:left,:right;mdot=0.02),))
    model=MovingWallNetwork(base;walls=())
    u=moving_wall_state(model);before=copy(u)
    # Unequal species counts require their own complete initial-layout contract.
    keys(base.nodes)==(:left,:right) && base.offsets==[1,5] && base.species_maps==[[1,4,9]] &&
        model.volume_indices==[16,17] && model.ledger_offset==18 && isempty(model.walls) &&
        length(u)==20 || error("Subset node/coordinate layout changed")
    expected=vcat(left.initial.density*left.volume.*left.initial.mass_fractions,1000.0,
        right.initial.density*right.volume.*right.initial.mass_fractions,900.0,1.0,1.0,zeros(3))
    u==expected || error("Subset species mass/T/V/ledger coordinates changed")
    columns=[4,16,1,2,3];rows=5:14;scales=vcat(1.0,1.0,up.MW)
    J=zeros(length(u),length(u));moving_wall_jacobian!(J,u,moving_wall_rhs(model))
    block=[J[i,j]*scales[b]/down.MW[a] for (a,i) in enumerate(rows),(b,j) in enumerate(columns)]
    n=before[1:3]./up.MW
    rtol,atol=provenance["integration_rtol"],provenance["integration_atol"]
    steps=vcat(atol.+abs.(before[columns[1:2]]).*rtol,atol*sum(n).+abs.(n).*rtol)
    independent=moving_wall_rhs(model)
    plus,minus,states_plus,states_minus=Vector{Float64}[],Vector{Float64}[],Vector{Float64}[],Vector{Float64}[]
    observed=Vector{Float64}[]
    for (j,h,scale) in zip(columns,steps,scales)
        a=copy(before);b=copy(before);a[j]+=scale*h;b[j]-=scale*h
        fa=similar(u);fb=similar(u)
        independent(fa,a,nothing,0.0)
        pa=moving_wall_diagnostics(independent,a).nodes.left
        independent(fb,b,nothing,0.0)
        pb=moving_wall_diagnostics(independent,b).nodes.left
        push!(plus,fa);push!(minus,fb);push!(states_plus,a);push!(states_minus,b)
        push!(observed,[pa.volume,pb.volume,pa.pressure,pb.pressure])
    end
    fd=hcat([(a-b)/(2h) for (a,b,h) in zip(plus,minus,steps)]...)
    oracle=[fd[i,j]/down.MW[k] for (k,i) in enumerate(rows),j in 1:5]
    shared=only(base.species_maps)
    record=Dict("species_up"=>up.species_names,"species_down"=>down.species_names,"mw_up"=>up.MW,"mw_down"=>down.MW,
        "state"=>before,"jacobian"=>[collect(r) for r in eachrow(J)],"species_block"=>[collect(r) for r in eachrow(block)],
        "fd_species_block"=>[collect(r) for r in eachrow(oracle)],"columns_1based"=>columns,"rows_1based"=>collect(rows),
        "shared_rows_1based"=>shared,"scales"=>scales,"upstream_moles"=>n,"upstream_total_moles"=>sum(n),
        "fd_steps"=>steps,"fd_plus"=>plus,"fd_minus"=>minus,"states_plus"=>states_plus,"states_minus"=>states_minus,
        "observed_upstream_volume_pressure"=>observed,"rtol"=>rtol,"atol"=>atol,"temperature"=>[1000.0,900.0],
        "pressure"=>[2one_atm,one_atm],"volume"=>[1.0,1.0],"mdot"=>0.02,"energy"=>"isothermal",
        "downstream_multipliers"=>zeros(down.n_reactions),"upstream_reactions"=>up.n_reactions,
        "mechanism_sha256_lf"=>digest,"upstream_sha256_lf"=>inputs["normalized_sha256_lf"],
        "solver_status"=>"not applicable: static Jacobian test; no integration")
    output=get(ENV,"CANTERA_PARITY_RESULTS",nothing)
    if output!==nothing
        mkpath(output);path=joinpath(output,"connector_species_subset.native.toml")
        isfile(path) && error("Choose fresh evidence directory")
        open(io->TOML.print(io,record),path,"w")
    end
    @test u==before
    @test all(isfinite,J) && all(isfinite,fd)
    # V was genuinely changed and propagated into density/pressure, not padded.
    @test observed[2][1:2]==[states_plus[2][16],states_minus[2][16]] && observed[2][1]!=observed[2][2] && observed[2][3]!=observed[2][4]
    for k in shared
        @test any(!iszero,block[k,:])
    end
    for k in setdiff(1:10,shared)
        @test all(thermal_approx(x,0.0,provenance;rtol=1e-6,atol=1e-15) for x in block[k,:])
    end
    for k in shared
        @test all(thermal_approx(a,b,provenance;rtol=1e-4,atol=1e-10) for (a,b) in zip(block[k,:],oracle[k,:]))
    end
end
