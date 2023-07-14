@testset "Stan examples" begin
    pigeons(target = stan_eight_schools(true), n_rounds = 2, n_chains = 2)
    pigeons(target = stan_eight_schools(false), n_rounds = 2, n_chains = 2)

    # some examples where an error is interpreted as -Inf:
    pigeons(target = Pigeons.stan_funnel(1), recorder_builders = [online], n_chains = 1, n_rounds = 5, explorer = SliceSampler())
    pigeons(target = Pigeons.stan_covid_target(), n_rounds = 1)
end