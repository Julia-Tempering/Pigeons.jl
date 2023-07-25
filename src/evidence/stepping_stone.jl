"""
$SIGNATURES 

Let Z1 denote the normalization constant of the target, and Z0, of the reference, this 
function approximates log(Z1/Z2) using the 
[stepping stone estimator](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3038348/) 
computed on the parallel tempering output. 
"""
function stepping_stone(pt::PT)
    p = stepping_stone_pair(pt)
    return (p[1] + p[2])/2.0
end

""" 
$SIGNATURES 

Return a pair, one such that its exponential is unbiased under 
Assumptions (A1-2) in [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464) for ``Z`` and the 
other, for ``1/Z``. 
Both are consistent in the number of MCMC iterations without these strong assumptions. 
"""
function stepping_stone_pair(pt::PT)
    log_sum_ratios = pt.reduced_recorders.log_sum_ratio
    key_subset = stepping_stone_keys(pt, log_sum_ratios, pt.shared.tempering)
    estimator1 = 0.0
    estimator2 = 0.0
    for (i, j) in key_subset
        log_sum_ratio = log_sum_ratios[(i, j)]
        current = value(log_sum_ratio) - log(log_sum_ratio.n)
        if i < j 
            estimator1 += current 
        else
            estimator2 += current 
        end
    end
    return (estimator1, -estimator2) 
end

# Determine which chains to use for normalization constant estimation 

# For one-leg: all chains
stepping_stone_keys(::PT, log_sum_ratios, ::NonReversiblePT) = keys(log_sum_ratios)

# use only the variational leg for 2-legs PT 
# rationale: for should give lower error for given compute since 
#            it the KL should be lower between target and variational
function stepping_stone_keys(pt::PT, log_sum_ratios, ::StabilizedPT)
    # Note: we rely on the variational leg being in increasing order 
    #       (the roles of 2 legs were swapped on 2023/07/20)
    indexer = pt.shared.tempering.indexer 
    variational_indices = Set(variational_leg_indices(indexer))
    result = Vector{Tuple{Int, Int}}()
    for (i, j) in keys(log_sum_ratios)
        if i in variational_indices && j in variational_indices 
            push!(result, (i, j))
        end
    end
    return result
end