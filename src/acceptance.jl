### Compute acceptance probability
# energy and schedule are both an list of numbers of the same length

function acceptanceprobability(Energy, Schedule)
    Δβ = Schedule[2:end] - Schedule[1:end-1]
    ΔV = Energy[2:end] - Energy[1:end-1]
    return exp.(min.(0,Δβ.*ΔV))
end

function acceptanceprobability(potential, newState, Etas, newEnergy)
    A = potential.(newState[2:end],eachrow(Etas[1:end-1, :])) .+ 
    potential.(newState[1:end-1], eachrow(Etas[2:end, :])) .-
    newEnergy[1:end-1] .- newEnergy[2:end]
    return exp.(min.(0, -A))
end

function acceptanceprobability(newEnergy, newEnergy1, newEnergy2)
    A = newEnergy1 .+ newEnergy2 .-
    newEnergy[1:end-1] .- newEnergy[2:end] # Log scale
    return exp.(min.(0, -A))
end

