

""" 
$SIGNATURES

A multivariate normal implemented in Stan for testing/benchmarking.
"""
@provides target toy_stan_target(dim::Int, precision = 10.0) =
    StanLogPotential(
        stan_example_path("mvn.stan"), 
        variables_to_stan(; dim, precision)
    )

toy_stan_unid_target(number = 100000, sum = ceil(Int, number/2)) =
    StanLogPotential(
        stan_example_path("unid.stan"), 
        variables_to_stan(; number, sum)
    )

stan_funnel(dim = 9) = 
    StanLogPotential(
        stan_example_path("funnel.stan"), 
        variables_to_stan(; dim)
    )

# the centered one is the "harder" one, see https://mc-stan.org/users/documentation/case-studies/divergences_and_bias.html
function stan_eight_schools(centered = true) 
    stan_path = stan_example_path("eight_schools_" * 
                    (centered ? 
                        "centered.stan" :
                        "noncentered.stan"))
    data = stan_example_path("eight_schools.json")
    return StanLogPotential(stan_path, data)
end

function stan_covid_target()
    stan_path = stan_example_path("covid19imperial_v3.stan")
    data = stan_example_path("ecdc0501.json")
    return StanLogPotential(stan_path, data)
end

stan_example_path(name) = 
    dirname(dirname(pathof(Pigeons))) * "/examples/stan/$name"

variables_to_stan(; variables...) = 
    "{" * 
    join(
        map(
            pair -> "\"$(pair[1])\" : $(pair[2])", 
            collect(variables)), ",") * 
    "}"