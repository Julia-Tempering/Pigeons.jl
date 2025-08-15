@testset "Cumulative barrier" begin
    target = toy_mvn_target(2)
    pt = pigeons(; target, n_rounds = 15);
    
    truth = Pigeons.analytic_cumulativebarrier(target)
    barriers = pt.shared.tempering.communication_barriers
    estimated_cum = barriers.cumulativebarrier

    for beta in 0.0:0.1:1.0
        @test abs(estimated_cum(beta)  - truth(beta)) < 0.01
    end
end 

@testset "Cumulative barrier multi knots" begin
    target = toy_mvn_target(2) 
    pt_ref = pigeons(; target, n_rounds = 15)

    # here we pick a middle point which happens to be in the linear path 
    # so that should keep the global barrier invariant in that special case

    middle_point = 0.2
    knots = map(beta -> Pigeons.interpolate(target, beta), [0.0, middle_point, 1.0])

    multistep_target = Pigeons.MultiStepsInterpolatingPath(knots)
    pt = pigeons(; target = multistep_target, n_rounds = 15);

    @test abs(Pigeons.global_barrier(pt) - Pigeons.global_barrier(pt_ref)) < 0.01
    @test abs(stepping_stone(pt) - stepping_stone(pt_ref)) < 0.001

    @test_throws "Conflicting options" pigeons(; target = multistep_target, reference = Pigeons.interpolate(target, 0.1))

    @test_throws "Variational inference not currently supported" pigeons(; target = multistep_target, variational = variational = GaussianReference())
end

