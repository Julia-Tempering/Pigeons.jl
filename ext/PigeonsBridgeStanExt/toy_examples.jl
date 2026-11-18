stan_example_path(name) =
    dirname(dirname(pathof(Pigeons))) * "/examples/stan/$name"



Pigeons.toy_stan_target(dim::Int, precision = 10.0; make_args = stan_threads_options()) =
    StanLogPotential(
        stan_example_path("mvn.stan"),
        Pigeons.json(; dim, precision),
        nothing;
        make_args
    )

Pigeons.toy_stan_unid_target(n_trials = 100000, n_successes = ceil(Int, n_trials/2); make_args = stan_threads_options()) =
    StanLogPotential(
        stan_example_path("unid.stan"),
        Pigeons.json(; n_trials, n_successes),
        nothing;
        make_args
    )

Pigeons.stan_funnel(dim = 9, scale = 2.0; make_args = stan_threads_options()) =
    StanLogPotential(
        stan_example_path("funnel.stan"),
        Pigeons.json(; dim, scale),
        nothing;
        make_args
    )

Pigeons.stan_bernoulli(y = [0,1,0,0,0,0,0,0,0,1]; make_args = stan_threads_options()) =
    StanLogPotential(
        stan_example_path("bernoulli.stan"),
        Pigeons.json(; y, N = length(y)),
        nothing;
        make_args   
    )

Pigeons.stan_banana(dim = 9, scale=1.0; make_args = stan_threads_options()) =
    StanLogPotential(
        stan_example_path("banana.stan"),
        Pigeons.json(; dim, scale),
        nothing;
        make_args
    )


# the centered one is the "harder" one, see https://mc-stan.org/users/documentation/case-studies/divergences_and_bias.html
function Pigeons.stan_eight_schools(centered = true; make_args = stan_threads_options())
    stan_path = stan_example_path("eight_schools_" *
                    (centered ?
                        "centered.stan" :
                        "noncentered.stan"))
    data = stan_example_path("eight_schools.json")
    return StanLogPotential(stan_path, data; make_args)
end
