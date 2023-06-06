@testset "Cumulative barrier" begin
    target = toy_mvn_target(2)
    pt = pigeons(; target, explorer = SliceSampler(), n_rounds = 15);
    
    truth = Pigeons.analytic_cumulativebarrier(target)
    barriers = pt.shared.tempering.communication_barriers
    estimated_cum = barriers.cumulativebarrier

    for beta in 0.0:0.1:1.0
        @test abs(estimated_cum(beta)  - truth(beta)) < 0.01
    end
end