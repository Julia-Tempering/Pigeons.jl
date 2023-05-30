@testset "Checkpoints" begin
    Pigeons.setup_blang("blangDemos")
    Pigeons.setup_blang("nowellpack")
    for target in [
            Pigeons.blang_ising(), 
            Pigeons.blang_unid(), 
            Pigeons.blang_sitka()]
        pigeons(; target, n_rounds = 2, n_chains = 2)
    end
end