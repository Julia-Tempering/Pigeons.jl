using Enzyme

@testset "autoMALA with Enzyme on custom Julia target" begin
    struct MyLogPotential 
        n_trials::Int
        n_successes::Int
    end
    
    # NB: this is a constrained target but we haven't yet implemented constrained
    # sampling for autoMALA. Still, the purpose here is to check that the buffered
    # Enzyme implementation works, and for this the test is sufficient. 
    function (log_potential::MyLogPotential)(x) 
        p1, p2 = x
        if !(0 < p1 < 1) || !(0 < p2 < 1)
            return -Inf64 
        end
        p = p1 * p2
        logpdf(Binomial(log_potential.n_trials, p), log_potential.n_successes)
    end
    
    my_log_potential = MyLogPotential(100, 50)
    
    Pigeons.initialization(::MyLogPotential, ::AbstractRNG, ::Int) = [0.5, 0.5]
    
    function Pigeons.sample_iid!(::MyLogPotential, replica, shared)
        state = replica.state 
        rng = replica.rng 
        rand!(rng, state)
    end
    
    LogDensityProblems.dimension(lp::MyLogPotential) = 2
    LogDensityProblems.logdensity(lp::MyLogPotential, x) = lp(x)
    
    pt = pigeons(
            target = MyLogPotential(100, 50), 
            reference = MyLogPotential(0, 0), 
            n_chains = 4,
            explorer = AutoMALA(default_autodiff_backend = :Enzyme) 
    )
    @test true
end
