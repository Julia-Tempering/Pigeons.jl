

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

observed_range_squared(x) = (maximum(x) - minimum(x))^2

function stan_galaxy(;K = 3, y = galaxy_data(), alpha_0 = 0.01, 
        b_0 = median(y),  # empirical prior proposed in Richardson and Green (1997)
        B_0 = observed_range_squared(y),
        c_0 = 2, # Escobar and West (1995), Phillips and Smith (1996) and Richardson and Green (1997)
        C_0 = 1) # Escobar and West (1995)
    alpha = ones(K)/alpha_0
    N = length(y)
    return StanLogPotential(
        stan_example_path("galaxy.stan"), 
        json(; K, N, alpha, b_0, B_0, c_0, C_0, y)
    )
end

galaxy_data() = [ # "classical" Roeder (1990) version, which includes a typo compared to the source, Postman et al. (1986), but is widely used in the comp. stat. literature
        9172, 9350, 9483, 9558, 9775, 10227, 10406, 16084, 16170, 18419, 
        18552, 18600, 18927, 19052, 19070, 19330, 19343, 19349, 19440, 19473, 
        19529, 19541, 19547, 19663, 19846, 19856, 19863, 19914, 19918, 19973,
        19989, 20166, 20175, 20179, 20196, 20215, 20221, 20795, 20875, 21492,
        21921, 22209, 20415, 20821, 20986, 21701, 21960, 22242, 20629, 20846,
        21137, 21814, 22185, 22249, 22314, 22746, 22914, 23263, 22374, 22747,
        23206, 23484, 22495, 22888, 23241, 23538, 23542, 23666, 23706, 23711, 
        24129, 24285, 24289, 24366, 24717, 24990, 25633, 26960, 26995, 32065, 
        32789, 34279
    ]/1000 # scaling by 1000 is standard in this dataset, e.g. Richardson and Green (1997)

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