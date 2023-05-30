@testset "Checkpoints" begin
    for target in [
            Pigeons.blang_bhcd(), 
            Pigeons.blang_ising(), 
            Pigeons.blang_unid(), 
            Pigeons.blang_sitka()]
        pigeons(; target, n_rounds = 2, n_chains = 2)
    end
end