include("supporting/turing_models.jl")
include("supporting/analytic_solutions.jl")

@testset "Turing-gradient" begin
    target = Pigeons.toy_turing_unid_target()
    @test target.dimension == 2
    truth = unid_target_exact_logZ(target)
    
    @show Threads.nthreads()
    
    logz_am = Pigeons.stepping_stone(pigeons(; target, explorer = AutoMALA(), n_chains=8))
    @show logz_am
    @test isapprox(logz_am, truth, rtol = 0.2)
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
    model_dim = PigeonsDynamicPPLExt.get_dimension(model)
    @test model_dim == 4
    @test dim == 4
    dest = zeros(dim)
    PigeonsDynamicPPLExt.flatten!(vi, dest)
    @test vi[:] == dest
end

@testset "Turing-variable-names-Dirichlet" begin
    # For models with constrained distributions like Dirichlet, the unconstrained
    # internal representation has fewer dimensions than the user-facing one
    # (a length-K Dirichlet uses K-1 unconstrained dims due to the simplex constraint).
    # sample_names must report the user-facing (constrained) names; previously
    # it iterated over the unconstrained representation, dropping x[K] and y[K].
    @model function dirichlet_sample_names_model()
        x ~ Dirichlet([1.0, 2.0, 1.0])
        y ~ Dirichlet([1.0, 2.0, 1.0])
    end
    pt = pigeons(target = TuringLogPotential(dirichlet_sample_names_model()), n_rounds = 2)
    names = sample_names(pt)
    @test length(names) == 6 + 1  # 3 components per Dirichlet × 2 vars + :log_density
    @test Symbol("x[3]") in names
    @test Symbol("y[3]") in names
    @test :log_density in names
end
