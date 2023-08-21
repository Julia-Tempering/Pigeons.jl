include("supporting/turing_models.jl")

function test_variational_Turing()
    model = flip_model_unidentifiable()
    
    inputs = Inputs(
        target = TuringLogPotential(model),
        n_chains = 10,
        n_chains_variational = 0,
        seed = 1
    )
    RNG_old = copy(Random.GLOBAL_RNG)
    pt = pigeons(inputs)
    @assert RNG_old == copy(Random.GLOBAL_RNG)
     
    # Check GaussianReference()
    inputs = Inputs(
        target = TuringLogPotential(model),
        n_chains = 0,
        n_chains_variational  = 10,
        seed = 1,
        variational = GaussianReference()
    )
    pt = pigeons(inputs)
    # check that a variational reference is indeed used
    @assert pt.shared.tempering.path.ref isa GaussianReference
end

function test_two_references()
    model = flip_model_unidentifiable()

    inputs = Inputs(
        target = TuringLogPotential(model),
        n_chains = 5,
        n_chains_variational = 5,
        variational = GaussianReference(),
        seed = 1
    )
    pt = pigeons(inputs)
    @assert pt.shared.tempering.variational_leg.path.ref isa GaussianReference
end

function test_two_references_2()
    n_chains = 5
    n_rounds = 15 
    seed = 1
    pt = pigeons(; target = Pigeons.TestSwapper(0.5), record = [Pigeons.round_trip], 
                 n_chains = n_chains, n_rounds = n_rounds, seed = seed)
    pt2 = pigeons(; target = Pigeons.TestSwapper(0.5), record = [Pigeons.round_trip], 
                 n_chains = n_chains, n_chains_variational = n_chains, variational = nothing, 
                 n_rounds = n_rounds, seed = seed)
    restarts = n_tempered_restarts(pt)
    restarts2 = n_tempered_restarts(pt2)
    @test abs(2.0 - restarts2/restarts) ≤ 0.05
    # check that sum of restarts is twice as large when using two references
end

function test_variational()
    test_variational_Turing()
    test_two_references()
    test_two_references_2()
end

function make_dict(vec) 
    result = Dict{Symbol,Any}()
    result[:singleton_variable] = vec 
    return result 
end

@testset "Manual diff check" begin
    rng = SplittableRandom(1)
    means = rand(rng, 2)
    sds = rand(rng, 2)
    ref = GaussianReference(make_dict(means), make_dict(sds), 1) 

    x = rand(rng, 2) 
    manual_grad_calculator = LogDensityProblemsAD.ADgradient(:xyz, ref, Pigeons.buffers())
    _, manual_grad = LogDensityProblems.logdensity_and_gradient(manual_grad_calculator, x)

    fct(x) = Pigeons.gaussian_logdensity(x, means, sds)
    @test manual_grad ≈ ForwardDiff.gradient(fct, x)
end

@testset "Variational reference" begin
    test_variational()
end

@testset "Two reference restarts" begin
    struct MyLogPotential end
    (::MyLogPotential)(x) = -0.5*(x[1]-1.0)^2
    Pigeons.create_explorer(::MyLogPotential, ::Inputs) = Pigeons.SliceSampler() 
    Pigeons.default_reference(::MyLogPotential) = Pigeons.ScaledPrecisionNormalLogPotential(1.0, 1)
    Pigeons.initialization(::MyLogPotential, ::AbstractRNG, ::Int) = [0.0]
    inputs = Inputs(
        target = MyLogPotential(), 
        n_chains = 5, 
        n_chains_variational = 5, 
        variational = GaussianReference(), 
        seed = 1,
        n_rounds = 13,
        record = record_online()
    )
    pt = pigeons(inputs)
    @test abs(Pigeons.global_barrier_variational(pt.shared.tempering) - 0.0) ≤ 0.05
    # check that GCB ≈ 0 for VPT
    
    inputs = Inputs(
       target = MyLogPotential(), 
        n_chains = 5, 
        n_chains_variational = 5, 
        seed = 1,
        n_rounds = 13,
        record = record_online()
    )
    pt = pigeons(inputs)
    GCB_fixed = Pigeons.global_barrier(pt.shared.tempering)
    GCB_var = Pigeons.global_barrier_variational(pt.shared.tempering)
    @test abs(GCB_fixed - GCB_var) ≤ 0.05
    # check that when no variational reference is used, the two legs are ≈ the same 
    
    inputs = Inputs(
        target = MyLogPotential(),
        n_chains = 5, 
        n_chains_variational = 0,
        seed = 1,
        n_rounds = 13, 
        record = record_online()
    )
    pt = pigeons(inputs)
    @test abs(GCB_fixed - Pigeons.global_barrier(pt.shared.tempering)) ≤ 0.05
    # check that VPT fixed leg ≈ single-leg PT fixed leg
end