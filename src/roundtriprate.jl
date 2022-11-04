# Round trip for a trajectory
#' cumulative: Whether to store the output as a vector containing information about the number of total round trips up to sample 'n'
#'   If false, the output is a scalar
function roundtrip(IndicesMatrix; cumulative = false)
    n, N = size(IndicesMatrix) # Number of samples x number of chains/machines
    if cumulative
        trips = fill(0, n)
    else
        trips = 0
    end

    for j ∈ 1:N
        trajectory = IndicesMatrix[:,j]
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

function roundtrip(Indices::Vector{Array{Int64,1}})
    IndicesMatrix = reduce(hcat, PTefficient.Indices)'
    roundtrip(IndicesMatrix)
end


function roundtriprate(Indices::AbstractArray)
    n, N = size(Indices)
    roundtrip(Indices)/n
end


# Computes the number of *restarts* instead of the number of round trips!
function restarts(IndicesMatrix; cumulative = false)
    n, N = size(IndicesMatrix) # Number of samples x number of chains/machines
    if cumulative
        trips = fill(0, n)
    else
        trips = 0
    end

    for j ∈ 1:N
        trajectory = IndicesMatrix[:,j]
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