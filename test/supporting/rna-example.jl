function rna_example(_data_sizes = [0, typemax(Int)]) 
    data_sizes = sort(_data_sizes)
    @assert data_sizes[1] == 0 
    n_knots = length(data_sizes) 
    @assert n_knots > 1

    example_dir = dirname(dirname(pathof(Pigeons))) * "/examples/"
    data = readdlm(example_dir * "data/Ballnus_et_al_2017_M1a.csv", ',')
    N   = size(data, 1)
    @assert data_sizes[end] == typemax(Int) || data_sizes[end] == N

    # prior 
    # use a DistributionLogPotential based on the prior to enable iid sampling
    # note: need to work on unconstrained_parameters. We use Bijectors.transformed
    # to achieve this automatically, because their bijection for scalar Uniforms
    # is the same as the one used in Stan (logit <-> logistic)
    prior_ref = DistributionLogPotential(product_distribution(
        transformed.([Uniform(-2,1), Uniform(-5,5), Uniform(-5,5), Uniform(-5,5), Uniform(-2,2)])
    ))

    knots = (prior_ref, ) 

    model_file = example_dir * "stan/mRNA.stan"
    for knot_index in 2:n_knots 
        cur_N = min(N, data_sizes[knot_index]) 
        @assert cur_N > 0
        ts = data[1:cur_N,1]
        ys = data[1:cur_N,2]
        knot = StanLogPotential(model_file, Pigeons.json(; N = cur_N, ts, ys))
        knots = (knots..., knot)
    end
    
    return Pigeons.MultiStepsInterpolatingPath(knots)
end
