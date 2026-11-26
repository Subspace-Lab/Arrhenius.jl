using Arrhenius, Test
include("reactor_connector_layout.jl")

@testset "Connector layout guards" begin
    gas = CreateSolution(joinpath(@__DIR__,"fixtures","cantera-726522be","h2o2.yaml");phase="ohmech")
    left = WellStirredReactor(gas;temperature=1200.0,pressure=202650.0,mole_fractions=Dict("H2"=>2.0,"O2"=>1.0,"AR"=>8.0))
    right = WellStirredReactor(gas;temperature=900.0,pressure=101325.0,mole_fractions=Dict("H2"=>1.0,"O2"=>1.0,"AR"=>8.0))
    model = ReactorNetwork((left=left,right=right))
    u = network_state(model)
    @test check_connector_layout(model,u,gas.species_names) === nothing
    @test_throws ArgumentError check_connector_layout(model,vcat(u,1.0),gas.species_names)
    @test_throws ArgumentError check_connector_layout(model,u,reverse(gas.species_names))
    @test_throws ArgumentError check_connector_layout((nodes=(right=right,left=left),offsets=model.offsets),u,gas.species_names)
    @test_throws ArgumentError check_connector_layout((nodes=model.nodes,offsets=[1,13]),u,gas.species_names)
    swapped = copy(u); swapped[1],swapped[11] = swapped[11],swapped[1]
    @test_throws ArgumentError check_connector_layout(model,swapped,gas.species_names)
    reordered = copy(u); reordered[1],reordered[4] = reordered[4],reordered[1]
    @test_throws ArgumentError check_connector_layout(model,reordered,gas.species_names)
    @test u == network_state(model)
end
