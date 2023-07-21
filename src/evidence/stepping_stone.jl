""" 
$SIGNATURES 

Assuming that the reference distribution has a normalization constant of one, 
compute the (log of) the [stepping stone estimator](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3038348/). 
It returns a pair, one such that its exponential is unbiased under 
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

function stepping_stone(pt::PT)
    p = stepping_stone_pair(pt)
    return (p[1] + p[2])/2.0
end

stepping_stone_keys(::PT, log_sum_ratios, ::NonReversiblePT) = keys(log_sum_ratios)
function stepping_stone_keys(pt::PT, log_sum_ratios, ::VariationalPT)
    indexer = pt.shared.tempering.indexer 
    variational_indices = Set(variational_leg_indices(indexer))
    result = Array{Tuple{Int, Int}}()
    for (i, j) in keys(log_sum_ratios)
        if i in variational_indices && j in variational_indices 
            push!(result, (i, j))
        end
    end
    return result
end
