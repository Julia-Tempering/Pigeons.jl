### Compute acceptance probability
# energy and schedule are both an list of numbers of the same length

function acceptanceprobability(newEnergy, newEnergy1, newEnergy2)
    A = newEnergy1 .+ newEnergy2 .-
    newEnergy[1:end-1] .- newEnergy[2:end] # Log scale
    return exp.(min.(0, -A))
end

