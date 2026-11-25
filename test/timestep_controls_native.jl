using Arrhenius,Test

@testset "Cantera time-step controls" begin
    mechanism=joinpath(@__DIR__,"..","mechanism","h2o2.yaml")
    gas=CreateSolution(mechanism)
    X="H2:1.1,O2:1,AR:5"
    defaults=(;time_step_growth_factor=1.5,time_step_growth_strategy=:fixed_growth,
        time_step_callback=nothing,time_step_regrid=3,jacobian_mode=:analytic)
    reference=solve!(FreeFlame(gas;X))
    explicit=solve!(FreeFlame(gas;X);defaults...)
    @test explicit.grid==reference.grid && explicit.state==reference.state
    speed=flame_speed(reference)
    for strategy in Arrhenius._timestep_growth_strategies
        steps=Float64[]
        f=solve!(FreeFlame(gas;X);time_step_growth_strategy=strategy,time_step_growth_factor=2.,
            time_step_callback=dt->push!(steps,dt))
        @test f.converged && isapprox(flame_speed(f),speed;rtol=1e-6)
        @test !isempty(steps) && all(>(0),steps)
    end
    fd=solve!(FreeFlame(gas;X);jacobian_mode=:finite_difference)
    @test fd.converged && isapprox(flame_speed(fd),speed;rtol=1e-6)
    analytic=solve!(FreeFlame(gas;X);jacobian_mode=:analytic)
    @test analytic.converged && analytic.grid==reference.grid && analytic.state==reference.state
    compatible=solve!(FreeFlame(gas;X);jacobian_mode=:finite_difference,cantera_compatible=true)
    # Cantera-compatible convergence/damping policies may change the converged
    # state, while the auto Jacobian alias must preserve the grid and converge.
    @test compatible.converged && compatible.grid==analytic.grid && all(isfinite,compatible.state)
    @test solve!(FreeFlame(gas;X);time_step_regrid=3).state==reference.state
    # Cantera TestOnedim.test_time_step_control_option_validation checks NaN
    # separately from Inf; both native flame families must reject it.
    for bad in ((;time_step_growth_factor=.5),(;time_step_growth_factor=Inf),(;time_step_growth_factor=NaN),
            (;time_step_growth_strategy=:invalid),(;time_step_regrid=-1),(;jacobian_mode=:unknown))
        @test_throws ArgumentError solve!(FreeFlame(gas;X);bad...)
        @test_throws ArgumentError solve!(CounterflowDiffusionFlame(gas;fuel="H2:1",oxidizer="O2:1",
            mdot_fuel=.24,mdot_oxidizer=.72);bad...)
    end

    kwargs=(fuel="H2:1,AR:1",oxidizer="O2:.2,AR:.8",mdot_fuel=.24,mdot_oxidizer=.72)
    counterflow=solve!(CounterflowDiffusionFlame(gas;kwargs...);slope=.2,curve=.3)
    counterflow_defaults=merge(defaults,(;jacobian_mode=:auto))
    explicit=solve!(CounterflowDiffusionFlame(gas;kwargs...);slope=.2,curve=.3,counterflow_defaults...)
    @test explicit.grid==counterflow.grid && explicit.state==counterflow.state
    compatible_cf=solve!(CounterflowDiffusionFlame(gas;kwargs...);slope=.2,curve=.3,cantera_compatible=true)
    @test compatible_cf.converged && compatible_cf.grid==counterflow.grid && all(isfinite,compatible_cf.state)
    Tmax=maximum(temperature(counterflow))
    for options in ((;time_step_growth_strategy=:residual_ratio),(;time_step_growth_strategy=:newton_iterations),
            (;jacobian_mode=:finite_difference))
        steps=Float64[]
        c=solve!(CounterflowDiffusionFlame(gas;kwargs...);slope=.2,curve=.3,options...,
            time_step_callback=dt->push!(steps,dt))
        @test c.converged && isapprox(maximum(temperature(c)),Tmax;rtol=1e-6)
        @test !isempty(steps) && all(>(0),steps)
    end
end

@testset "default premixed analytic Jacobian and transport fallback" begin
    mechanism=joinpath(@__DIR__,"..","mechanism","h2o2.yaml")
    gas=CreateSolution(mechanism)
    X="H2:2,O2:1,AR:3.76"

    # FreeFlame and BurnerFlame default to residual-faithful :analytic species
    # columns (matching Cantera's interior analytic Jacobian while retaining
    # Burner boundary blocks required by the default residual stopping rule).
    free=solve!(FreeFlame(gas;X,width=.03);slope=.06,curve=.12)
    @test free.converged
    @test solver_options(free).jacobian_mode===:analytic

    burner_default=solve!(BurnerFlame(gas;X,mdot=.3,width=.03);slope=.06,curve=.12)
    burner_fd=solve!(BurnerFlame(gas;X,mdot=.3,width=.03);slope=.06,curve=.12,
        jacobian_mode=:finite_difference)
    @test burner_default.converged && burner_fd.converged
    @test solver_options(burner_default).jacobian_mode===:analytic
    @test isapprox(maximum(temperature(burner_default)),maximum(temperature(burner_fd));rtol=1e-6)

    # Unsupported transport/basis modes (e.g. flux_gradient_basis=:mass) already
    # assemble full FD columns in the primary stencil loop and must not trigger
    # a second redundant FD fallback pass under default jacobian_mode=:analytic.
    Xmass="H2:1.1,O2:1,AR:5"
    mass_default=FreeFlame(gas;X=Xmass,width=.03)
    set_transport!(mass_default,:mixture_averaged;flux_gradient_basis=:mass)
    solve!(mass_default;slope=.1,curve=.2)

    mass_fd=FreeFlame(gas;X=Xmass,width=.03)
    set_transport!(mass_fd,:mixture_averaged;flux_gradient_basis=:mass)
    solve!(mass_fd;slope=.1,curve=.2,jacobian_mode=:finite_difference)

    @test mass_default.converged && mass_fd.converged
    @test mass_default.state==mass_fd.state
    @test solver_stats(mass_default).residual_evals==solver_stats(mass_fd).residual_evals
    @test solver_stats(mass_default).jacobians==solver_stats(mass_fd).jacobians
end
