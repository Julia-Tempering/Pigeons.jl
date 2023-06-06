@testset "Allocs-SliceSampler" begin
    allocs_10_rounds = Pigeons.last_round_max_allocation(pigeons(n_rounds = 11, target = toy_mvn_target(100)))
    allocs_11_rounds = Pigeons.last_round_max_allocation(pigeons(n_rounds = 12, target = toy_mvn_target(100)))
    @test allocs_10_rounds == allocs_11_rounds
end

@testset "Allocs-AutoMALA" begin
    allocs_rounds = Pigeons.last_round_max_allocation(pigeons(n_rounds = 13, target = toy_mvn_target(1), explorer = AutoMALA()))
    allocs_rounds_longer = Pigeons.last_round_max_allocation(pigeons(n_rounds = 14, target = toy_mvn_target(1), explorer = AutoMALA()))
    @test allocs_rounds == allocs_rounds_longer
end