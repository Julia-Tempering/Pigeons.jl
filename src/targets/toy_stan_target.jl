

""" 
$SIGNATURES

A multivariate normal implemented in Stan for testing/benchmarking.
"""
@provides target toy_stan_target(dim::Int, precision = 10.0) =
    StanLogPotential(
        stan_example_path("mvn.stan"), 
        json(; dim, precision)
    )

toy_stan_unid_target(n_trials = 100000, n_successes = ceil(Int, n_trials/2)) =
    StanLogPotential(
        stan_example_path("unid.stan"), 
        json(; n_trials, n_successes)
    )

stan_funnel(dim = 9) = 
    StanLogPotential(
        stan_example_path("funnel.stan"), 
        json(; dim)
    )

stan_bernoulli(y = [0,1,0,0,0,0,0,0,0,1]) =
    StanLogPotential(
        stan_example_path("bernoulli.stan"), 
        json(; y, N = length(y))
    )

stan_banana(dim = 9) = 
    StanLogPotential(
        stan_example_path("banana.stan"), 
        json(; dim)
    )

observed_range_squared(x) = (maximum(x) - minimum(x))^2

# the centered one is the "harder" one, see https://mc-stan.org/users/documentation/case-studies/divergences_and_bias.html
function stan_eight_schools(centered = true) 
    stan_path = stan_example_path("eight_schools_" * 
                    (centered ? 
                        "centered.stan" :
                        "noncentered.stan"))
    data = stan_example_path("eight_schools.json")
    return StanLogPotential(stan_path, data)
end

stan_example_path(name) = 
    dirname(dirname(pathof(Pigeons))) * "/examples/stan/$name"

""" 
$SIGNATURES 

Create a JSON string based on the scalar or array variables 
provided. 
"""
json(; variables...) = 
    "{" * 
    join(
        map(
            pair -> "\"$(pair[1])\" : $(pair[2])", 
            collect(variables)), ",") * 
    "}"