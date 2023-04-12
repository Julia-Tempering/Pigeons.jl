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

# function logp_cdf(pt, index::Int) # TODO: remove 
#     schedule = pt.shared.tempering.schedule
#     interpolator = pt.shared.tempering.path.interpolator

#     points = Float64[]
#     weights = Float64[]

#     beta = schedule.grids[index]
#     proposal_data = pt.reduced_recorders.interpolated_log_potentials[index]

#     for ref_target_pair in proposal_data 
#         logp = interpolate(interpolator, ref_target_pair[1], ref_target_pair[2], beta)
#         push!(points, logp)
#         push!(weights, 1.0/length(proposal_data))
#     end
#     cumulative_weights = cumsum(weights) 
#     return points, cumulative_weights
# end

# function local_barrier_test(pt, index::Int) # remove me
#     point, cumulative_weights = logp_cdf(pt, index)
#     sum = 0.0
#     n = length(points)
#     for i in 2:n
#         cur_point = points[i]
#         prev_point = points[i-1]
#         F = cumulative_weights[i-1]
#         sum += (cur_point - prev_point) * F * (1.0 - F)
#     end
#     return sum
# end


function interpolated_log_potential_distribution(pt, beta, degree::Int = 0)
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
            if degree == 0
                push!(points, proposed)
            elseif degree == 1 
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

function global_barrier_is(pt)
    quadgk(x -> local_barrier_is(pt, x), 0.0, 1.0)[1]
end
