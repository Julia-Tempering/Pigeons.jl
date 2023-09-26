include("supporting/HetPrecisionNormalLogPotential.jl")
include("supporting/dimensional-analysis.jl")

mean_mh_accept(pt) = mean(Pigeons.explorer_mh_prs(pt))

automala(target) =
    pigeons(; 
        target, 
        explorer = AutoMALA(), 
        n_chains = 1, n_rounds = 10, record = record_online())

@testset "Scaling law" begin
    tuple = scaling_plot(7, sampling_fcts = [auto_mala]) 
    @test abs(tuple.slopes[:auto_mala] - 1.33) < 0.15
end

@testset "Step size convergence" begin
    targets = Any[toy_mvn_target(1)]
    is_windows_in_CI() || push!(targets, toy_stan_target(1))
    for t in targets
        step10rounds = pigeons(target = t, explorer = AutoMALA(), n_chains = 1, n_rounds = 10).shared.explorer.step_size
        step15rounds = pigeons(target = t, explorer = AutoMALA(), n_chains = 1, n_rounds = 15).shared.explorer.step_size
        @test isapprox(step10rounds, step15rounds, rtol = 0.1)
    end
end

@testset "Step size d-scaling" begin
    step1d    = automala(toy_mvn_target(1)).shared.explorer.step_size
    step1000d = automala(toy_mvn_target(1000)).shared.explorer.step_size
    @test step1000d < step1d # make sure we do shrink eps with d 

    # should not shrink by more than ~(1000)^(1/3) according to theory
    # indeed we get 3.666830946679011 factor shrinkage as of 23493d7bb5bf926ab98b78883a0f056b98d59e75
    @test step1d/step1000d < (1000)^(1/3)  
end

@testset "Mass-matrix" begin
    bad_conditioning_target = HetPrecisionNormalLogPotential([500.0, 1.0])
    pt = pigeons(target = bad_conditioning_target, explorer = AutoMALA(), n_chains = 1, n_rounds = 10)
    @test abs(pt.shared.explorer.estimated_target_std_deviations[1] - 1/sqrt(500)) < 0.01
    @test mean_mh_accept(pt) > 0.5
end

@testset "AutoMALA dimensional autoscale" begin
    for i in 0:3
        d = 10^i
        @test mean_mh_accept(automala(toy_mvn_target(d))) > 0.4
    end
end

@testset "Hamiltonian-involutive" begin
    rng = SplittableRandom(1)

    my_target = ADgradient(:ForwardDiff, HetPrecisionNormalLogPotential([5.0, 1.1]))
    some_cond = [2.3, 0.8]

    x = randn(rng, 2)
    v = randn(rng, 2)

    n_leaps = 40

    @testset "Flip step" begin
        x = randn(rng, 2)
        v = randn(rng, 2)
        startx = copy(x)
        startv = copy(v)
        @test Pigeons.hamiltonian_dynamics!(my_target, some_cond, x, v, 0.1, n_leaps)
        @test !(x ≈ startx) && !(v ≈ startv)
        @test Pigeons.hamiltonian_dynamics!(my_target, some_cond, x, v, -0.1, n_leaps)
        @test (x ≈ startx) && (v ≈ startv)
    end
    
    @testset "Flip momentum" begin
        x = randn(rng, 2)
        v = randn(rng, 2)
        startx = copy(x)
        startv = copy(v)
        @test Pigeons.hamiltonian_dynamics!(my_target, some_cond, x, v, 0.1, n_leaps)
        @test !(x ≈ startx) && !(v ≈ startv)
        v .*= -1
        @test Pigeons.hamiltonian_dynamics!(my_target, some_cond, x, v, 0.1, n_leaps)
        @test (x ≈ startx) && (v ≈ -startv)
    end
    
end

@testset "Preconditioners: normal target" begin
    rng = SplittableRandom(1)
    precs = [100.0, 0.01]
    unbalanced_target = HetPrecisionNormalLogPotential(precs)

    pt = pigeons(
        target = unbalanced_target,
        explorer = AutoMALA(preconditioner = Pigeons.IdentityPreconditioner()),
        n_chains = 1,
        n_rounds = 12,
        record = [traces]
    )
    min_ess_id = minimum(ess(Chains(sample_array(pt))).nt.ess) # ~12

    pt = pigeons(
        target = unbalanced_target,
        explorer = AutoMALA(preconditioner = Pigeons.DiagonalPreconditioner()),
        n_chains = 1,
        n_rounds = 12,
        record = [traces]
    )
    min_ess_diag = minimum(ess(Chains(sample_array(pt))).nt.ess) # ~3945

    pt = pigeons(
        target = unbalanced_target,
        explorer = AutoMALA(preconditioner = Pigeons.MixDiagonalPreconditioner()),
        n_chains = 1,
        n_rounds = 12,
        record = [traces]
    )
    min_ess_mixdiag = minimum(ess(Chains(sample_array(pt))).nt.ess) # ~492

    @test min_ess_id < min_ess_mixdiag < min_ess_diag
end