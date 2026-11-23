using Arrhenius, SHA, Test

@testset "Cantera FreeFlame low inlet temperature" begin
    mechanism = joinpath(@__DIR__, "..", "data", "cantera_flux_gradient_mass", "h2o2.yaml")
    @test bytes2hex(sha256(read(mechanism))) ==
          "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
    @test bytes2hex(sha256(read(mechanism * ".npz"))) ==
          "1cc087ea45a8451ebf575ee35d9edee90445c6d08260f0a92669ee4457f528b5"

    gas = CreateSolution(mechanism)
    X = "H2:0.8, O2:0.5, AR:2"
    # Converged nine-point runs of TestFreeFlame.run_mix with Cantera 4.0.0a2
    # (726522be4). Store inlet.mdot and density * velocity at every grid point.
    reference = (
        (T=180.0, lower=175.0, mdot=0.1611102690983439, rhou=[
            0.1611102690983439, 0.1611102878794202, 0.16111028851875395,
            0.16111028746123945, 0.16111028687382475, 0.16111028551715856,
            0.16111028427687546, 0.16111028008669037, 0.16111023325125853]),
        (T=200.0, lower=195.0, mdot=0.16808940004676484, rhou=[
            0.16808940004676484, 0.16808939796980057, 0.1680893982093732,
            0.16808939780266835, 0.1680893975778185, 0.16808939741148632,
            0.16808939738799344, 0.1680893977490365, 0.1680894031933101]),
        (T=300.0, lower=200.0, mdot=0.23625296628060685, rhou=[
            0.23625296628060685, 0.2362529678943257, 0.2362529679047117,
            0.23625296788863345, 0.2362529678818299, 0.2362529678814331,
            0.23625296788200237, 0.23625296787881192, 0.2362529643028452]),
    )
    @test reference[1].lower < 190
    function check_continuity(rhou, mdot)
        @test length(rhou) == 9 && all(isfinite, rhou)
        @test isfinite(mdot) && mdot > 0
        @test all(abs.(rhou .- mdot) .<= max(1e-4 * abs(mdot), 1e-12))
    end
    for ref in reference
        @testset "Inlet $(ref.T) K" begin
            f = FreeFlame(gas; T=ref.T, P=one_atm, X, width=0.05,
                transport_model=:mixture_averaged)
            grid = copy(f.grid)
            solve!(f; refine_grid=false, auto=false)
            @test f.converged && all(isfinite, f.state)
            @test length(grid) == 9 && f.grid == grid
            @test 1000 * first(Arrhenius._flame_bounds(f, 1, size(f.state, 1))) == ref.lower
            @test 1000 * first(Arrhenius._cantera_flame_temperature_bounds(f)) == ref.lower

            @testset "Cantera reference" begin
                check_continuity(ref.rhou, ref.mdot)
            end
            @testset "Arrhenius" begin
                check_continuity(density(f) .* velocity(f), f.state[end, 1])
            end
        end
    end

    @testset "Compatible solve and cold restarts" begin
        f = FreeFlame(gas; T=180.0, X, width=0.05)
        grid = copy(f.grid)
        solve!(f; refine_grid=false, auto=false, cantera_compatible=true)
        @test f.converged && all(isfinite, f.state)
        @test length(grid) == 9 && f.grid == grid
        check_continuity(density(f) .* velocity(f), f.state[end, 1])

        mktempdir() do dir
            csv = save_flame(joinpath(dir, "cold.csv"), f)
            guess = FreeFlame(gas; T=180.0, X)
            set_initial_guess!(guess, csv)
            @test guess.grid == f.grid
            @test temperature(guess) ≈ temperature(f)
            @test velocity(guess) ≈ velocity(f)
            table = read_flame_csv(csv)
            table.data[2, findfirst(==("temperature_K"), table.columns)] = 174.0
            @test_throws ArgumentError set_initial_guess!(guess, table)

            # A snapshot carries its own inlet, even if the destination is warm.
            snapshot = save_flame(joinpath(dir, "cold.npz"), f)
            restored = FreeFlame(gas; T=300.0, X)
            restore_flame!(restored, snapshot)
            @test restored.inlet_temperature == 180.0
            @test restored.grid == f.grid && restored.state == f.state
        end
    end

    @testset "Weakly exothermic cold mixture" begin
        weak = "H2:0.005,O2:0.0025,AR:1"
        # Cantera 4.0.0a2 HP equilibrium at 100 K and one atmosphere.
        Tad = 157.3047630752228
        for f in (FreeFlame(gas; T=100.0, X=weak),
                  BurnerFlame(gas; T=100.0, X=weak, mdot=0.1))
            @test last(temperature(f)) ≈ Tad
            f.state[1, end] = f.inlet_temperature / 1000
            Arrhenius._fresh_analytic_guess!(f)
            @test last(temperature(f)) ≈ Tad
        end
    end

    for T in (5.0, 0.0, -10.0, NaN, Inf, -Inf, 6001.0)
        @test_throws ArgumentError FreeFlame(gas; T, X)
    end
    @test_throws ArgumentError FreeFlame(gas; T=180.0, P=0.0, X)
    @test_throws ArgumentError FreeFlame(gas; T=180.0, P=NaN, X)

    burner = BurnerFlame(gas; T=180.0, X, mdot=0.1)
    set_temperature_profile!(burner, [0., 1.], [180., 175.])
    @test temperature(burner)[[1, end]] ≈ [180., 175.]
    @test_throws ArgumentError set_temperature_profile!(burner, [0., 1.], [180., 174.])
end
