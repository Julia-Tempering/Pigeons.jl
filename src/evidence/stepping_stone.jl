"""
$SIGNATURES 

Let Z1 denote the normalization constant of the target, and Z0, of the reference, this 
function approximates log(Z1/Z2) using the 
[stepping stone estimator](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3038348/) 
computed on the parallel tempering output. 
"""
function stepping_stone(pt::PT)
    p = stepping_stone_pair(pt)
    if !isfinite(p[1])
        return p[2]
    end
    if !isfinite(p[2])
        return p[1]
    end
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
stepping_stone_keys(::PT, log_sum_ratios::GroupBy, ::NonReversiblePT) = keys(log_sum_ratios.value)

# use only the variational leg for 2-legs PT 
# rationale: for should give lower error for given compute since 
#            it the KL should be lower between target and variational
function stepping_stone_keys(pt::PT, log_sum_ratios::GroupBy, ::StabilizedPT)
    # Note: we rely on the variational leg being in increasing order 
    #       (the roles of 2 legs were swapped on 2023/07/20)
    indexer = pt.shared.tempering.indexer 
    variational_indices = Set(variational_leg_indices(indexer))
    result = Vector{Tuple{Int, Int}}()
    for (i, j) in keys(log_sum_ratios.value)
        if i in variational_indices && j in variational_indices 
            push!(result, (i, j))
        end
    end
    return result
end

"""
$SIGNATURES

Compute estimated ``\\log(Z_{\\beta_k}/Z_0)`` for each temperature ``\\beta_k`` 
in the schedule, using the stepping stone estimator's telescoping decomposition.

Returns a `NamedTuple` with fields:
- `betas::Vector{Float64}` — the temperature schedule (0.0 to 1.0)
- `log_norm_constants::Vector{Float64}` — cumulative ``\\log(Z_{\\beta_k}/Z_0)``
"""
function stepping_stone_per_chain(pt::PT)
    return _stepping_stone_per_chain(pt, pt.shared.tempering)
end

function _stepping_stone_per_chain(pt::PT, tempering::NonReversiblePT)
    betas = tempering.schedule.grids
    K = length(betas)

    log_sum_ratios = pt.reduced_recorders.log_sum_ratio

    # Collect forward estimates: key(i, i+1)
    # Collect backward estimates: key(i+1, i)
    # Sandwich estimator: average forward and backward

    forward = zeros(K) # forward[k] = estimate of log(Z_{β_k}/Z_{β_{k-1}}) from chain k-1 -> k
    backward = zeros(K) # backward[k] = estimate of log(Z_{β_{k-1}}/Z_{β_{k}}) from chain k -> k-1

    for (i, j) in keys(log_sum_ratios.value)
        ls = log_sum_ratios[(i, j)]
        est = value(ls) - log(ls.n)

        if i < j && j <= K 
            forward[j] = est 
        elseif i > j && i <= K 
            backward[i] = est 
        end
    end

    # build cumulative sums 
    log_norm_constants = zeros(K)
    for k in 2:K
        local_est = (forward[k] + (-backward[k])) / 2.0
        log_norm_constants[k] = log_norm_constants[k-1] + local_est
    end

    return (betas = collect(betas), log_norm_constants = log_norm_constants)
end
