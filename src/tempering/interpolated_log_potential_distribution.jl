"""
$SIGNATURES 

Denote the path of log_potentials by ``W(x, \\beta)```. 

When `order` is zero, this returns the CDF of the CDF of an 
importance sampling approximation of ``W(X_\\beta, \\beta)``, 
where  ``X_\\beta \\sim \\exp(W(x, \\beta))/Z_\\beta``. 
The importance distribution is based on two chains that 
are neighbours to beta.

When `order` is one, it is the same idea but for ``W'(X_\\beta, \\beta)``
where ``W'`` is the derivative with respect to ``\\beta``. 

In both cases, the CDF is represented by a pair of vectors, 
the first one containing the location of the atoms sorted from left 
to right, and the second, 
the cumulative distribution at each of the points in the same order. 
"""
function interpolated_log_potential_distribution(pt, beta, order::Int = 0)
    schedule = pt.shared.tempering.schedule
    interpolator = pt.shared.tempering.path.interpolator

    # Compute IS approximation based on nearby grid points
    points = Float64[]
    log_weights = Float64[]
    for proposal_chain in closest_pair(schedule, beta) 
        proposal_beta = schedule.grids[proposal_chain]
        proposal_data = pt.reduced_recorders.interpolated_log_potentials[proposal_chain]
        for ref_target_pair in proposal_data 
            proposed = interpolate(interpolator, ref_target_pair[1], ref_target_pair[2], proposal_beta)
            target   = interpolate(interpolator, ref_target_pair[1], ref_target_pair[2], beta)
            if order == 0
                push!(points, proposed)
            elseif order == 1 
                deriv = path_derivative(interpolator, ref_target_pair[1], ref_target_pair[2], proposal_beta)
                push!(points, deriv)
            else
                error()
            end
            push!(log_weights, target - proposed)
        end
    end
    weights = exp.(log_weights .- logsumexp(log_weights))

    # sort using permuation matrix 
    p = sortperm(points) 
    points = points[p]
    weights = weights[p] 

    cumulative_weights = cumsum(weights) 
    return points, cumulative_weights
end

function closest_pair(schedule, beta)
    search_result = searchsorted(schedule.grids, beta)
    point = search_result.start 
    return if isempty(search_result)
        (point - 1):point 
    else
        if point > 1
            (point - 1):point 
        else 
            point:(point + 1)
        end
    end
end

"""
$SIGNATURES 

An alternative estimation of the local communication barrier based 
on importance sampling. It is more computationally costly than the 
Syed et al. JRSSB method, but has the property that it converges to the 
true answer when the number of MCMC samples goes to infinity but the 
grid size N is finite. In contrast, the Syed et al. JRSSB needs both 
quantities to go to infinity (but performs remarkably well for finite 
N due to its cubic error term). 
"""
function local_barrier_is(pt, beta)
    points, cumulative_weights = interpolated_log_potential_distribution(pt, beta, 1)
    sum = 0.0
    n = length(points)
    for i in 2:n
        cur_point = points[i]
        prev_point = points[i-1]
        F = cumulative_weights[i-1]
        sum += (cur_point - prev_point) * F * (1.0 - F)
    end
    return sum
end

"""
$SIGNATURES 

Uses [`local_barrier_is`](@ref) and `quadgk()` to approximate 
the global communication barrier. See [`local_barrier_is`](@ref), 
for a description of the distinct asymptotic properties of this 
method.
"""
function global_barrier_is(pt)
    quadgk(x -> local_barrier_is(pt, x), 0.0, 1.0)[1]
end

function interpolate_cdf(points, cumulative_prs, inverse = false)

    function derivative(i::Int, xs, ys) 
        left_point = xs[i] 
        right_point = xs[i + 1]
        bottom = ys[i] 
        top = ys[i + 1] 
        return (top - bottom) / (right_point - left_point) 
    end

    len = length(points)
    first_point = points[1]
    last_point = points[len - 2]
    first_cp = cumulative_prs[1]
    last_cp = cumulative_prs[len - 2]
    first_deriv = derivative(1, points, cumulative_prs)
    last_deriv = derivative(length(points) - 2, points, cumulative_prs)
    r1 = first_deriv/first_cp
    r2 = last_deriv/last_cp

    if inverse 
        points, cumulative_prs = cumulative_prs, points
    else
        cumulative_prs, points = cumulative_prs, points
    end

    # can be distinct from first_point, last_point when computing inverse
    left_limit = points[1]
    right_limit = points[len - 2]
    
    function result(x)
        if isnan(x)
            return NaN 
        end
        # annoyingly, we got -1e-11 when composing in at least one instance
        if inverse 
            if x < 0 && abs(x) < 1e-8 
                return -x 
            elseif x > 1 && abs(1.0 - x) < 1e-8
                return 1 - (x - 1) 
            end
        end

        if x <= left_limit
            if inverse 
                return first_point + log(x / first_cp) / r1
            else
                return first_cp * exp(r1 * (x - first_point))
            end
        elseif x >= right_limit
            if inverse 
                return last_point - log((1 - x) / (1-last_cp)) / r2
            else
                return 1-(1-last_cp) * exp(r2  * (last_point - x))
            end
        else 
            search_result = searchsorted(points, x) 
            if isempty(search_result)
                left_idx = search_result.start - 1
                left_point = points[left_idx] 
                deriv = derivative(left_idx, points, cumulative_prs)
                bottom = cumulative_prs[left_idx] 
                return bottom + (x - left_point) * deriv
            else 
                return cumulative_prs[search_result.start]
            end
        end
    end
    return result
end

