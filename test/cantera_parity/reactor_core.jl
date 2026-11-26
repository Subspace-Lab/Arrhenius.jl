using Arrhenius
using Test

# TestReactor.test_invalid_empty_network has no reactor-class dependence;
# the same guard is inherited unchanged by its ideal-gas/mole subclasses.
@testset "Cantera parity: TestReactor.test_invalid_empty_network" begin
    @test_throws ArgumentError ReactorNetwork(NamedTuple())
end
