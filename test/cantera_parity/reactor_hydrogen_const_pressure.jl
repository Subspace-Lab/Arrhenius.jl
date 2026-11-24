using LinearAlgebra

@testset "Cantera parity: TestReactorJacobians.test_const_pressure_hydrogen_single" begin
    gas, provenance, digest = thermal_fixture()
    multipliers = zeros(gas.n_reactions); multipliers[15] = 1.0
    reactor = IdealGasReactor(gas; temperature=1000.0, pressure=one_atm,
        mole_fractions=Dict("H2"=>1.0,"H"=>2.0,"H2O"=>2.0),
        constraint=:constant_pressure, energy=:adiabatic, rate_multipliers=multipliers)
    initial_mass = 2.0*reactor_properties(reactor).density
    problem = reactor_problem(reactor, (0.0,1.0))
    ode = ODEProblem(ODEFunction(problem.f; jac=problem.jac, tgrad=problem.tgrad),
        problem.u0, problem.tspan, problem.p)
    rtol, atol = provenance["integration_rtol"], provenance["integration_atol"]
    integrator = SciMLBase.init(ode, QNDF(); reltol=rtol, abstol=atol, save_everystep=false)
    SciMLBase.step!(integrator)
    advanced = copy(integrator.u)
    length(advanced) == 11 && gas.n_species == 10 || error("Expected [Y[10],T] layout")
    @test integrator.t > 0
    @test integrator.sol.stats.naccept == 1
    @test all(isfinite, advanced)
    # Preserve the integrator state. Read physical n from the conserved initial
    # mass scale; inverse mapping uses the actual perturbed M=dot(W,n).
    q = vcat(advanced[end], initial_mass*advanced[1:10]./gas.MW)
    rhs = reactor_rhs(reactor)
    function physical_rhs(q)
        # Keep each probe's buffers local: outer checkpoint names are reused
        # below, and Julia closures would otherwise overwrite that evidence.
        local n = q[2:end]
        local mass = dot(gas.MW,n)
        local u = vcat(gas.MW.*n./mass,q[1])
        local f = similar(u); rhs(f,u,nothing,integrator.t)
        return vcat(f[end],mass*f[1:10]./gas.MW), u, mass, f
    end
    g, u, mass, f = physical_rhs(q)
    J = zeros(11,11); reactor_jacobian!(J,u,reactor_rhs(reactor),integrator.t)
    # A=dY/dn. The outer product accounts for the output scale M/W changing
    # when one mole coordinate changes. No inverse of the singular A is used.
    A = (Diagonal(gas.MW)-u[1:10]*gas.MW')/mass
    mapped = zeros(11,11)
    mapped[1,1] = J[11,11]
    mapped[1,2:end] = J[11,1:10]'*A
    mapped[2:end,1] = mass*J[1:10,11]./gas.MW
    mapped[2:end,2:end] = Diagonal(1 ./gas.MW)*(f[1:10]*gas.MW'+mass*J[1:10,1:10]*A)
    fd = zeros(11,11); steps = zeros(11)
    probes = Dict{String,Any}[]
    for j in 1:11
        h = max(abs(q[j]),1000*atol)*sqrt(eps(Float64)); steps[j] = h
        z = copy(q); z[j] += h
        gz, uz, mz, fz = physical_rhs(z)
        fd[:,j] = (gz-g)/h
        props = reactor_properties(reactor,uz)
        push!(probes,Dict("physical_state"=>z,"native_state"=>uz,"mass"=>mz,
            "native_rhs"=>fz,"physical_rhs"=>gz,"volume"=>mz/props.density,
            "pressure"=>props.pressure))
    end
    @test advanced == integrator.u
    @test all(isfinite,mapped) && all(isfinite,fd)
    record = Dict("time"=>integrator.t,"advanced_native_state"=>advanced,
        "physical_state"=>q,"mapped_native_state"=>u,"state_mass"=>mass,
        "initial_mass"=>initial_mass,"initial_volume"=>2.0,
        "initial_temperature"=>1000.0,"initial_pressure"=>one_atm,
        "composition"=>Dict("H2"=>1.0,"H"=>2.0,"H2O"=>2.0),
        "mechanism_sha256_lf"=>digest,"species_names"=>gas.species_names,
        "molecular_weights"=>gas.MW,"rate_multipliers"=>multipliers,
        "constraint"=>"constant_pressure","energy"=>"adiabatic",
        "rtol"=>rtol,"atol"=>atol,"assertion_rtol"=>1e-3,"assertion_atol"=>1e-4,
        "native_jacobian"=>[collect(r) for r in eachrow(J)],"native_rhs"=>f,
        "mapped_jacobian"=>[collect(r) for r in eachrow(mapped)],
        "mapped_fd"=>[collect(r) for r in eachrow(fd)],"baseline_physical_rhs"=>g,
        "mass_fraction_derivatives"=>[collect(r) for r in eachrow(A)],
        "fd_steps"=>steps,"probes"=>probes,
        "maximum_error_over_bound"=>maximum(abs.(mapped-fd)./max.(1e-4,1e-3.*abs.(fd))),
        "retcode"=>string(integrator.sol.retcode),
        "solver_stats"=>Dict(string(k)=>getproperty(integrator.sol.stats,k)
            for k in propertynames(integrator.sol.stats) if getproperty(integrator.sol.stats,k) isa Number),
        "termination"=>"caller stopped after one accepted step; nominal endpoint not requested")
    output = get(ENV,"CANTERA_PARITY_RESULTS",nothing)
    if output !== nothing
        mkpath(output); path = joinpath(output,"hydrogen_const_pressure.native.toml")
        isfile(path) && error("Choose a fresh results directory")
        open(io->TOML.print(io,record),path,"w")
    end
    for col in 1:11, row in 1:11
        @test thermal_approx(mapped[row,col],fd[row,col],provenance;rtol=1e-3,atol=1e-4)
    end
end
