""" 
$SIGNATURES 

Assuming that the reference distribution has a normalization constant of one, 
compute the (log of) the [stepping stone estimator](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3038348/). 
It returns a pair, one such that its exponential is unbiased under stationary for ``Z`` and the 
other, for ``1/Z``. 
Both are consistent in the number of MCMC iterations. 
"""
stepping_stone_pair(pt::PT) = stepping_stone_pair(pt.reduced_recorders.log_sum_ratio)

function stepping_stone_pair(log_sum_ratios::GroupBy)
    estimator1 = 0.0
    estimator2 = 0.0
    for (i, j) in keys(log_sum_ratios.value)
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