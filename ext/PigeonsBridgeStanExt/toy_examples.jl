stan_example_path(name) =
    dirname(dirname(pathof(Pigeons))) * "/examples/stan/$name"



Pigeons.toy_stan_target(dim::Int, precision = 10.0) =
    StanLogPotential(
        stan_example_path("mvn.stan"),
        Pigeons.json(; dim, precision)
    )

Pigeons.toy_stan_unid_target(n_trials = 100000, n_successes = ceil(Int, n_trials/2)) =
    StanLogPotential(
        stan_example_path("unid.stan"),
        Pigeons.json(; n_trials, n_successes)
    )

Pigeons.stan_funnel(dim = 9, scale = 2.0) =
    StanLogPotential(
        stan_example_path("funnel.stan"),
        Pigeons.json(; dim, scale)
    )

Pigeons.stan_bernoulli(y = [0,1,0,0,0,0,0,0,0,1]) =
    StanLogPotential(
        stan_example_path("bernoulli.stan"),
        Pigeons.json(; y, N = length(y))
    )

Pigeons.stan_banana(dim = 9, scale=1.0) =
    StanLogPotential(
        stan_example_path("banana.stan"),
        Pigeons.json(; dim, scale)
    )


observed_range_squared(x) = (maximum(x) - minimum(x))^2

# the centered one is the "harder" one, see https://mc-stan.org/users/documentation/case-studies/divergences_and_bias.html
function Pigeons.stan_eight_schools(centered = true)
    stan_path = stan_example_path("eight_schools_" *
                    (centered ?
                        "centered.stan" :
                        "noncentered.stan"))
    data = stan_example_path("eight_schools.json")
    return StanLogPotential(stan_path, data)
end
