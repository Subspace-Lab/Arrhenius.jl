# Maintenance guards for the existing #59 physical case and actual adapter.
include("internal_energy_initialization.jl")

struct _InternalEnergyDomainProbe
    exception::Exception
end
# Fault injection is confined to this test-only RHS parameter type.
Arrhenius.reactor_properties(rhs::InternalEnergyRHS{_InternalEnergyDomainProbe},u) =
    throw(rhs.reactor.exception)

@testset "internal-energy adapter error classification" begin
    state = [1.0, -1.0]
    probe(error) = InternalEnergyRHS(_InternalEnergyDomainProbe(error),nothing,
        copy(state),zeros(1),zeros(2,2))
    @test _internal_energy_outside_domain(probe(DomainError(-1,"physical")),state)
    inversion = Arrhenius._InternalEnergyInversionError("root failure detail")
    @test _internal_energy_outside_domain(probe(inversion),state)
    @test sprint(showerror,inversion) == "root failure detail"
    original = ErrorException("injected programming error")
    caught = try
        _internal_energy_outside_domain(probe(original),state)
        nothing
    catch error
        error
    end
    @test caught === original
    @test sprint(showerror,caught) == "injected programming error"
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