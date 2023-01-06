"""
$TYPEDSIGNATURES
Compute the number of round trips for a given index process trajectory. 
`indices_matrix` is a matrix containing information about the index process.
`cumulative` indicates whether we should store the output as a vector containing 
information about the number of total round trips up to sample `n`. If false, the
output is a scalar.
"""
function roundtrip(indices_matrix; cumulative = false)
    n, N = size(indices_matrix) # Number of samples x number of chains/machines
    if cumulative
        trips = fill(0, n)
    else
        trips = 0
    end

    for j ∈ 1:N
        trajectory = indices_matrix[:,j]
        if 1 ∉ trajectory
            break # This machine/particle did not contribute to the round trip count
        end
        k = findfirst(trajectory .== 1) # Find first time at which the reference distribution is hit
        goingUp = true # Set trajectory to be 'upwards'
        while k < n
            if goingUp && N ∈ @view trajectory[k:end]
                k += findfirst(trajectory[k:end] .== N) # Move to one step *after* the occurence
                goingUp = false # Set trajectory to be 'downwards'
            elseif !goingUp && 1 ∈ trajectory[k:end]
                k += findfirst(trajectory[k:end] .== 1)
                if cumulative
                    trips[k-1] = 1
                else
                    trips += 1
                end
                goingUp = true
            else
                k = n
                break
            end
        end
    end

    if cumulative
        trips = cumsum(trips)
    end
    return trips
end


"""
$TYPEDSIGNATURES
Compute the number of restarts for a given index process trajectory. 
Otherwise, it is the same as `roundtrip()`.
"""
function restarts(indices_matrix; cumulative = false)
    n, N = size(indices_matrix) # Number of samples x number of chains/machines
    if cumulative
        trips = fill(0, n)
    else
        trips = 0
    end

    for j ∈ 1:N
        trajectory = indices_matrix[:,j]
        if 1 ∉ trajectory
            break # This machine/particle did not contribute to the restart count
        end
        k = findfirst(trajectory .== 1) # Find first time at which the reference distribution is hit
        goingUp = true # Set trajectory to be 'upwards'
        while k < n
            if goingUp && N ∈ @view trajectory[k:end]
                k += findfirst(trajectory[k:end] .== N) # Move to one step *after* the occurence
                if cumulative
                    trips[k-1] = 1
                else
                    trips += 1
                end
                goingUp = false # Set trajectory to be 'downwards'
            elseif !goingUp && 1 ∈ trajectory[k:end]
                k += findfirst(trajectory[k:end] .== 1)
                goingUp = true
            else
                k = n
                break
            end
        end
    end

    if cumulative
        trips = cumsum(trips)
    end
    return trips
end