include("supporting/HetPrecisionNormalLogPotential.jl")

mean_mh_accept(pt) = mean(Pigeons.explorer_mh_prs(pt))

@testset "Mass-matrix" begin
    bad_conditioning_target = HetPrecisionNormalLogPotential([500.0, 1.0])
    pt = pigeons(target = bad_conditioning_target, explorer = AutoMALA(), n_chains = 1, n_rounds = 10)
    @test abs(pt.shared.explorer.estimated_target_std_deviations[1] - 1/sqrt(500)) < 0.01
    @test mean_mh_accept(pt) > 0.5
end

@testset "Allocs-AutoMALA" begin
    allocs_rounds = Pigeons.last_round_max_allocation(pigeons(n_rounds = 13, target = toy_mvn_target(1), explorer = AutoMALA()))
    allocs_rounds_longer = Pigeons.last_round_max_allocation(pigeons(n_rounds = 14, target = toy_mvn_target(1), explorer = AutoMALA()))
    @test allocs_rounds == allocs_rounds_longer
end

auto_mala(target) =
    pigeons(; 
        target, 
        explorer = AutoMALA(), 
        n_chains = 1, n_rounds = 10, recorder_builders = Pigeons.online_recorder_builders())


@testset "AutoMALA dimensional autoscale" begin
    for i in 0:3
        d = 10^i
        @test mean_mh_accept(auto_mala(toy_mvn_target(d))) > 0.4
    end
end

@testset "Hamiltonian-involutive" begin
    rng = SplittableRandom(1)

    my_target = HetPrecisionNormalLogPotential([5.0, 1.1]) 
    some_cond = [2.3, 0.8]

    x = randn(rng, 2)
    v = randn(rng, 2)

    n_leaps = 40

    start = copy(x)
    @test Pigeons.hamiltonian_dynamics!(my_target, some_cond, x, v, 0.1, n_leaps, zeros(2))
    @test !(x ≈ start)
    @test Pigeons.hamiltonian_dynamics!(my_target, some_cond, x, -v, 0.1, n_leaps, zeros(2))
    @test x ≈ start
end