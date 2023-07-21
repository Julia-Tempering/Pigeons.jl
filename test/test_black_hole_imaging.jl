include("supporting/comrade-interface.jl")

@testset "Comrade" begin
    pt = pigeons(
            target = comrade_target_example(), 
            n_chains = 2,
            n_rounds = 2);
end