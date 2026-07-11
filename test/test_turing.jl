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

@testset "Turing extract_values" begin
    @testset "mixed continuous and discrete" begin
        @model function cont_and_discrete()
            x ~ Normal()
            y ~ Poisson(2.5)
            2.0 ~ Normal(x + y)
        end
        model = cont_and_discrete()
        vi = DynamicPPL.VarInfo(model)
        lp = TuringLogPotential(model)
        sample = Pigeons.extract_sample(vi, lp)
        @test eltype(sample) == Real
        @test length(sample) == 3 # x, y, log_density
        @test sample[1] isa Float64
        @test sample[2] isa Int
        @test sample[3] isa Float64
    end

    @testset "all continuous" begin
        @model function cont_only()
            x ~ Normal()
            1.0 ~ Normal(x)
        end
        model = cont_only()
        vi = DynamicPPL.VarInfo(model)
        lp = TuringLogPotential(model)
        sample = Pigeons.extract_sample(vi, lp)
        # Check that the result is concretised
        @test eltype(sample) == Float64
        @test length(sample) == 2 # x, log_density
    end
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
