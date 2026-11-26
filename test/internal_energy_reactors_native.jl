using Arrhenius, LinearAlgebra, Test

@testset "closed internal-energy reactor" begin
    gas = CreateSolution(joinpath(@__DIR__, "..", "mechanism", "h2o2.yaml"))
    initial = (; temperature=1100.0, pressure=10one_atm, mole_fractions=Dict("H2"=>1.0,"O2"=>0.5,"AR"=>8.0))
    thermal = IdealGasReactor(gas; initial..., constraint=:constant_volume)
    r = InternalEnergyReactor(thermal)
    u = reactor_state(r)
    @test u[1:end-1] == reactor_state(thermal)[1:end-1]
    @test u[end] == reactor_properties(thermal).internal_energy
    @test reactor_state(InternalEnergyReactor(gas; initial...)) == u
    @test_throws ArgumentError InternalEnergyReactor(IdealGasReactor(gas; initial..., constraint=:constant_pressure))
    @test_throws ArgumentError InternalEnergyReactor(IdealGasReactor(gas; initial..., energy=:isothermal))
    rhs = reactor_rhs(r)
    other = reactor_rhs(r)
    @test rhs.thermal_rhs.workspace !== other.thermal_rhs.workspace
    @test rhs.thermal_state !== other.thermal_state
    before = copy(u)
    du = similar(u)
    rhs(du,u,nothing,0.0)
    old = similar(u)
    reactor_rhs(thermal)(old,reactor_state(thermal),nothing,0.0)
    @test du[1:end-1] ≈ old[1:end-1] rtol=1e-12
    @test iszero(du[end])
    @test u == before
    @test reactor_properties(rhs,u).temperature ≈ 1100.0 atol=1e-10 rtol=0
    @test_throws DimensionMismatch reactor_properties(rhs,u[1:end-1])
    bad = copy(u); bad[end] = NaN
    @test_throws DomainError reactor_properties(rhs,bad)
    bad[end] = -1e100
    @test_throws Arrhenius._InternalEnergyInversionError reactor_properties(rhs,bad)
    bad .= 0
    @test_throws DomainError reactor_properties(rhs,bad)
    # Fixed-composition inverse must recover independently evaluated energy;
    # the negative formation energy of water must not be rejected.
    positive = collect(range(1.0,2.0; length=gas.n_species)); positive ./= sum(positive)
    for (T,Y) in ((300.0,mass_fractions(gas,mole_fractions(gas,"H2O"))),
                  (1400.0,positive),(2671.7750560287313,positive))
        rt = IdealGasReactor(gas; temperature=T,pressure=10one_atm,mass_fractions=Y,constraint=:constant_volume)
        re = InternalEnergyReactor(rt)
        ue = reactor_state(re); fr = reactor_rhs(re)
        # Force inversion from a different seed, not a zero-residual shortcut.
        fr.thermal_state[end] = 1100.0
        p = reactor_properties(fr,ue)
        @test p.temperature ≈ T atol=1e-10 rtol=0
        @test abs((p.internal_energy-ue[end])*rt.density) <= 1e-7
        @test p.mass_fractions == rt.mass_fractions
        T == 300.0 && @test ue[end] < 0
        if T == 1400.0
            J = zeros(length(ue),length(ue)); reactor_jacobian!(J,ue,fr)
            direction = collect(range(-0.1,0.1;length=length(ue)))
            direction[end] = 100p.cv
            plus,minus = similar(ue),similar(ue); h = 1e-5
            fr(plus,ue+h*direction,nothing,0.0)
            fr(minus,ue-h*direction,nothing,0.0)
            # Same directional check/tolerance as reactors_native.jl.
            @test J*direction ≈ (plus-minus)/(2h) rtol=1e-6
            @test all(iszero,J[end,:])
            @test_throws DimensionMismatch reactor_jacobian!(zeros(2,2),ue,fr)
        end
    end
    # Signed trial fractions are kept, not normalized or clipped by inversion.
    signed = copy(u); signed[findfirst(==("H"),gas.species_names)] = -1e-14
    p = reactor_properties(rhs,signed)
    @test p.mass_fractions == signed[1:end-1]
    @test abs((p.internal_energy-signed[end])*thermal.density) <= 1e-7
    rhs(du,signed,nothing,0.0)
    @test all(isfinite,du) && iszero(du[end])
    problem = reactor_problem(r,(0.0,1.0))
    @test problem.u0 == u
    @test_throws ArgumentError reactor_problem(r,(1.0,0.0))
    problem.tgrad(du,u,nothing,0.0)
    @test all(iszero,du)
    @test solve_reactor(r,(0.0,1.0);integrator=(p;marker)->marker,marker=:result) === :result
end
@testset "internal-energy configuration ownership" begin
    gas = CreateSolution(joinpath(@__DIR__, "..", "mechanism", "h2o2.yaml"))
    source = IdealGasReactor(gas; temperature=1100.0, pressure=10one_atm,
        mole_fractions=Dict("H2"=>1.0,"O2"=>0.5,"AR"=>8.0),
        constraint=:constant_volume, rate_multipliers=ones(gas.n_reactions))
    owned = InternalEnergyReactor(source)
    initial = reactor_state(owned)
    rhs = reactor_rhs(owned); before = similar(initial); rhs(before,initial)
    @test owned.thermal.mass_fractions !== source.mass_fractions
    @test owned.thermal.rate_multipliers !== source.rate_multipliers
    @test owned.thermal.mass_fractions == source.mass_fractions
    @test owned.thermal.rate_multipliers == source.rate_multipliers
    @test owned.thermal.density === source.density
    @test owned.thermal.gas === source.gas # Shared read-only mechanism.
    source.mass_fractions .= 0
    source.rate_multipliers .= 0
    @test reactor_state(owned) == initial
    after = similar(initial); rhs(after,reactor_state(owned))
    @test after == before
end