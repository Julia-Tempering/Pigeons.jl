"""
Run from runtests.jl
"""

function test_var_reference_Turing()
    model = flip_model_unidentifiable()
    
    # Check NoVarReference()
    inputs = Inputs(
        target = TuringLogPotential(model),
        n_chains = 10,
        n_chains_var_reference = 0,
        seed = 1
    )
    @test_nowarn pt = pigeons(inputs)
    
    # Check GaussianReference()
    inputs = Inputs(
        target = TuringLogPotential(model),
        n_chains = 0,
        n_chains_var_reference  = 10,
        seed = 1,
        var_reference = GaussianReference()
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
        n_chains_var_reference = 5,
        var_reference = GaussianReference(),
        seed = 1
    )
    pt = pigeons(inputs)
    @assert pt.shared.tempering.variational_leg.path.ref isa GaussianReference
end


@testset "Two reference restarts" begin
    struct MyLogPotential end
    (::MyLogPotential)(x) = -0.5*(x[1]-1.0)^2
    Pigeons.create_explorer(::MyLogPotential, ::Inputs) = Pigeons.SliceSampler() 
    Pigeons.create_reference_log_potential(::MyLogPotential, ::Inputs) = Pigeons.ScaledPrecisionNormalLogPotential(1.0, 1)
    Pigeons.create_state_initializer(my_potential::MyLogPotential, ::Inputs) = my_potential
    Pigeons.initialization(::MyLogPotential, ::SplittableRandom, ::Int) = [0.0]
    inputs = Inputs(
        target = MyLogPotential(), 
        n_chains = 5, 
        n_chains_var_reference = 5, 
        var_reference = GaussianReference(), 
        seed = 1,
        n_rounds = 13,
        recorder_builders = Pigeons.online_recorder_builders()
    )
    pt = pigeons(inputs)
    @test abs(Pigeons.global_barrier_variational(pt.shared.tempering) - 0.0) ≤ 0.05
    # check that GCB ≈ 0 for VPT
    
    inputs = Inputs(
       target = MyLogPotential(), 
        n_chains = 5, 
        n_chains_var_reference = 5, 
        var_reference = NoVarReference(), 
        seed = 1,
        n_rounds = 13,
        recorder_builders = Pigeons.online_recorder_builders()
    )
    pt = pigeons(inputs)
    GCB_fixed = Pigeons.global_barrier(pt.shared.tempering)
    GCB_var = Pigeons.global_barrier_variational(pt.shared.tempering)
    @test abs(GCB_fixed - GCB_var) ≤ 0.05
    # check that when no variational reference is used, the two legs are ≈ the same 
    
    inputs = Inputs(
        target = MyLogPotential(),
        n_chains = 5, 
        n_chains_var_reference = 0,
        seed = 1,
        n_rounds = 13, 
        recorder_builders = Pigeons.online_recorder_builders()
    )
    pt = pigeons(inputs)
    @test abs(GCB_fixed - Pigeons.global_barrier(pt.shared.tempering)) ≤ 0.05
    # check that VPT fixed leg ≈ single-leg PT fixed leg
end


function test_two_references_2()
    n_chains = 5
    n_rounds = 15 
    seed = 1
    pt = pigeons(; target = Pigeons.TestSwapper(0.5), recorder_builders = [Pigeons.round_trip], 
                 n_chains = n_chains, n_rounds = n_rounds, seed = seed)
    pt2 = pigeons(; target = Pigeons.TestSwapper(0.5), recorder_builders = [Pigeons.round_trip], 
                 n_chains = n_chains, n_chains_var_reference = n_chains, var_reference = NoVarReference(), 
                 n_rounds = n_rounds, seed = seed)
    restarts = n_tempered_restarts(pt)
    restarts2 = n_tempered_restarts(pt2)
    @test abs(2.0 - restarts2/restarts) ≤ 0.05
    # check that sum of restarts is twice as large when using two references
end


function test_var_reference()
    test_var_reference_Turing()
    test_two_references()
    test_two_references_2()
end
