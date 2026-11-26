include(joinpath(@__DIR__, "..", "..", "example", "reactors", "surface_solver.jl"))
@testset "Cantera parity: TestAdvanceCoverages.test_different_tolerances" begin
    _, provenance, _ = thermal_fixture()
    folder = joinpath(@__DIR__, "fixtures", "cantera-726522be", "pt_coverages")
    input = TOML.parsefile(joinpath(folder, "fixture.toml"))
    @test input["cantera_commit"] == provenance["cantera_commit"]
    for (name, digest) in input["sha256"]
        @test bytes2hex(sha256(read(joinpath(folder,name)))) == digest
    end
    @test bytes2hex(sha256(read(joinpath(dirname(folder),"gri30.yaml")))) == input["gri30_sha256"]
    gas = CreateSolution(joinpath(folder,"pt.gas.yaml");phase="gas")
    mechanism = SurfaceMechanism(joinpath(folder,"pt.npz"))
    @test gas.species_names == input["gas_species"]
    @test gas.n_species == 32 && gas.n_reactions == 186
    @test mechanism.n_surface == 11 && mechanism.n_gas == 32
    @test mechanism.species_names[1:11] == input["surface_species"]
    # The original fixture obtains the fixed gas composition by HP equilibrium.
    equilibrium = equilibrate(gas;T=input["initial_T"],P=input["initial_P"],
        X=input["initial_X"],mode=:HP)
    @test thermal_approx(equilibrium.T,input["equilibrium_T"],provenance)
    @test all(thermal_approx(a,b,provenance) for (a,b) in zip(equilibrium.X,input["equilibrium_X"]))
    surface = IdealSurface(mechanism;temperature=input["surface_T"],pressure=input["surface_P"],
        gas_temperature=input["surface_T"],mole_fractions=equilibrium.X,
        coverages=Dict("O(S)"=>0.1,"PT(S)"=>0.5,"H(S)"=>0.4))
    initial = copy(surface.coverages)
    expected_initial = [name=="O(S)" ? 0.1 : name=="PT(S)" ? 0.5 : name=="H(S)" ? 0.4 : 0.0 for name in input["surface_species"]]
    @test all(thermal_approx(a,b,provenance) for (a,b) in zip(initial,expected_initial))
    runs = Dict{String,Any}[]
    for (rtol,atol) in ((1e-5,1e-12),(1e-7,1e-14))
        solution = solve_surface(surface,(0.0,1.0);integrator=native_surface_bdf,
            initial_coverages=initial,reltol=rtol,abstol=atol,save_everystep=false)
        @test SciMLBase.successful_retcode(solution)
        @test last(solution.t) == 1.0
        @test length(last(solution.u)) == 11 && all(isfinite,last(solution.u))
        @test surface.coverages == initial
        push!(runs,Dict("rtol"=>rtol,"atol"=>atol,"time"=>last(solution.t),
            "retcode"=>string(solution.retcode),"initial_coverages"=>copy(initial),
            "coverages"=>copy(last(solution.u)),
            "solver_stats"=>Dict(string(k)=>getproperty(solution.stats,k)
                for k in propertynames(solution.stats) if getproperty(solution.stats,k) isa Number)))
        @info "Surface tolerance run" rtol atol retcode=solution.retcode time=last(solution.t) stats=solution.stats
    end
    loose,tight = runs[1]["coverages"],runs[2]["coverages"]
    for i in 1:11
        @test thermal_approx(loose[i],tight[i],provenance)
    end
    @test any(loose .!= tight)
    record = Dict("species"=>input["surface_species"],"equilibrium_T"=>equilibrium.T,
        "equilibrium_X"=>equilibrium.X,"surface_T"=>surface.temperature,"surface_P"=>surface.pressure,
        "gas_T"=>surface.gas_temperature,"runs"=>runs,
        "assertion_rtol"=>1e-6,"assertion_atol"=>1e-12,
        "maximum_error_over_bound"=>maximum(abs.(loose.-tight)./max.(1e-12,1e-6.*abs.(tight))),
        "initial_step_policy"=>"Existing native_surface_bdf default: min(1e-12,tspan/100); no override")
    output=get(ENV,"CANTERA_PARITY_RESULTS",nothing)
    if output !== nothing
        mkpath(output);path=joinpath(output,"surface_tolerances.native.toml")
        isfile(path) && error("Choose a fresh results directory")
        open(io->TOML.print(io,record),path,"w")
    end
end
