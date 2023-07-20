@testset "Round trips" begin
    n_chains = 4
    n_rounds = 5
    
    pt = pigeons(; target = Pigeons.TestSwapper(1.0), record = [Pigeons.round_trip], 
        n_chains = n_chains, n_rounds = n_rounds);
    
    len = 2^(n_rounds)
    truth = 0.0
    for i in 0:(n_chains-1)
        truth += floor(max(len - i, 0) / n_chains / 2)
    end

    @test truth == Pigeons.n_round_trips(pt)
end