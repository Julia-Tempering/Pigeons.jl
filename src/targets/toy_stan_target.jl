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
    sm = BridgeStan.StanModel(; stan_file = stan_path, data)
    return StanLogPotential(sm)
end
