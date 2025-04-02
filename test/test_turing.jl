include("supporting/turing_models.jl")
include("supporting/analytic_solutions.jl")

@testset "Turing-gradient" begin
    target = Pigeons.toy_turing_unid_target()
    @test target.dimension == 2
    truth = unid_target_exact_logZ(target)
    
    @show Threads.nthreads()
    
    logz_am = Pigeons.stepping_stone(pigeons(; target, explorer = AutoMALA(), n_chains=8))
    @show logz_am
    @test isapprox(logz_am, truth, rtol = 0.1)
end

@testset "Turing-variable-names" begin
    pt = pigeons(target = TuringLogPotential(model_with_vectors()), n_rounds = 2);
    @test length(sample_names(pt)) == 4 + 1 # +1 for :log_density
end

@testset "Utilities" begin
    # sadly this seems like the only way to test functions inside extensions
    # https://discourse.julialang.org/t/running-tests-on-code-defined-in-package-extension/99691
    PigeonsDynamicPPLExt = if isdefined(Base, :get_extension)
        Base.get_extension(Pigeons, :PigeonsDynamicPPLExt)
    else
        Pigeons.PigeonsDynamicPPLExt
    end
    model = model_with_vectors()
    vi = DynamicPPL.VarInfo(SplittableRandom(1234), model)
    dim = PigeonsDynamicPPLExt.get_dimension(vi)
    @test dim == 4
    dest = zeros(dim)
    PigeonsDynamicPPLExt.flatten!(vi, dest)
    @test DynamicPPL.getall(vi) == dest
end
