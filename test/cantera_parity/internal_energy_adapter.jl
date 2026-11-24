# Maintenance guards for the existing #59 physical case and actual adapter.
include("internal_energy_initialization.jl")

struct _InternalEnergyDomainProbe
    exception::Exception
end
# Fault injection is confined to this test-only RHS parameter type.
Arrhenius.reactor_properties(rhs::InternalEnergyRHS{_InternalEnergyDomainProbe},u) =
    throw(rhs.reactor.exception)
Arrhenius._internal_energy_properties(rhs::InternalEnergyRHS{_InternalEnergyDomainProbe},u,domain_error) =
    throw(rhs.reactor.exception)

@testset "internal-energy adapter error classification" begin
    state = [1.0, -1.0]
    probe(error) = InternalEnergyRHS(_InternalEnergyDomainProbe(error),nothing,
        copy(state),zeros(1),zeros(2,2))
    physical = DomainError(-1,"physical")
    marked = Arrhenius._InternalEnergyDomainError(physical)
    @test _internal_energy_outside_domain(probe(marked),state)
    @test marked.cause === physical
    @test sprint(showerror,marked) == sprint(showerror,physical)
    inversion = Arrhenius._InternalEnergyInversionError("root failure detail")
    @test _internal_energy_outside_domain(probe(inversion),state)
    @test sprint(showerror,inversion) == "root failure detail"
    # Identical value/message is not enough: only explicit origin tags are recoverable.
    for original in (physical, DomainError(:unrelated,"physical"),
                     ErrorException("injected programming error"),
                     DimensionMismatch("injected layout error"), BoundsError(state,3))
        caught = try
            _internal_energy_outside_domain(probe(original),state)
            nothing
        catch error
            error
        end
        @test caught === original
        @test sprint(showerror,caught) == sprint(showerror,original)
    end
end

@testset "internal-energy explicit physical guard origins" begin
    gas = CreateSolution(joinpath(@__DIR__,"fixtures/cantera-726522be/h2o2.yaml");phase="ohmech")
    r = InternalEnergyReactor(gas;temperature=1100.,pressure=10one_atm,
        mole_fractions=Dict("H2"=>1.,"O2"=>0.5,"AR"=>8.))
    u = reactor_state(r)
    invalid = copy(u); invalid[end] = NaN
    caught(call) = try call(); nothing catch error; error end
    # Exercise the real throw sites; do not infer origin from an exception message.
    calls = (
        d -> Arrhenius._internal_energy_state!(reactor_rhs(r),invalid,d),
        d -> Arrhenius._internal_energy_temperature!(reactor_rhs(r),NaN,1.,d),
        d -> Arrhenius._internal_energy_state!(reactor_rhs(r),zeros(length(u)),d),
        d -> Arrhenius._internal_energy_thermo!(reactor_rhs(r),1100.,0.,d))
    for call in calls
        ordinary = caught(() -> call(DomainError))
        marked = caught(() -> call(Arrhenius._InternalEnergyDomainError))
        @test ordinary isa DomainError
        @test marked isa Arrhenius._InternalEnergyDomainError
        @test isequal(marked.cause.val,ordinary.val)
        @test sprint(showerror,marked) == sprint(showerror,ordinary)
    end
    @test_throws DomainError reactor_properties(reactor_rhs(r),invalid)
    @test_throws DomainError reactor_properties(reactor_rhs(r),zeros(length(u)))
    @test _internal_energy_outside_domain(reactor_rhs(r),invalid)
    @test _internal_energy_outside_domain(reactor_rhs(r),zeros(length(u)))
    @test !_internal_energy_outside_domain(reactor_rhs(r),u)
    signed = copy(u); signed[findfirst(==("H"),gas.species_names)] = -1e-14
    @test !_internal_energy_outside_domain(reactor_rhs(r),signed)
    signed[findfirst(==("H"),gas.species_names)] = -1e-13
    @test !_internal_energy_outside_domain(reactor_rhs(r),signed)
    signed[findfirst(==("H"),gas.species_names)] = -2e-13
    @test _internal_energy_outside_domain(reactor_rhs(r),signed)
    extreme = copy(u); extreme[end] = -1e100
    @test_throws Arrhenius._InternalEnergyInversionError reactor_properties(reactor_rhs(r),extreme)
    @test _internal_energy_outside_domain(reactor_rhs(r),extreme)
    water = InternalEnergyReactor(gas;temperature=300.,pressure=10one_atm,mole_fractions=Dict("H2O"=>1.))
    @test reactor_state(water)[end] < 0
    @test !_internal_energy_outside_domain(reactor_rhs(water),reactor_state(water))
    @test_throws DimensionMismatch _internal_energy_outside_domain(reactor_rhs(r),u[1:end-1])
    thermal_bad = reactor_state(r.thermal); thermal_bad[end] = 0.
    @test_throws DomainError reactor_properties(r.thermal,thermal_bad)

end

@testset "internal-energy dense selection preserves results" begin
    auto,sa,ref=initialization_energy_result()
    dense,sd,_=initialization_energy_result(;linear_solver=:dense)
    check_internal_energy_initialization(auto,sa,ref)
    check_internal_energy_initialization(dense,sd,ref)
    @test isequal(sa.t,sd.t)
    @test isequal(sa.u,sd.u)
    @test auto["stats"]==dense["stats"]
    if !isempty(ARGS)
        ispath(only(ARGS)) && error("Preserve existing evidence")
        open(only(ARGS),"w") do io
            TOML.print(io,Dict("auto"=>auto,"dense"=>dense))
        end
    end
end