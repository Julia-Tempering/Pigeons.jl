include("supporting/turing_models.jl")


@testset "Non-turing-gradient" begin
    target = Pigeons.toy_mvn_target(2)

    @show Threads.nthreads()

    logz_mala = Pigeons.stepping_stone_pair(pigeons(; target, explorer = AutoMALA(preconditioner = Pigeons.IdentityPreconditioner())))
    logz_slicer = Pigeons.stepping_stone_pair(pigeons(; target, explorer = SliceSampler()))

    @test abs(logz_mala[1] - logz_slicer[1]) < 0.1
end

#= 
The reason this test is excluded is described in 
ADgradient() in TuringLogPotential.jl
=#
@testset "Turing-gradient" begin
    target = Pigeons.toy_turing_unid_target()

    @show Threads.nthreads()

    logz_mala = Pigeons.stepping_stone_pair(pigeons(; target, explorer = AutoMALA(preconditioner = Pigeons.IdentityPreconditioner())))
    logz_slicer = Pigeons.stepping_stone_pair(pigeons(; target, explorer = SliceSampler()))

    @test abs(logz_mala[1] - logz_slicer[1]) < 0.1
end

@testset "Turing-variable-names" begin
    pt = pigeons(target = TuringLogPotential(model_with_vectors()), n_rounds = 2);
    @test length(variable_names(pt)) == 4
end