# TestSurfaceKinetics.test_coverages_regression1: energy is disabled upstream.
@testset "Cantera parity: TestSurfaceKinetics.test_coverages_regression1" begin
    _, provenance, _ = thermal_fixture()
    folder = joinpath(@__DIR__, "fixtures", "cantera-726522be", "diamond")
    config = TOML.parsefile(joinpath(folder, "fixture.toml"))
    @test config["cantera_commit"] == provenance["cantera_commit"]
    for (name, digest) in config["sha256"]
        @test bytes2hex(sha256(read(joinpath(folder, name)))) == digest
    end
    gas = CreateSolution(joinpath(folder, "diamond.gas.yaml"); phase="gas")
    surface = SurfaceMechanism(joinpath(folder, "diamond.npz"))
    @test gas.species_names == ["H", "H2", "CH3", "CH4"]
    @test gas.n_reactions == 0
    @test surface.n_surface == 8 && surface.n_gas == 4
    @test surface.species_names[1:8] == ["c6HH", "c6H*", "c6*H", "c6**", "c6HM", "c6HM*", "c6*M", "c6B"]
    vessel() = WellStirredReactor(gas; temperature=1200.0, pressure=1e3,
        mole_fractions=Dict("H"=>0.002,"H2"=>1.0,"CH4"=>0.01,"CH3"=>0.0002),
        volume=0.01, energy=:isothermal)
    network = ReactorNetwork((r1=vessel(), r2=vessel()))
    coverages = zeros(8); coverages[1] = 0.3; coverages[5] = 0.7
    attached = ReactorSurface(:r1, surface; area=1.0, coverages)
    model = CatalyticNetwork(network; surfaces=(attached,))
    u0 = catalytic_state(model)
    # Two [four gas masses,T] blocks, eight coverages, one signed bulk amount.
    @test length(u0) == 19 && model.offsets == [11]
    @test all(abs.(u0[11:18] .- coverages) .<= max.(1e-12, 1e-6 .* abs.(coverages)))
    @test attached.area == 1.0
    @test all(n.initial.energy == :isothermal && n.volume == 0.01 for n in values(network.nodes))
    times = collect(range(1e-6, 1e-3; length=50))
    solution = solve_catalytic(model, (0.0, 1e-3); integrator=native_network_bdf,
        reltol=config["integration_rtol"], abstol=config["integration_atol"],
        saveat=times, save_start=false, save_everystep=false)
    @test SciMLBase.successful_retcode(solution)
    @test solution.t == times
    @test last(solution.t) == 1e-3
    data = zeros(50, 16)
    for (i, (t, u)) in enumerate(zip(solution.t, solution.u))
        @test length(u) == 19 && all(isfinite, u)
        masses = u[1:4]; moles = masses ./ gas.MW
        # Gas mass excludes stored surface and deposited bulk mass.
        data[i,:] = vcat(t, u[5], sum(moles)*Arrhenius.R*u[5]/0.01,
            sum(masses), moles/sum(moles), u[11:18])
    end
    reference = wall_matrix([parse.(Float64, split(line, ',')) for line in
        readlines(joinpath(folder, "reference.csv")) if !isempty(strip(line))])
    @test size(reference) == size(data) == (50,16)
    report = compare_wall_profiles(reference, data; rtol=config["profile_rtol"],
        atol=config["profile_atol"], xtol=config["profile_xtol"])
    @test isnothing(report)
    isnothing(report) || @error report
    save_wall_trajectory("surface_coverages", data)
    @info "Surface coverage regression" retcode=solution.retcode time=last(solution.t) stats=solution.stats
end
