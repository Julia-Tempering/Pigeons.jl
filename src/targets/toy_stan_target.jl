""" 
$SIGNATURES

A multivariate normal implemented in Stan for testing/benchmarking.
"""
@provides target function toy_stan_target(dim::Int, precision = 10.0)
    pigeons_path = dirname(dirname(pathof(Pigeons)))
    stan_path = "$pigeons_path/examples/stan/mvn.stan" 
    data = 
        """
        {
            "N" : $dim, 
            "precision" : $precision
        }
        """
    return StanLogPotential(stan_path, data)
end

function stan_covid_target()
    pigeons_path = dirname(dirname(pathof(Pigeons)))
    stan_path = "$pigeons_path/examples/stan/covid19imperial_v3.stan"
    data =  "$pigeons_path/examples/stan/ecdc0501.json" 
    return StanLogPotential(stan_path, data)
end