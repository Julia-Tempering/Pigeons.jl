include("supporting/turing_models.jl")

@testset "Turing-gradient" begin
    target = Pigeons.toy_turing_unid_target()
    truth = -11.9 # based on: stepping_stone(pigeons(target = Pigeons.toy_turing_unid_target(), n_rounds = 17))
    
    @show Threads.nthreads()
    
    logz_am = Pigeons.stepping_stone(pigeons(; target, explorer = AutoMALA(), n_chains=8))
    @show logz_am
    @test isapprox(logz_am, truth, rtol = 0.05)
end

@testset "Turing-variable-names" begin
    pt = pigeons(target = TuringLogPotential(model_with_vectors()), n_rounds = 2);
    @test length(sample_names(pt)) == 4 + 1 # +1 for :log_density
end