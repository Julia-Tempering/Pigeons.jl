@testset "Stan examples" begin
    pigeons(target = Pigeons.stan_eight_schools(true), n_rounds = 2, n_chains = 2)
    pigeons(target = Pigeons.stan_eight_schools(false), n_rounds = 2, n_chains = 2)

    # some examples where an error is interpreted as -Inf:
    pigeons(target = Pigeons.stan_funnel(1), recorder_builders = [online], n_chains = 1, n_rounds = 5, explorer = SliceSampler())
    pigeons(target = Pigeons.stan_covid_target(), n_rounds = 1)
end

@testset "Stan restarts" begin
    for explorer in [AutoMALA(), SliceSampler()]
        pt = pigeons(;
                target = Pigeons.stan_eight_schools(), 
                recorder_builders = [round_trip], 
                variational = GaussianReference(), 
                explorer)
        n_restarts = n_tempered_restarts(pt)
        @test n_restarts > 100
    end
end