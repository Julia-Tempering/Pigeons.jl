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

function interpolated_log_potential_distribution(pt, beta)
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
            push!(points, proposed)
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