@testset "Preflights" begin
    @test_throws "activate checkpoint" pigeons(target = toy_mvn_target(1), on = ChildProcess(), checked_round = 1)
    @test_throws "activate checkpoint" pigeons(target = toy_mvn_target(1), on = ChildProcess(), record = [disk])
end