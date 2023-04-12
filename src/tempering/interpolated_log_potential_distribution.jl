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

function global_barrier_trapezoid(pt)
    sum = 0.0

    schedule = pt.shared.tempering.schedule

    previous = process_interpolated_log_potentials(pt, 1, 1)
    for i in 2:pt.inputs.n_chains 
        current = process_interpolated_log_potentials(pt, i, 1)
        len = length(current)
        @assert length(previous) == len "$(length(previous)) vs $len"

        delta_beta = schedule.grids[i] - schedule.grids[i - 1]

        for s in 2:len
            a = current[s] - current[s - 1]
            b = previous[s] - previous[s - 1]
            increment = (s/len) * (1.0 - s/len) * (a + b) * delta_beta / 2.0
            sum += increment
            @assert increment ≥ 0.0 "$a $b $delta_beta"
        end

        previous = current
    end

    return sum
end

function process_interpolated_log_potentials(pt, dist_index, degree::Int = 0)
    interpolator = pt.shared.tempering.path.interpolator
    trace = pt.reduced_recorders.interpolated_log_potentials[dist_index]
    schedule = pt.shared.tempering.schedule
    beta = schedule.grids[dist_index]
    result = Float64[] 
    for ref_target_pair in trace 
        if degree == 0
            push!(result,     interpolate(interpolator, ref_target_pair[1], ref_target_pair[2], beta))
        elseif degree == 1 
            push!(result, path_derivative(interpolator, ref_target_pair[1], ref_target_pair[2], beta))
        else
            error()
        end
    end
    sort!(result)
    return result
end
